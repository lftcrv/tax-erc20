use starknet::{ContractAddress, ClassHash};


#[starknet::interface]
pub trait IPair<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress) -> u256;

    fn burn(ref self: TContractState, to: ContractAddress) -> (u256, u256);

    fn swap(
        ref self: TContractState,
        amount_0_out: u256,
        amount_1_out: u256,
        to: ContractAddress,
        data: Array<felt252>,
    );

    fn out_given_in(self: @TContractState, amount_in: u256, first_token_in: bool) -> u256;

    fn in_given_out(self: @TContractState, amount_out: u256, first_token_in: bool) -> u256;

    fn skim(ref self: TContractState, to: ContractAddress);

    fn sync(ref self: TContractState);

    fn set_swap_fee(ref self: TContractState, new_swap_fee: u16);

    fn token_0(self: @TContractState) -> ContractAddress;

    fn token_1(self: @TContractState) -> ContractAddress;

    fn get_reserves(self: @TContractState) -> (u256, u256);

    fn k_last(self: @TContractState) -> u256;

    fn swap_fee(self: @TContractState) -> u16;
}


#[starknet::interface]
pub trait IFactory<TContractState> {
    fn all_pairs(self: @TContractState) -> Array<ContractAddress>;
    fn get_pair(
        self: @TContractState, token0: ContractAddress, token1: ContractAddress
    ) -> ContractAddress;
    fn num_of_pairs(self: @TContractState) -> u32;
    fn fee_to(self: @TContractState) -> ContractAddress;
    fn fee_to_setter(self: @TContractState) -> ContractAddress;
    fn pair_contract_class_hash(self: @TContractState) -> ClassHash;
    fn stable_pair_contract_class_hash(self: @TContractState) -> ClassHash;
    fn create_pair(
        ref self: TContractState, token_a: ContractAddress, token_b: ContractAddress,
    ) -> ContractAddress;
    fn create_stable_pair(
        ref self: TContractState,
        token_a: ContractAddress,
        token_b: ContractAddress,
        initial_amp: u32,
        rate_provider_a: ContractAddress,
        rate_provider_b: ContractAddress,
    ) -> ContractAddress;
    fn set_fee_to(ref self: TContractState, new_fee_to: ContractAddress);
    fn set_fee_to_setter(ref self: TContractState, new_fee_to_setter: ContractAddress);
    fn replace_pair_contract_hash(ref self: TContractState, new_pair_contract_class: ClassHash);
    fn replace_stable_pair_contract_hash(
        ref self: TContractState, new_stable_pair_contract_class: ClassHash,
    );
    fn migrate_pairs(ref self: TContractState, pairs: Array<ContractAddress>);
}


#[starknet::interface]
pub trait IRouter<TContractState> {
    // Setup functions
    fn initializer(
        ref self: TContractState, factory: ContractAddress, proxy_admin: ContractAddress
    );
    fn factory(self: @TContractState) -> ContractAddress;

    // View functions
    fn sort_tokens(
        self: @TContractState, token_a: ContractAddress, token_b: ContractAddress
    ) -> (ContractAddress, ContractAddress);

    fn quote(self: @TContractState, amount_a: u256, reserve_a: u256, reserve_b: u256) -> u256;

    fn get_amount_out(
        self: @TContractState, amount_in: u256, reserve_in: u256, reserve_out: u256
    ) -> u256;

    fn get_amount_in(
        self: @TContractState, amount_out: u256, reserve_in: u256, reserve_out: u256
    ) -> u256;

    fn get_amounts_out(
        self: @TContractState, amount_in: u256, path: Array<ContractAddress>
    ) -> Array<u256>;

    fn get_amounts_in(
        self: @TContractState, amount_out: u256, path: Array<ContractAddress>
    ) -> Array<u256>;

    // State-changing functions
    fn add_liquidity(
        ref self: TContractState,
        token_a: ContractAddress,
        token_b: ContractAddress,
        amount_a_desired: u256,
        amount_b_desired: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        to: ContractAddress,
        deadline: felt252
    ) -> (u256, u256, u256);

    fn remove_liquidity(
        ref self: TContractState,
        token_a: ContractAddress,
        token_b: ContractAddress,
        liquidity: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        to: ContractAddress,
        deadline: felt252
    ) -> (u256, u256);

    fn swap_exact_tokens_for_tokens(
        ref self: TContractState,
        amount_in: u256,
        amount_out_min: u256,
        path: Array<ContractAddress>,
        to: ContractAddress,
        deadline: felt252
    ) -> Array<u256>;

    fn swap_tokens_for_exact_tokens(
        ref self: TContractState,
        amount_out: u256,
        amount_in_max: u256,
        path: Array<ContractAddress>,
        to: ContractAddress,
        deadline: felt252
    ) -> Array<u256>;
}

// Events
#[derive(Drop, starknet::Event)]
pub struct Upgraded {
    pub implementation: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct AdminChanged {
    pub previous_admin: ContractAddress,
    pub new_admin: ContractAddress,
}
#[derive(Drop, Serde)]
pub struct TokenLocked {
    pub end_timestamp: u64,
    pub start_timestamp: u64,
    pub initial_amount: u256,
    pub current_amount: u256,
    pub owner: ContractAddress
}

#[starknet::interface]
pub trait IGradualLocker<TContractState> {
    fn claim(ref self: TContractState, token: ContractAddress) -> u256;
    fn lock(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
        end_timestamp: u64,
        owner: ContractAddress,
    ) -> TokenLocked;
    fn lockCamel(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
        end_timestamp: u64,
        owner: ContractAddress,
    ) -> TokenLocked;
    #[external(v0)]
    fn get_lock(
        self: @TContractState, owner: ContractAddress, token: ContractAddress,
    ) -> TokenLocked;
    fn supports_interface(self: @TContractState, interface_id: felt252) -> bool;
}

pub const GRADUAL_LOCKER_ID: felt252 =
    0xb8d81441e297b31db874ccc7e13400572864b7194343047d5b1f49cae8560e;
