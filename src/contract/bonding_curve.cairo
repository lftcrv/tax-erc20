// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^0.20.0

#[starknet::contract]
mod BondingCurve {
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
        tick_price: u256,
        starting_price: u256,
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
        ref self: ContractState, _owner: ContractAddress, _name: felt252, _symbol: felt252,
    ) {
        let (_name, _symbol) = (_name.format_as_byte_array(10), _symbol.format_as_byte_array(10));
        self.erc20.initializer(_name, _symbol);
        self.ownable.initializer(_owner);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn get_current_price(self: @ContractState) -> u256 {
            self.get_price_for_market_cap(self.get_market_cap())
        }

        #[external(v0)]
        fn get_price_for_market_cap(self: @ContractState, market_cap: u256) -> u256 {
            if market_cap == 0 {
                return 601500000 * MANTISSA_1e9;
            }
            let market_cap_in_gwei: u256 = market_cap / 1000000000_u256;
            let market_cap_in_gwei: felt252 = market_cap_in_gwei.try_into().unwrap();
            println!("[+] market_cap_in_gwei {}", market_cap_in_gwei);
            let market_cap_in_gwei: Fixed = FixedTrait::from_felt(market_cap_in_gwei);

            let mantissa_1e9: Fixed = FixedTrait::from_felt(1000000000);
            let market_cap: Fixed = market_cap_in_gwei / mantissa_1e9;

            println!("[+] euler");
            let euler: Fixed = FixedTrait::from_felt(271828) / FixedTrait::from_felt(100000);

            println!("[+] base");

            let base = FixedTrait::from_felt(601500000) / mantissa_1e9;
            println!("[+] exponent");
            let exponent: Fixed = FixedTrait::from_felt(EXPONENT_X1E9) / mantissa_1e9;
            println!("[+] price_x9 ");
            let price_x9: felt252 = (base * euler.pow(market_cap * exponent) * mantissa_1e9)
                .floor()
                .into();
            println!("[+] price_x9");
            let price_x9: u256 = price_x9.into();

            price_x9 * MANTISSA_1e9
        }

        #[external(v0)]
        fn get_market_cap(self: @ContractState) -> u256 {
            let eth_contract = IERC20Dispatcher { contract_address: ETH.try_into().unwrap() };
            eth_contract.balance_of(get_contract_address())
        }

        #[external(v0)]
        fn simulate_buy(ref self: ContractState, eth_amount: u256) -> u256 {
            let current_cap = self.get_market_cap();
            let new_cap = current_cap + eth_amount;
            let new_price = self.get_price_for_market_cap(new_cap);
            let old_price = self.get_current_price();
            println!("[+] old_price {}, new_price {}", old_price, new_price);
            let av_price = (old_price + new_price) / 2;
            eth_amount * MANTISSA  / av_price 
        }

        #[external(v0)]
        fn simulate_sell(ref self: ContractState, token_amount: u256) -> u256 {
            let current_cap = self.get_market_cap();
            let new_cap = current_cap - token_amount;
            let new_price = self.get_price_for_market_cap(new_cap);
            let old_price = self.get_current_price();
            println!("[+] old_price {}, new_price {}", old_price, new_price);
            let av_price = (old_price + new_price) / 2;

            token_amount * av_price / MANTISSA
        }

        #[external(v0)]
        fn buy(ref self: ContractState, eth_amount: u256) -> u256 {
            let amount = self.simulate_buy(eth_amount);
            let eth_contract = IERC20Dispatcher { contract_address: ETH.try_into().unwrap() };
            eth_contract.transfer(get_contract_address(), amount);
            self.erc20.mint(get_caller_address(), amount);
            amount
        }

        #[external(v0)]
        fn sell(ref self: ContractState, token_amount: u256) -> u256 {
            let amount = self.simulate_sell(token_amount);
            self.erc20.burn(get_caller_address(), token_amount);
            amount
        }
        // fn sell(ref self: ContractState, eth_amount : u256) -> u256 {

        // }
    }
}
