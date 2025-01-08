// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^0.20.0

use starknet::ContractAddress;

#[starknet::interface]
pub trait ITaxERC20<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress) -> u256;
    fn set_is_pool(ref self: TContractState,address: ContractAddress);
    fn set_sell_tax(ref self: TContractState,amount: u16);
    fn set_buy_tax(ref self: TContractState,amount: u16);
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn balance_of(self: @TContractState, owner: ContractAddress) -> u256;
}
#[starknet::contract]
mod TaxERC20 {
    // use openzeppelin::utils::bytearray::ByteArrayExtTrait;
    use core::to_byte_array::FormatAsByteArray;
    use openzeppelin::access::ownable::OwnableComponent;
    use crate::custom_component::modified_erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::UpgradeableComponent;
    use starknet::{ClassHash, ContractAddress, get_caller_address};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, name: felt252, symbol: felt252, sell_tax : u16) {
        let (name, symbol) = (name.format_as_byte_array(8), symbol.format_as_byte_array(8));
        self.erc20.initializer(name, symbol);
        self.erc20.set_sell_tax(sell_tax);  
        self.ownable.initializer(owner);
        self.erc20.mint(owner, 1743074421886482729);
        self.erc20.set_tax_address(0x0439aF06A8F0302d4155C9bb5835FC73A57836243b126D5B8883A1eCe6A65958.try_into().unwrap());
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn burn(ref self: ContractState, value: u256) {
            self.erc20.burn(get_caller_address(), value);
        }

        #[external(v0)]
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self.erc20.mint(recipient, amount);
        }
        #[external(v0)]
        fn set_sell_tax(ref self: ContractState,amount: u16) {
            self.ownable.assert_only_owner();
            self.erc20.set_sell_tax(amount);  
        }
        #[external(v0)]
        fn set_buy_tax(ref self: ContractState,amount: u16) {
            self.ownable.assert_only_owner();
            self.erc20.set_buy_tax(amount);  
        }
        #[external(v0)]
        fn set_is_pool(ref self: ContractState,address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.erc20.set_is_pool(address);  
        }
        #[external(v0)]
        fn revoke_is_pool(ref self: ContractState,address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.erc20.revoke_is_pool(address);
        }
    }

    //
    // Upgradeable
    //
    
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
