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
        ERC20Component, ERC20HooksEmptyImpl,
        interface::{IERC20Mixin, IERC20MixinDispatcher, IERC20MixinDispatcherTrait}
    };
    use openzeppelin_access::ownable::OwnableComponent;

    // Local imports
    use crate::contract::interfaces::{
        IRouterDispatcher, IRouterDispatcherTrait, IFactoryDispatcher, IFactoryDispatcherTrait,
    };
    use cubit::f128::types::fixed::{Fixed, FixedTrait, FixedZero};

    // Constants
    const ETH: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
    const FACTORY_ADDRESS: felt252 =
        0x02a93ef8c7679a5f9b1fcf7286a6e1cadf2e9192be4bcb5cb2d1b39062697527;
    const ROUTER_ADDRESS: felt252 =
        0x049ff5b3a7d38e2b50198f408fa8281635b5bc81ee49ab87ac36c8324c214427;

    // Bonding curve parameters
    const BASE_X1E9: felt252 = 36090000;
    const EXPONENT_X1E9: felt252 = 36060;
    const MANTISSA: u256 = 1000000000000000000; // 1e18
    const MANTISSA_1e9: u256 = 1000000000; // 1e9
    const SCALING_FACTOR: u256 = 18446744073709552000; // 2^64
    const MAX_SUPPLY: u256 = 1000000000000000000000000000;
    const TRIGGER_LAUNCH: u256 = MAX_SUPPLY * 80 / 100;

    // Components
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Storage
    #[storage]
    struct Storage {
        buy_tax: u16,
        sell_tax: u16,
        creator: ContractAddress,
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
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        // View functions
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
        fn get_market_cap(self: @ContractState) -> u256 {
            let eth_contract = IERC20MixinDispatcher { contract_address: ETH.try_into().unwrap() };
            eth_contract.balance_of(get_contract_address())
        }

        // Price calculation functions
        #[external(v0)]
        fn get_price_for_market_cap(self: @ContractState, market_cap: u256) -> u256 {


            let (mantissa_1e9, base_normalized, exponent_normalized, market_cap_normalized) = self._normalize_data(market_cap);
            self
                ._calculate_price_x9(
                    base_normalized, market_cap_normalized, exponent_normalized, mantissa_1e9
                )
        }

        #[external(v0)]
        fn get_market_cap_for_price(self: @ContractState, price: u256) -> u256 {

            let (mantissa_1e9, base_normalized, exponent_normalized, price_normalized) = self
                ._normalize_data(price);

            self
                ._calculate_market_cap_x9(
                    price_normalized, base_normalized, exponent_normalized, mantissa_1e9
                )
        }

        // Trade simulation functions
        #[external(v0)]
        fn simulate_buy(self: @ContractState, eth_amount: u256) -> u256 {
            let (ret, _) = self._simulate_buy(eth_amount);
            ret
        }

        #[external(v0)]
        fn simulate_buy_for(self: @ContractState, token_amount: u256) -> u256 {
            let (ret, _) = self._simulate_buy_for(token_amount);
            ret
        }

        #[external(v0)]
        fn simulate_sell(self: @ContractState, token_amount: u256) -> u256 {
            let (taxed_amount, _) = self._simulate_sell(token_amount);
            taxed_amount
        }

        // Trading functions
        #[external(v0)]
        fn buy(ref self: ContractState, eth_amount: u256) -> u256 {
            let (amount, tax_amount) = self._simulate_buy(eth_amount);
            let eth_contract = IERC20MixinDispatcher { contract_address: ETH.try_into().unwrap() };
            let from: ContractAddress = get_caller_address();
            let to = get_contract_address();

            eth_contract.transfer_from(from, to, eth_amount);
            self._transfer_tax(tax_amount);
            self.erc20.mint(get_caller_address(), amount);
            amount
        }

        #[external(v0)]
        fn buy_for(ref self: ContractState, token_amount: u256) -> u256 {
            let (eth_amount, tax_amount) = self._simulate_buy_for(token_amount);
            let eth_contract = IERC20MixinDispatcher { contract_address: ETH.try_into().unwrap() };
            let from: ContractAddress = get_caller_address();
            let to = get_contract_address();

            eth_contract.transfer_from(from, to, eth_amount + tax_amount);
            self._transfer_tax(tax_amount);
            self.erc20.mint(get_caller_address(), token_amount);
            token_amount
        }

        #[external(v0)]
        fn sell(ref self: ContractState, token_amount: u256) -> u256 {
            let (amount, tax) = self._simulate_sell(token_amount);
            self.erc20.burn(get_caller_address(), token_amount);

            let eth_contract = IERC20MixinDispatcher { contract_address: ETH.try_into().unwrap() };
            assert!(self.get_market_cap() >= amount, "Not enough eth get");

            eth_contract.transfer(get_caller_address(), amount);
            self._transfer_tax(tax);
            amount
        }

        // Internal calculation functions
        fn _calculate_price_x9(
            self: @ContractState, base: Fixed, market_cap: Fixed, exponent: Fixed, mantissa: Fixed
        ) -> u256 {
            let exp_result = (market_cap * exponent).exp();
            let ret_x9_scaled: felt252 = (base * exp_result * mantissa).round().into();
            ret_x9_scaled.into() / SCALING_FACTOR * MANTISSA_1e9
        }

        fn _calculate_market_cap_x9(
            self: @ContractState, price: Fixed, base: Fixed, exponent: Fixed, mantissa: Fixed
        ) -> u256 {
            let ret_x9_scaled: felt252 = (((price / base).ln() / exponent) * mantissa)
                .round()
                .into();
            ret_x9_scaled.into() / SCALING_FACTOR
        }

        fn _normalize_data(self: @ContractState, data: u256) -> (Fixed, Fixed, Fixed, Fixed) {
            let mantissa_1e9: Fixed = FixedTrait::from_unscaled_felt(
                MANTISSA_1e9.try_into().unwrap()
            );
            let base_normalized = FixedTrait::from_unscaled_felt(BASE_X1E9) / mantissa_1e9;
            let data_normalized: Fixed = FixedTrait::from_unscaled_felt(
                (data / MANTISSA_1e9).try_into().unwrap()
            )
                / mantissa_1e9;
            let exponent_normalized = FixedTrait::from_unscaled_felt(EXPONENT_X1E9) / mantissa_1e9;

            (mantissa_1e9, base_normalized, exponent_normalized, data_normalized)
        }

        // Helper functions
        fn _simulate_buy(self: @ContractState, eth_amount: u256) -> (u256, u256) {
            let current_cap = self.get_market_cap();
            let tax_amount = self._simulate_tax(eth_amount, self.buy_tax.read().into());
            let taxed_amount = eth_amount - tax_amount;

            let new_cap = current_cap + taxed_amount;
            let new_price = self.get_price_for_market_cap(new_cap);
            let old_price = self.get_current_price();
            let av_price = (old_price + new_price) / 2;

            (taxed_amount * MANTISSA / av_price, tax_amount)
        }

        fn _simulate_buy_for(self: @ContractState, desired_tokens: u256) -> (u256, u256) {
            let current_cap = self.get_market_cap();
            let old_price = self.get_current_price();

            if current_cap == 0 {
                let eth_needed = desired_tokens * old_price / MANTISSA;
                let final_tax = self._simulate_tax(eth_needed, self.buy_tax.read().into());
                return (eth_needed, final_tax);
            }

            let approx_eth = desired_tokens * old_price / MANTISSA;
            let tax_amount = self._simulate_tax(approx_eth, self.buy_tax.read().into());
            let taxed_amount = approx_eth - tax_amount;
            let new_cap = current_cap + taxed_amount;
            let new_price = self.get_price_for_market_cap(new_cap);
            let av_price = (old_price + new_price) / 2;
            let eth_needed = desired_tokens * av_price / MANTISSA;

            let final_tax = self._simulate_tax(eth_needed, self.buy_tax.read().into());
            (eth_needed, final_tax)
        }

        fn _simulate_sell(self: @ContractState, token_amount: u256) -> (u256, u256) {
            let current_supply = self.total_supply();
            let current_cap = self.get_market_cap();

            let portion = token_amount * MANTISSA / current_supply;
            let cap_reduction = current_cap * portion / MANTISSA;
            let new_cap = current_cap - cap_reduction;

            let old_price = self.get_current_price();
            let new_price = self.get_price_for_market_cap(new_cap);
            let av_price = (old_price + new_price) / 2;

            let untaxed_amount = token_amount * av_price / MANTISSA;
            let tax = self._simulate_tax(untaxed_amount, self.sell_tax.read().into());
            (untaxed_amount - tax, tax)
        }

        fn _simulate_tax(self: @ContractState, amount: u256, tax_percentage_x100: u256) -> u256 {
            amount * tax_percentage_x100 / 10000
        }

        fn _transfer_tax(self: @ContractState, amount: u256) -> u256 {
            let eth_contract = IERC20MixinDispatcher { contract_address: ETH.try_into().unwrap() };
            eth_contract.transfer(ETH.try_into().unwrap(), amount);
            amount
        }
    }
}