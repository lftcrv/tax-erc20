use starknet::ContractAddress;

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
