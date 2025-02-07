#[starknet::contract]
pub mod GradualLocker {
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, Map, StoragePointerWriteAccess, StoragePathEntry
    };

    use openzeppelin_token::erc20::{interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait}};

    use crate::locker::IGradualLocker;

    #[derive(Drop, Serde, Copy, starknet::Store, starknet::Event)]
    pub struct TokenLocked {
        pub end_timestamp: u64,
        pub start_timestamp: u64,
        pub initial_amount: u256,
        pub current_amount: u256,
        pub owner: ContractAddress
    }
    #[derive(Drop, Serde, starknet::Event)]
    pub struct LPClaimed {
        pub amount: u256,
        pub amount_left: u256,
        pub owner: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        LPLocked: TokenLocked,
        LPClaimed: LPClaimed,
    }
    #[storage]
    struct Storage {
        token_locked_by_user: Map<ContractAddress, Map<ContractAddress, TokenLocked>>,
    }

    #[abi(embed_v0)]
    impl LockerImpl of IGradualLocker<ContractState> {
        fn lock(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            end_timestamp: u64,
            owner: ContractAddress,
        ) -> TokenLocked {
            assert!(amount != 0, "No empty amount");
            assert!(end_timestamp > get_block_timestamp(), " Cannot lock antero");
            let old_token = self.token_locked_by_user.entry(owner).entry(token).read();
            assert!(old_token.initial_amount == 0, " Cannot lock twice the same lp per owner");

            let caller = get_caller_address();
            let this = get_contract_address();
            let timestamp = get_block_timestamp();

            let token_locked = TokenLocked {
                end_timestamp,
                start_timestamp: timestamp,
                initial_amount: amount,
                current_amount: amount,
                owner
            };
            let erc20_token = IERC20MixinDispatcher { contract_address: token };
            erc20_token.transfer_from(caller, this, amount);
            self.emit(Event::LPLocked(token_locked));
            self.token_locked_by_user.entry(owner).entry(token).write(token_locked);
            token_locked
        }


        fn get_lock(
            self: @ContractState, owner: ContractAddress, token: ContractAddress,
        ) -> TokenLocked {
            self.token_locked_by_user.entry(owner).entry(token).read()
        }


        fn lockCamel(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            end_timestamp: u64,
            owner: ContractAddress,
        ) -> TokenLocked {
            let caller = get_caller_address();
            let this = get_contract_address();
            let timestamp = get_block_timestamp();

            assert!(amount != 0, "No empty amount");
            assert!(end_timestamp > timestamp, " Cannot lock antero");
            let old_token = self.token_locked_by_user.entry(owner).entry(token).read();
            assert!(old_token.initial_amount == 0, " Cannot lock twice the same lp per owner");

            let token_locked = TokenLocked {
                end_timestamp,
                start_timestamp: timestamp,
                initial_amount: amount,
                current_amount: amount,
                owner
            };
            let erc20_token = IERC20MixinDispatcher { contract_address: token };
            erc20_token.transferFrom(caller, this, amount);
            self.emit(Event::LPLocked(token_locked));
            self.token_locked_by_user.entry(owner).entry(token).write(token_locked);
            token_locked
        }

        fn claim(ref self: ContractState, token: ContractAddress) -> u256 {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();

            let mut token_info = self.token_locked_by_user.entry(caller).entry(token).read();
            assert!(token_info.current_amount != 0, "Cannot claim for empty lock");
            let token_contract = IERC20MixinDispatcher { contract_address: token };
            let time_diff: u64 = token_info.end_timestamp - token_info.start_timestamp;
            let now_diff: u64 = timestamp - token_info.start_timestamp;

            let amount = if now_diff > time_diff {
                token_info.current_amount
            } else {
                let max_claimable: u256 = token_info.initial_amount
                    * now_diff.into()
                    / time_diff.into();
                let already_claimed = token_info.initial_amount - token_info.current_amount;
                assert!(max_claimable >= already_claimed, "Already claimed");
                max_claimable - already_claimed
            };

            assert!(amount != 0, "Cannot claim for empty lock");

            token_info.current_amount -= amount;
            self.token_locked_by_user.entry(caller).entry(token).write(token_info);
            self
                .emit(
                    Event::LPClaimed(
                        LPClaimed {
                            amount, amount_left: token_info.current_amount, owner: token_info.owner
                        }
                    )
                );

            token_contract.transfer(caller, amount.into());
            amount
        }

        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            interface_id == 0xb8d81441e297b31db874ccc7e13400572864b7194343047d5b1f49cae8560e
        }
    }
}

