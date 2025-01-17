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
    fn quote(self: @TContractState, amount_a: u256, reserve_a: u256, reserve_b: u256) -> u256;

    fn get_amounts_out(
        self: @TContractState,
        amount_in: u256,
        token_in: ContractAddress,
        pairs: Span<ContractAddress>,
    ) -> (Array<u256>, ContractAddress);

    fn get_amounts_in(
        self: @TContractState,
        amount_out: u256,
        token_out: ContractAddress,
        pairs: Span<ContractAddress>,
    ) -> (Array<u256>, ContractAddress);

    fn add_liquidity(
        ref self: TContractState,
        pair: ContractAddress,
        amount_0_desired: u256,
        amount_1_desired: u256,
        amount_0_min: u256,
        amount_1_min: u256,
        to: ContractAddress,
        deadline: u64,
    ) -> (u256, u256, u256);

    fn remove_liquidity(
        ref self: TContractState,
        pair: ContractAddress,
        liquidity: u256,
        amount_0_min: u256,
        amount_1_min: u256,
        to: ContractAddress,
        deadline: u64,
    ) -> (u256, u256);
    

    fn swap_exact_tokens_for_tokens(
        ref self: TContractState,
        amount_in: u256,
        amount_out_min: u256,
        token_in: ContractAddress,
        pairs: Span<ContractAddress>,
        to: ContractAddress,
        deadline: u64,
    ) -> Array<u256>;

    fn swap_tokens_for_exact_tokens(
        ref self: TContractState,
        amount_out: u256,
        amount_in_max: u256,
        token_out: ContractAddress,
        pairs: Span<ContractAddress>,
        to: ContractAddress,
        deadline: u64,
    ) -> Array<u256>;
}
