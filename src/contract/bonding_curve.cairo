// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^0.20.0

#[starknet::contract]
mod BondingCurve {
    use openzeppelin_token::erc20::interface::IERC20Mixin;
    use openzeppelin::access::ownable::OwnableComponent;
    use core::to_byte_array::FormatAsByteArray;
    use cubit::f128::types::fixed::{Fixed, FixedTrait, FixedZero};
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    #[starknet::interface]
    pub trait IERC20<TContractState> {
        fn balance_of(ref self: TContractState, owner: ContractAddress) -> u256;
        fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256);
        fn transfer_from(
            ref self: TContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        );
    }
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // External
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        buy_tax: u16,
        sell_tax: u16,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    const BASE_X1E9: felt252 = 601500000;
    const EXPONENT_X1E9: felt252 = 36060000;
    const EULER_X9: u32 = 2718281828;


    const MANTISSA: u256 = 1000000000000000000;
    const MANTISSA_1e9: u256 = 1000000000;
    const ETH: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
    const LFTCRV_TAX_CONTRACT: felt252 =
        0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }
    #[constructor]
    fn constructor(
        ref self: ContractState,
        _owner: ContractAddress,
        _name: felt252,
        _symbol: felt252,
        buy_tax_percentage_x100: u16,
        sell_tax_percentage_x100: u16
    ) {
        let (_name, _symbol) = (_name.format_as_byte_array(10), _symbol.format_as_byte_array(10));
        self.erc20.initializer(_name, _symbol);
        self.ownable.initializer(_owner);
        self.buy_tax.write(buy_tax_percentage_x100);
        self.sell_tax.write(sell_tax_percentage_x100);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn get_current_price(self: @ContractState) -> u256 {
            self.get_price_for_market_cap(self.get_market_cap())
        }
        #[external(v0)]
        fn buy_tax_percentage_x100(self: @ContractState) -> u16 {
            self.buy_tax.read()
        }
        #[external(v0)]
        fn sell_tax_percentage_x100(self: @ContractState) -> u16 {
            self.sell_tax.read()
        }


        #[external(v0)]
        fn get_price_for_market_cap(self: @ContractState, market_cap: u256) -> u256 {
            if market_cap == 0 {
                return 601500000 * MANTISSA_1e9;
            }
            let market_cap_in_gwei: u256 = market_cap / 1000000000_u256;
            let market_cap_in_gwei: felt252 = market_cap_in_gwei.try_into().unwrap();
            let market_cap_in_gwei: Fixed = FixedTrait::from_felt(market_cap_in_gwei);

            let mantissa_1e9: Fixed = FixedTrait::from_felt(1000000000);
            let market_cap: Fixed = market_cap_in_gwei / mantissa_1e9;
            let euler: Fixed = FixedTrait::from_felt(271828) / FixedTrait::from_felt(100000);

            let base = FixedTrait::from_felt(601500000) / mantissa_1e9;
            let exponent: Fixed = FixedTrait::from_felt(EXPONENT_X1E9) / mantissa_1e9;
            let price_x9: felt252 = (base * euler.pow(market_cap * exponent) * mantissa_1e9).into();
            let price_x9: u256 = price_x9.into();

            price_x9 * MANTISSA_1e9
        }

        #[external(v0)]
        fn get_market_cap(self: @ContractState) -> u256 {
            let eth_contract = IERC20Dispatcher { contract_address: ETH.try_into().unwrap() };
            eth_contract.balance_of(get_contract_address())
        }


        #[external(v0)]
        fn simulate_buy(self: @ContractState, eth_amount: u256) -> u256 {
            let (ret, _) = self._simulate_buy(eth_amount);
            ret
        }


        #[external(v0)]
        fn simulate_sell(ref self: ContractState, token_amount: u256) -> u256 {
            let (taxed_amount, _ ) = self._simulate_sell(token_amount);
            taxed_amount
        }
        #[external(v0)]
        fn buy(ref self: ContractState, eth_amount: u256) -> u256 {
            let (amount, tax_amount) = self._simulate_buy(eth_amount);
            let eth_contract = IERC20Dispatcher { contract_address: ETH.try_into().unwrap() };
            let from: ContractAddress = get_caller_address();
            let to = get_contract_address();
            eth_contract.transfer_from(from, to, eth_amount);
            self._transfer_tax(tax_amount);
            self.erc20.mint(get_caller_address(), amount);
            amount
        }

        #[external(v0)]
        fn sell(ref self: ContractState, token_amount: u256) -> u256 {
            let (amount, tax) = self._simulate_sell(token_amount);

            println!("[+] Market cap {}", self.get_market_cap());
            println!("toSell {}", amount);
            self.erc20.burn(get_caller_address(), token_amount);
            let eth_contract = IERC20Dispatcher { contract_address: ETH.try_into().unwrap() };
            assert!(self.get_market_cap() >= amount, "Not enough eth get");
            eth_contract.transfer(get_caller_address(), amount);
            self._transfer_tax(tax);
            amount
        }

        fn _simulate_buy(self: @ContractState, eth_amount: u256) -> (u256, u256) {
            println!("-------------------------------\n!!_simulate_buy !! {}", eth_amount);
            let current_cap = self.get_market_cap();
            println!("[+] current_cap {}", current_cap);
            let tax_amount = self._simulate_tax(eth_amount, self.buy_tax.read().into());
            println!("tax_amount {}", tax_amount);
            
            let taxed_amount = eth_amount - tax_amount;

            let new_cap = current_cap + taxed_amount;
            let new_price = self.get_price_for_market_cap(new_cap);
            let old_price = self.get_current_price();
            println!("[+] old_price {}, new_price {}", old_price, new_price);
            let av_price = (old_price + new_price) / 2;
            (taxed_amount * MANTISSA / av_price , tax_amount)
        }


        fn _simulate_sell(ref self: ContractState, token_amount: u256) -> (u256, u256) {
            println!("[+] token_amount {}", token_amount);
            let current_supply = self.total_supply();
            println!("[+] current_supply {}", current_supply);

            let current_cap = self.get_market_cap();
            println!("[+] current_cap {}", current_cap);
            // Calculate what portion of the supply is being sold
            let portion = token_amount * MANTISSA  / current_supply;
            println!("[+] portion {}", portion);
            // Calculate equivalent market cap reduction
            let cap_reduction = current_cap * portion / MANTISSA;
            println!("[+] cap_reduction {}", cap_reduction);
            let new_cap = current_cap - cap_reduction;

            let old_price = self.get_current_price();
            let new_price = self.get_price_for_market_cap(new_cap);
            println!("[+] old_price {}, new_price {}", old_price, new_price);

            let av_price = (old_price + new_price) / 2;
            let  untaxed_amount = 
            token_amount * av_price / MANTISSA;
            let tax = self._simulate_tax(untaxed_amount, self.sell_tax.read().into());
            (untaxed_amount - tax, tax)
        }

        fn _transfer_tax(self: @ContractState, amount: u256) -> u256 {
            let eth_contract = IERC20Dispatcher { contract_address: ETH.try_into().unwrap() };
            eth_contract.transfer(LFTCRV_TAX_CONTRACT.try_into().unwrap(), amount);
            amount
        }

        fn _simulate_tax(self: @ContractState, amount: u256, tax_percentage_x100: u256) -> u256 {
            amount * tax_percentage_x100 / 10000
        }
    }
    // #[generate_trait]
// pub impl InternalImpl<
//     TContractState,
//     +Drop<TContractState>,
// > of InternalTrait<TContractState> {

    // }
}
