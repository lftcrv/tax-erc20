use starknet::ContractAddress;

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
