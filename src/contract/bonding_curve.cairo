#[starknet::contract]
mod BondingCurve {
    // Imports grouped by functionality
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use core::{
        to_byte_array::FormatAsByteArray,
        starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess}
    };

    // OpenZeppelin imports
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20DispatcherTrait, IERC20Dispatcher}
    };
    // use openzeppelin_access::ownable::OwnableComponent;

    // Local imports
    use crate::contract::interfaces::{
        IRouterDispatcher, IRouterDispatcherTrait, IFactoryDispatcher, IFactoryDispatcherTrait
    };
    use cubit::f128::types::fixed::{Fixed, FixedTrait, FixedZero};


    const MANTISSA_1e18: u256 = 1000000000000000000;
    const MANTISSA_1e12: u256 = 1000000000000;
    const MANTISSA_1e9: u256 = 1000000000;
    const MANTISSA_1e6: u256 = 1000000;


    // Constants
    const ETH: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
    const FACTORY_ADDRESS: felt252 =
        0x02a93ef8c7679a5f9b1fcf7286a6e1cadf2e9192be4bcb5cb2d1b39062697527;
    const ROUTER_ADDRESS: felt252 =
        0x049ff5b3a7d38e2b50198f408fa8281635b5bc81ee49ab87ac36c8324c214427;

    // Bonding curve parameters

    const SCALING_FACTOR: u256 = 18446744073709552000; // 2^64
    const MAX_SUPPLY: u256 = 1000000000 * MANTISSA_1e6;
    const TRIGGER_LAUNCH: u256 = MAX_SUPPLY * 80 / 100;
    const LP_SUPPLY: u256 = MAX_SUPPLY - TRIGGER_LAUNCH;

    // Components
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    // component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Storage
    #[storage]
    struct Storage {
        buy_tax: u16,
        sell_tax: u16,
        creator: ContractAddress,
        protocol: ContractAddress,
        controlled_market_cap: u256,
        base_price: Fixed,
        exponent: Fixed,
        pair_address: ContractAddress,
        is_bond_closed: bool,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        // #[substorage(v0)]
    // ownable: OwnableComponent::Storage,
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        // #[flat]
    // OwnableEvent: OwnableComponent::Event,
    }

    // Implementation blocks
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    // impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    #[constructor]
    fn constructor(
        ref self: ContractState,
        _protocol_wallet: ContractAddress,
        _owner: ContractAddress,
        _name: felt252,
        _symbol: felt252,
        price_x1e9: felt252,
        exponent_x1e9: felt252,
        buy_tax_percentage_x100: u16,
        sell_tax_percentage_x100: u16
    ) {
        let (_name, _symbol) = (_name.format_as_byte_array(10), _symbol.format_as_byte_array(10));
        let mantissa: u64 = MANTISSA_1e9.try_into().unwrap();
        let base_price_ = FixedTrait::from_unscaled_felt(price_x1e9) / mantissa.into();
        let exponent_ = FixedTrait::from_unscaled_felt(exponent_x1e9) / mantissa.into();
        self.base_price.write(base_price_);
        self.exponent.write(exponent_);
        self.erc20.initializer(_name, _symbol);
        // self.ownable.initializer(_owner);
        self.buy_tax.write(buy_tax_percentage_x100);
        self.sell_tax.write(sell_tax_percentage_x100);
        self.creator.write(_owner);
        self.protocol.write(_protocol_wallet);
        self.controlled_market_cap.write(0);
        self.is_bond_closed.write(false);
    }


    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.ERC20_name.read()
        }

        #[external(v0)]
        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.ERC20_symbol.read()
        }

        #[external(v0)]
        fn decimals(self: @ContractState) -> u8 {
            6
        }
        // View functions
        #[external(v0)]
        fn get_current_price(self: @ContractState) -> u256 {
            self.get_price_for_supply(self.erc20.total_supply())
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
        fn market_cap(self: @ContractState) -> u256 {
            self.controlled_market_cap.read()
        }


        // Price calculation functions
        #[external(v0)]
        fn get_price_for_supply(self: @ContractState, supply: u256) -> u256 {
            let (_, base_normalized, exponent_normalized) = self._get_price_consts();
            let mantissa_1e6: Fixed = FixedTrait::from_unscaled_felt(
                MANTISSA_1e6.try_into().unwrap()
            );

            let supply_normalized: Fixed = FixedTrait::from_unscaled_felt(
                (supply).try_into().unwrap()
            )
                / mantissa_1e6;
            println!("supply_normalized ");
            self._calculate_price(base_normalized, supply_normalized, exponent_normalized)
        }

        #[external(v0)]
        fn market_cap_for_price(self: @ContractState, price: u256) -> u256 {
            let (mantissa_1e9, base_normalized, exponent_normalized) = self._get_price_consts();
            let price_normalized: Fixed = FixedTrait::from_unscaled_felt(
                (price / MANTISSA_1e9).try_into().unwrap()
            )
                / mantissa_1e9;

            self._calculate_supply(price_normalized, base_normalized, exponent_normalized)
        }

        // Trade simulation functions
        #[external(v0)]
        fn simulate_buy(self: @ContractState, token_amount: u256) -> u256 {
            let (ret, _) = self._simulate_buy(token_amount);
            ret
        }

        // #[external(v0)]
        // fn simulate_buy_for(self: @ContractState, eth_amount: u256) -> u256 {
        //     let (ret, _) = self._simulate_buy_for(eth_amount);
        //     ret
        // }

        #[external(v0)]
        fn simulate_sell(self: @ContractState, token_amount: u256) -> u256 {
            let (taxed_amount, _) = self._simulate_sell(token_amount);
            taxed_amount
        }

        #[external(v0)]
        fn get_taxes(self: @ContractState) -> (u16, u16) {
            (self.buy_tax.read().into(), self.sell_tax.read().into())
        }

        #[external(v0)]
        fn buy(ref self: ContractState, token_amount: u256) -> u256 {
            self.require_in_bond_stage(true);

            assert!(token_amount > 0, "BondingCurve: amount 0");
            let ts = self.erc20.total_supply();
            let is_cap_reached: bool = ts + token_amount >= TRIGGER_LAUNCH;

            let token_amount = if is_cap_reached {
                TRIGGER_LAUNCH - ts
            } else {
                token_amount
            };

            println!("simulating buy");
            let eth_contract = IERC20Dispatcher { contract_address: ETH.try_into().unwrap() };
            let (eth_amount, tax_amount) = self._simulate_buy(token_amount);
            println!("eth_amount: {}", eth_amount);
            assert!(
                eth_contract.balance_of(get_caller_address()) >= eth_amount,
                "BondingCurve: Insufficient balance"
            );

            // Handle regular buy
            println!("executing buy");
            self._execute_buy(eth_amount, tax_amount, token_amount, get_caller_address());
            if is_cap_reached {
                println!("launching pool");
                self._launch_pool();
            }
            eth_amount
        }


        #[external(v0)]
        fn sell(ref self: ContractState, token_amount: u256) -> u256 {
            self.require_in_bond_stage(true);
            assert!(
                token_amount <= self.erc20.balance_of(get_caller_address()),
                "BondingCurve: Insufficient balance"
            );
            assert!(token_amount > 0, "BondingCurve: amount 0");
            self.erc20.burn(get_caller_address(), token_amount);

            let (amount, tax) = self._simulate_sell(token_amount);
            assert!(self.market_cap() >= amount, "BondingCurve: Insufficient market cap");

            let eth_contract = IERC20Dispatcher { contract_address: ETH.try_into().unwrap() };
            self._transfer_tax(tax);
            eth_contract.transfer(get_caller_address(), amount);
            self._decrease_market_cap(amount);
            amount
        }

        #[external(v0)]
        fn skim(ref self: ContractState) -> u256 {
            let eth_contract = IERC20Dispatcher { contract_address: ETH.try_into().unwrap() };
            let balance_eth = eth_contract.balance_of(get_contract_address());
            if self.market_cap() < balance_eth {
                self._transfer_tax(balance_eth - self.market_cap())
            } else {
                0
            }
        }


        fn _execute_buy(
            ref self: ContractState,
            eth_amount: u256,
            tax_amount: u256,
            mint_amount: u256,
            from: ContractAddress,
        ) {
            let eth_contract = IERC20Dispatcher { contract_address: ETH.try_into().unwrap() };
            eth_contract.transfer_from(from, get_contract_address(), eth_amount + tax_amount);
            self._transfer_tax(tax_amount);
            self._increase_market_cap(eth_amount);
            self.erc20.mint(from, mint_amount);
        }

        fn _increase_market_cap(ref self: ContractState, amount: u256) -> u256 {
            let new_market_cap = self.controlled_market_cap.read() + amount;
            self.controlled_market_cap.write(new_market_cap);
            new_market_cap
        }

        fn _decrease_market_cap(ref self: ContractState, amount: u256) -> u256 {
            let new_market_cap = self.controlled_market_cap.read() - amount;
            self.controlled_market_cap.write(new_market_cap);
            new_market_cap
        }

        fn _launch_pool(ref self: ContractState) {
            let this_address = get_contract_address();
            self.erc20.mint(this_address, LP_SUPPLY);

            let eth_address = ETH.try_into().expect('ETH address is invalid');
            let router_address = ROUTER_ADDRESS.try_into().expect('Router address is invalid');
            let factory_address = FACTORY_ADDRESS.try_into().expect('Factory address is invalid');

            let eth_contract = IERC20Dispatcher { contract_address: eth_address };
            let factory_contract = IFactoryDispatcher { contract_address: factory_address, };
            let router_contract = IRouterDispatcher { contract_address: router_address };
            let pair_address = factory_contract.create_pair(eth_address, this_address);

            let market_cap = self.market_cap();
            println!("market cap: {} - balance {}", market_cap, eth_contract.balance_of(this_address));
            println!("token balnce : {}", self.erc20.balance_of(this_address));

            eth_contract.approve(router_address, ~0_u256);
            self.erc20._approve(this_address, router_address, ~0_u256);
            println!("add liquidity");
            let (_amount_a, _amount_b, _amount_lp) = router_contract
                .add_liquidity(
                    pair_address, market_cap, LP_SUPPLY, 0, 0, self.creator.read(), ~0_64
                );

            println!("checking rest");
            let rests = eth_contract.balance_of(this_address);
            if rests > 0 {
                self._transfer_tax(rests);
            }

            self.is_bond_closed.write(true);
        }


        /// Internal functions READ

        fn _calculate_price(
            self: @ContractState, base: Fixed, supply: Fixed, exponent: Fixed
        ) -> u256 {
            let mantissa_1e9: Fixed = FixedTrait::from_unscaled_felt(
                MANTISSA_1e9.try_into().unwrap()
            );
            println!("supply");

            let y_calc = supply / 1000000_u32.into() * exponent;

            let exp_result = (y_calc).exp();
            let ret_x9_scaled: felt252 = (base * exp_result * mantissa_1e9).round().into();
            let ret_x9_unscaled: u256 = ret_x9_scaled.into()  / SCALING_FACTOR;
            let ret = ret_x9_unscaled * MANTISSA_1e9;
            println!("price: {}", ret);
            ret
        }

        fn _calculate_supply(
            self: @ContractState, base: Fixed, price: Fixed, exponent: Fixed
        ) -> u256 {
            let mantissa_1e9: Fixed = FixedTrait::from_unscaled_felt(
                MANTISSA_1e9.try_into().unwrap()
            );
            let price_unscaled = price / mantissa_1e9;
            let ln_result = (price_unscaled / base).ln();

            let supply_calc = ln_result / exponent * 1000000_u32.into();

            let ret_x9_scaled: felt252 = (supply_calc).round().into();
            let ret = ret_x9_scaled.into() * MANTISSA_1e9 / SCALING_FACTOR;
            ret
        }

        fn _get_price_consts(self: @ContractState) -> (Fixed, Fixed, Fixed) {
            let mantissa_1e9: Fixed = FixedTrait::from_unscaled_felt(
                MANTISSA_1e9.try_into().unwrap()
            );

            (mantissa_1e9, self.base_price.read(), self.exponent.read())
        }
        fn require_in_bond_stage(self: @ContractState, is_it: bool) {
            let is_bond_closed = self.is_bond_closed.read();
            if !is_it {
                assert!(is_bond_closed, "Bonding stage is closed");
            } else {
                assert!(!is_bond_closed, "Bonding stage is open");
            }
        }

        fn _simulate_sell(self: @ContractState, token_amount: u256) -> (u256, u256) {
            let current_supply = self.erc20.total_supply();
            if token_amount > current_supply {
                return (0, 0);
            };
            let new_supply = current_supply - token_amount;
            let av_price = (self.get_current_price() + self.get_price_for_supply(new_supply)) / 2;
            let eth_amount = token_amount * av_price / MANTISSA_1e6;
            self._simulate_sell_tax(eth_amount)
        }

        fn _simulate_buy(self: @ContractState, desired_tokens: u256) -> (u256, u256) {
            let current_supply = self.erc20.total_supply();
            let new_supply = current_supply + desired_tokens;

            let old_price = self.get_current_price();
            println!("old price: {}", old_price);
            let new_price = self.get_price_for_supply(new_supply);
            println!("new price: {}", new_price);

            let av_price = (old_price + new_price) / 2;

            let eth_needed = desired_tokens
                * av_price
                / MANTISSA_1e6; //Here the mantissa_1e6 because token decimals  6 but price and ether is 18
            self._simulate_buy_tax(eth_needed)
        }
        fn _simulate_buy_tax(self: @ContractState, amount: u256) -> (u256, u256) {
            let taxed_eth = amount / (10000 - self.buy_tax.read()).into() * 10000_u256;
            (taxed_eth, taxed_eth - amount)
        }
        fn _simulate_sell_tax(self: @ContractState, amount: u256) -> (u256, u256) {
            let tax = amount * self.sell_tax.read().into() / 10000;
            (amount - tax, tax)
        }

        fn _transfer_tax(self: @ContractState, amount: u256) -> u256 {
            let eth_contract = IERC20Dispatcher { contract_address: ETH.try_into().unwrap() };
            eth_contract.transfer(self.protocol.read(), amount);
            amount
        }
    }

    /// Hooks
    pub impl ERC20Hooks of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {}

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {}
    }
}
