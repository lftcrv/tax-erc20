use starknet::{ContractAddress, ClassHash};
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
