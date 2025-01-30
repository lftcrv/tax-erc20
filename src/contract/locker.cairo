#[starknet::contract]
mod LPGradualLock {
    // Imports grouped by functionality
    // use starknet::event::EventEmitter;
    use starknet::event::EventEmitter;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use core::{
        starknet::storage::{
            StoragePointerReadAccess, Map, StoragePointerWriteAccess, StoragePathEntry
        }
    };
    // OpenZeppelin imports
    use openzeppelin_token::erc20::{interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait}};

    // #[starknet::storage_node]
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

    // #[constructor]
    // fn constructor() {}

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn lock(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            end_timestamp: u64,
            owner: ContractAddress,
        ) {
            assert!(amount != 0, "No empty amount");
            assert!(end_timestamp > get_block_timestamp(), " Cannot lock antero");
            let old_token = self.token_locked_by_user.entry(owner).entry(token).read();
            assert!(old_token.initial_amount == 0, " Cannot lock twice the same lp per owner");

            let token_locked = TokenLocked {
                end_timestamp,
                start_timestamp: get_block_timestamp(),
                initial_amount: amount,
                current_amount: amount,
                owner
            };
            let erc20_token = IERC20MixinDispatcher { contract_address: token };
            erc20_token.transfer_from(get_caller_address(), get_contract_address(), amount);
            self.emit(Event::LPLocked(token_locked));
            self.token_locked_by_user.entry(owner).entry(token).write(token_locked);
        }

        #[external(v0)]
        fn claim(ref self: ContractState, token: ContractAddress, owner: ContractAddress,) {
            // let
            let mut token_info = self
                .token_locked_by_user
                .entry(get_caller_address())
                .entry(token)
                .read();
            assert!(token_info.current_amount != 0, "Cannot claim for empty lock");
            let token_contract = IERC20MixinDispatcher { contract_address: token };
            let time_diff: u64 = token_info.end_timestamp - token_info.start_timestamp;
            let now_diff: u64 = get_block_timestamp() - token_info.start_timestamp;

            let amount = if now_diff > time_diff {
                token_info.current_amount
            } else {
                let max_claimable: u256 = token_info.initial_amount
                    * now_diff.into()
                    / time_diff.into();
                let already_claimed = token_info.initial_amount - token_info.current_amount;
                assert!(max_claimable <= already_claimed, "Already claimed");
                max_claimable - already_claimed
            };

            if amount == 0 {
                panic!("Cannot claim for empty lock");
            }

            token_info.current_amount -= amount;
            self.token_locked_by_user.entry(owner).entry(token).write(token_info);
            self
                .emit(
                    Event::LPClaimed(
                        LPClaimed {
                            amount, amount_left: token_info.current_amount, owner: token_info.owner
                        }
                    )
                );

            token_contract.transfer(get_caller_address(), amount.into());
        }
    }
}

