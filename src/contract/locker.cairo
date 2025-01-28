#[starknet::contract]
mod LPLOCKER {
    // Imports grouped by functionality
    use starknet::event::EventEmitter;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use core::{starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess}};
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait, ISRC5_ID};
    // OpenZeppelin imports
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20DispatcherTrait, IERC20Dispatcher}
    };

    pub struct TokenLocked {
        pub is_liquid_lock: bool,
        pub end_timestamp: u64,
        pub start_timestamp: u64,
        pub initial_amount: felt252,
        pub current_amount: felt252,
        pub owner: ContractAddress
    }
    #[storage]
    struct Storage {
        token_locked_by_user: Map<ContractAddress, Map<ContractAddress, TokenLocked>>,
    }

    #[constructor]
    fn constructor() {}


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
            is_liquid_lock: bool
        ) {
            assert!(amount != 0, "No empty amount");
            assert!(end_timestamp > get_block_timestamp(), " Cannot lock antero");
            let token_locked = TokenLocked {
                is_liquid_lock,
                end_timestamp,
                start_timestamp: get_block_timestamp(),
                initial_amount: amount,
                current_amount: amount,
                owner
            };
            let erc20_token = IERC20Dispatcher { contract_address: token };
            erc20_token.transfer_from(get_caller_address(), get_contract_address(), amount);

            let old_token = self.token_locked_by_user.entry(owner).entry(token).read();
            assert!(old_token.initial_amount == 0, " Cannot lock twice the same lp per owner");
            self.token_locked_by_user.entry(owner).entry(token).write(token_locked);
        }

        #[external(v0)]
        fn claim(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            end_timestamp: u64,
            owner: ContractAddress,
            is_liquid_lock: bool
        ) {
            let mut token_info = self
                .token_locked_by_user
                .entry(get_caller_address())
                .entry(token)
                .read();
            assert!(token_info.current_amount != 0, " Cannot claim for empty lock");
            assert!(token_info.owner == get_caller_address(), " Cannot claim for empty lock");
            let token = IERC20Dispatcher { contract_address: token };
            let time_diff = token_info.end_timestamp - token_info.start_timestamp;
            let now_diff = get_block_timestamp() - token_info.start_timestamp;

            let amount = if now_diff > time_diff {
                token_info.current_amount;
            } else if !token_info.is_liquid_lock {
                let max_claimable = token_info.initial_amount * now_diff / time_diff;
                let already_claimed = token_info.initial_amount - token_info.current_amount;
                assert!(max_claimable > already_claimed, "Already claimed");
                max_claimable - already_claimed
            } else {
                panic!("Cannot claim now");
            };
            token_info.current_amount -= amount;
            self.token_locked_by_user.entry(owner).entry(token).write(token_locked);

            token.tranfer(get_caller_address(), amount);
        }
    }
}

