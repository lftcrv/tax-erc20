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
        ERC20Component, interface::{IERC20Mixin, IERC20MixinDispatcher, IERC20MixinDispatcherTrait}
    };
    use openzeppelin_access::ownable::OwnableComponent;

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
    const BASE_X1E9: felt252 = 10;
    const EXPONENT_X1E9: felt252 = 6130200;

    const SCALING_FACTOR: u256 = 18446744073709552000; // 2^64
    const MAX_SUPPLY: u256 = 1000000000 * MANTISSA_1e6;
    const TRIGGER_LAUNCH: u256 = MAX_SUPPLY * 80 / 100;
    const LP_SUPPLY: u256 = MAX_SUPPLY - TRIGGER_LAUNCH;

    // Components
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Storage
    #[storage]
    struct Storage {
        buy_tax: u16,
        sell_tax: u16,
        creator: ContractAddress,
        protocol: ContractAddress,
        controlled_market_cap: u256,
        pair_address: ContractAddress,
        is_bond_closed: bool,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    // Implementation blocks
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        _owner: ContractAddress,
        _protocol: ContractAddress,
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
        self.creator.write(get_caller_address());
        self.protocol.write(_protocol);
        self.controlled_market_cap.write(0);
        self.is_bond_closed.write(false);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        // View functions
        #[external(v0)]
        fn get_current_price(self: @ContractState) -> u256 {
            self.get_price_for_market_cap(self.market_cap())
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
        fn get_price_for_market_cap(self: @ContractState, market_cap: u256) -> u256 {
            let (_, base_normalized, exponent_normalized) = self._normalize_data(market_cap);
            let mantissa_1e9: Fixed = FixedTrait::from_unscaled_felt(
                MANTISSA_1e9.try_into().unwrap()
            );

            let market_cap_normalized: Fixed = FixedTrait::from_unscaled_felt(
                (market_cap / MANTISSA_1e9).try_into().unwrap()
            )
                / mantissa_1e9;

            self._calculate_price(base_normalized, market_cap_normalized, exponent_normalized)
        }

        #[external(v0)]
        fn market_cap_for_price(self: @ContractState, price: u256) -> u256 {
            let (mantissa_1e9, base_normalized, exponent_normalized) = self._normalize_data(price);
            let price_normalized: Fixed = FixedTrait::from_unscaled_felt(
                (price / MANTISSA_1e9).try_into().unwrap()
            )
                / mantissa_1e9;

            self._calculate_market_cap(price_normalized, base_normalized, exponent_normalized)
        }

        // Trade simulation functions
        #[external(v0)]
        fn simulate_buy(self: @ContractState, token_amount: u256) -> u256 {
            let (ret, _) = self._simulate_buy(token_amount);
            ret
        }

        #[external(v0)]
        fn simulate_buy_for(self: @ContractState, eth_amount: u256) -> u256 {
            let (ret, _) = self._simulate_buy_for(eth_amount);
            ret
        }

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
        fn get_supply_from_market_cap(self: @ContractState, market_cap: u256) -> u256 {
            // If market cap is 0, supply would be 0
            if market_cap == 0 {
                return 0;
            }

            // Get our normalized constants
            let (mantissa_1e9, base_normalized, exponent_normalized) = self
                ._normalize_data(market_cap);

            // Convert market cap to Fixed
            let market_cap_normalized: Fixed = FixedTrait::from_unscaled_felt(
                (market_cap / MANTISSA_1e9).try_into().unwrap()
            )
                / mantissa_1e9;

            // Calculate e^(kM)
            let exponent_result = (market_cap_normalized * exponent_normalized).exp();

            // Calculate B * e^(kM)
            let denominator = base_normalized * exponent_result;

            // Supply = M / (B * e^(kM))
            // We do market_cap_normalized / denominator * MANTISSA_1e18 to get the final supply
            let supply_normalized = market_cap_normalized / denominator;

            // Convert back to u256 and scale appropriately
            let supply_scaled: felt252 = (supply_normalized * mantissa_1e9).round().into();
            supply_scaled.into() * MANTISSA_1e18 / SCALING_FACTOR
        }

        #[external(v0)]
        fn get_market_cap_from_supply(self: @ContractState, supply: u256) -> u256 {
            if supply == 0 {
                return 0;
            }
            let mantissa_1e6: Fixed = FixedTrait::from_unscaled_felt(
                MANTISSA_1e6.try_into().unwrap()
            );

            // Get our normalized constants
            let (mantissa_1e9, base_normalized, exponent_normalized) = self._normalize_data(0);

            // Convert supply to Fixed
            let supply_normalized: Fixed = FixedTrait::from_unscaled_felt(
                (supply).try_into().unwrap()
            )
                / mantissa_1e6;

            // Initial guess: use current price for approximation
            let current_price = self.get_current_price();
            let mut market_cap_guess = supply * current_price / MANTISSA_1e18;

            // Convert guess to normalized form
            let mut m_normalized: Fixed = FixedTrait::from_unscaled_felt(
                (market_cap_guess / MANTISSA_1e9).try_into().unwrap()
            )
                / mantissa_1e9;

            // Calculate e^(kM) for the guess
            let exp_result = (m_normalized * exponent_normalized).exp();

            // S = M/(B * e^(kM))
            // Therefore: M = S * B * e^(kM)
            let new_m = supply_normalized * base_normalized * exp_result;

            // Convert back to u256
            let market_cap_scaled: felt252 = (new_m * mantissa_1e9).round().into();
            market_cap_scaled.into() * MANTISSA_1e9 / SCALING_FACTOR
        }
        // Trading functions
        // Highly unoptimised
        #[external(v0)]
        fn buy(ref self: ContractState, token_amount: u256) -> u256 {
            self.require_in_bond_stage(true);
            let eth_contract = IERC20MixinDispatcher { contract_address: ETH.try_into().unwrap() };
            let (eth_amount, tax_amount) = self._simulate_buy(token_amount);
            assert!(
                eth_contract.balance_of(get_caller_address()) >= eth_amount, "Insufficient balance"
            );
            // Simulate buy to get amounts

            // Get contract addresses

            // Check if launch should be triggered
            let total_supply = self.erc20.total_supply();
            let total_amount = token_amount + total_supply;
            //println!("buy total_amount: {}", total_amount);

            if total_amount >= TRIGGER_LAUNCH {
                return self
                    ._handle_launch_trigger(total_amount, token_amount, eth_amount, tax_amount);
            }

            // Handle regular buy
            self._execute_buy(eth_amount, tax_amount, token_amount, get_caller_address());

            eth_amount
        }

        #[external(v0)]
        fn buy_for(ref self: ContractState, eth_amount: u256) -> u256 {
            self.require_in_bond_stage(true);
            //println!("--------- buy_for begin -----------");
            let eth_contract = IERC20MixinDispatcher { contract_address: ETH.try_into().unwrap() };
            assert!(
                eth_contract.balance_of(get_caller_address()) >= eth_amount, "Insufficient balance"
            );
            let (token_amount, tax_amount) = self._simulate_buy_for(eth_amount);
            //println!("eth_amount: {}", eth_amount);

            let from: ContractAddress = get_caller_address();
            let total_supply = self.erc20.total_supply();
            let total_amount = token_amount + total_supply;
            //println!("buy total_amount: {}", total_amount);

            if total_amount >= TRIGGER_LAUNCH {
                return self
                    ._handle_launch_trigger(total_amount, token_amount, eth_amount, tax_amount);
            }
            //println!("--------- _execute_buy -----------");
            self._execute_buy(eth_amount, tax_amount, token_amount, from);
            //println!("--------- buy_for end -----------");
            token_amount
        }


        #[external(v0)]
        fn sell(ref self: ContractState, token_amount: u256) -> u256 {
            assert!(
                token_amount <= self.erc20.balance_of(get_caller_address()), "Insufficient balance"
            );
            self.erc20.burn(get_caller_address(), token_amount);
            let (amount, tax) = self._simulate_sell(token_amount);
            assert!(self.market_cap() >= amount, "Insufficient market cap");

            let eth_contract = IERC20MixinDispatcher { contract_address: ETH.try_into().unwrap() };
            self._transfer_tax(tax);
            eth_contract.transfer(get_caller_address(), amount);
            self._decrease_market_cap(amount);

            amount
        }


        // INTERNAL WRITE
        fn _handle_launch_trigger(
            ref self: ContractState,
            total_amount: u256,
            amount: u256,
            eth_amount: u256,
            tax_amount: u256
        ) -> u256 {
            //println!("Launch trigger reached");
            let diff = total_amount - TRIGGER_LAUNCH;
            if diff > 0 {
                //println!("diff > 0");
                let new_amount = total_amount - diff;
                //println!("new_amount: {}", new_amount);
                let new_eth_amount = eth_amount * new_amount / amount;
                //println!("new_eth_amount: {}", new_eth_amount);
                let adjusted_tax = tax_amount * new_amount / amount;
                //println!("adjusted_tax: {}", adjusted_tax);
                self._execute_buy(new_eth_amount, adjusted_tax, new_amount, get_caller_address());
            } else {
                //println!("diff <= 0");
                self._execute_buy(eth_amount, tax_amount, amount, get_caller_address());
            }
            //println!("----------------Launch pool -----------");
            self._launch_pool();
            //println!("----------------Launch triggered -----------");

            amount
        }
        fn _execute_buy(
            ref self: ContractState,
            eth_amount: u256,
            tax_amount: u256,
            mint_amount: u256,
            from: ContractAddress,
        ) {
            let eth_contract = IERC20MixinDispatcher { contract_address: ETH.try_into().unwrap() };
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

        fn _launch_pool(ref self: ContractState,) {
            let this_address = get_contract_address();
            //let this_address_felt: felt252 = this_address.into();
            //println!("this_address: {}", this_address_felt);
            self.erc20.mint(this_address, LP_SUPPLY);
            let eth_address = ETH.try_into().expect('ETH address is invalid');
            let router_address = ROUTER_ADDRESS.try_into().expect('Router address is invalid');
            let factory_address = FACTORY_ADDRESS.try_into().expect('Factory address is invalid');

            let eth_contract = IERC20MixinDispatcher { contract_address: eth_address };
            let factory_contract = IFactoryDispatcher { contract_address: factory_address, };
            let router_contract = IRouterDispatcher { contract_address: router_address };
            let pair_address = factory_contract.create_pair(eth_address, this_address);


            let market_cap = self.market_cap();
            eth_contract.approve(router_address, market_cap);
            self.erc20._approve(this_address, router_address, LP_SUPPLY);
            
            let (_amount_a, _amount_b, _amount_lp) = router_contract
                .add_liquidity(pair_address, market_cap, LP_SUPPLY, 0, 0, this_address, ~0_64);


            let rests = eth_contract.balance_of(this_address);
            if rests > 0 {
                self._transfer_tax(eth_contract.balance_of(this_address));
            }

            self.is_bond_closed.write(true);
        }


        /// Internal functions READ

        fn _calculate_price(
            self: @ContractState, base: Fixed, market_cap: Fixed, exponent: Fixed
        ) -> u256 {
            let mantissa_1e9: Fixed = FixedTrait::from_unscaled_felt(
                MANTISSA_1e9.try_into().unwrap()
            );

            let y_calc = market_cap * exponent;

            let exp_result = (y_calc).exp();
            let ret_x9_scaled: felt252 = (base * exp_result * mantissa_1e9).round().into();
            let ret_x9_unscaled: u256 = ret_x9_scaled.into() / SCALING_FACTOR;
            let ret = ret_x9_unscaled * MANTISSA_1e9;
            ret
        }

        fn _calculate_market_cap(
            self: @ContractState, price: Fixed, base: Fixed, exponent: Fixed,
        ) -> u256 {
            let mantissa_1e9: Fixed = FixedTrait::from_unscaled_felt(
                MANTISSA_1e9.try_into().unwrap()
            );
            let ret_x9_scaled: felt252 = (((price / base).ln() / exponent) * mantissa_1e9)
                .round()
                .into();
            ret_x9_scaled.into() * MANTISSA_1e9 / SCALING_FACTOR
        }

        fn _normalize_data(self: @ContractState, data: u256) -> (Fixed, Fixed, Fixed) {
            let mantissa_1e9: Fixed = FixedTrait::from_unscaled_felt(
                MANTISSA_1e9.try_into().unwrap()
            );
            let base_normalized = FixedTrait::from_unscaled_felt(BASE_X1E9) / mantissa_1e9;

            let exponent_normalized = FixedTrait::from_unscaled_felt(EXPONENT_X1E9) / mantissa_1e9;

            (mantissa_1e9, base_normalized, exponent_normalized)
        }
        fn require_in_bond_stage(self: @ContractState, is_it: bool) {
            let is_bond_closed = self.is_bond_closed.read();
            if !is_it {
                assert!(is_bond_closed, "Bonding stage is closed");
            } else {
                assert!(!is_bond_closed, "Bonding stage is open");
            }
        }


        // Helper functions
        fn _simulate_buy_for(self: @ContractState, eth_amount: u256) -> (u256, u256) {
            let current_cap = self.market_cap();
            //println!("current_cap: {}", current_cap);
            let tax_amount = self._simulate_tax(eth_amount, self.buy_tax.read().into());
            let taxed_amount = eth_amount - tax_amount;

            let new_cap = current_cap + taxed_amount;
            //println!("get_price_for_market_cap");
            let new_price = self.get_price_for_market_cap(new_cap);
            //println!("=> {}", new_price);
            //println!("get_current_price");
            let old_price = self.get_current_price();
            //println!("=> {}", old_price);
            let av_price = (old_price + new_price) / 2;

            //println!("return");
            (taxed_amount * MANTISSA_1e6 / av_price, tax_amount)
        }

        fn _simulate_buy(self: @ContractState, desired_tokens: u256) -> (u256, u256) {
            let current_cap = self.market_cap();

            // Special case: Empty market cap
            if current_cap == 0 {
                let price = self.get_price_for_market_cap(0);
                let eth_needed = desired_tokens * price / MANTISSA_1e18;
                let tax_amount = self._simulate_tax(eth_needed, self.buy_tax.read().into());
                return (eth_needed, tax_amount);
            }

            let current_supply = self.get_supply_from_market_cap(current_cap);
            let target_supply = current_supply + desired_tokens;

            // Calculate required market cap for target supply
            let target_cap = self.get_market_cap_from_supply(target_supply);
            let eth_needed = target_cap - current_cap;

            let tax_amount = self._simulate_tax(eth_needed, self.buy_tax.read().into());
            (eth_needed, tax_amount)
        }


        fn _simulate_sell(self: @ContractState, token_amount: u256) -> (u256, u256) {
            let current_supply = self.total_supply();
            let current_cap = self.market_cap();

            let portion = token_amount * MANTISSA_1e6 / current_supply;
            let cap_reduction = current_cap * portion / MANTISSA_1e6;
            let new_cap = current_cap - cap_reduction;

            let old_price = self.get_current_price();
            let new_price = self.get_price_for_market_cap(new_cap);
            let av_price = (old_price + new_price) / 2;

            let untaxed_amount = token_amount * av_price / (MANTISSA_1e18 / MANTISSA_1e6);
            let tax = self._simulate_tax(untaxed_amount, self.sell_tax.read().into());
            (untaxed_amount - tax, tax)
        }

        fn _simulate_tax(self: @ContractState, amount: u256, tax_percentage_x100: u256) -> u256 {
            amount * tax_percentage_x100 / 10000
        }

        fn _transfer_tax(self: @ContractState, amount: u256) -> u256 {
            let eth_contract = IERC20MixinDispatcher { contract_address: ETH.try_into().unwrap() };
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
