use starknet::ContractAddress;

use crate::locker::TokenLocked;

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
