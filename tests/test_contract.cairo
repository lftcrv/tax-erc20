use tax_erc20::contract::v2_pool_factory_interface::{IFactoryDispatcher, IFactoryDispatcherTrait};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use tax_erc20::contract::v2_router_interface::{IRouterDispatcher, IRouterDispatcherTrait};
use tax_erc20::contract::v2_pair_interface::{IPairDispatcher, IPairDispatcherTrait};
use tax_erc20::contract::tax_erc20::{ITaxERC20Dispatcher,ITaxERC20DispatcherTrait};
use starknet::ContractAddress;

// Constants
const FACTORY_ADDRESS: felt252 = 0x02a93ef8c7679a5f9b1fcf7286a6e1cadf2e9192be4bcb5cb2d1b39062697527;
const ROUTER_ADDRESS: felt252 = 0x049ff5b3a7d38e2b50198f408fa8281635b5bc81ee49ab87ac36c8324c214427;
const ETH: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
const ETH_HOLDER: felt252 = 0x07170f54dd61ae85377f75131359e3f4a12677589bb7ec5d61f362915a5c0982;

#[starknet::interface]
pub trait IExternal<ContractState> {
    fn approve(ref self: ContractState, spender: ContractAddress, amount: u256);
    fn balance_of(self: @ContractState, owner: ContractAddress) -> u256;
    fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256);
}

#[test]
#[fork("MAINNET_LATEST")]
fn test_using_forked_state() {
    println!(">>> Starting test on forked mainnet...");

    // Initialize addresses
    println!("[*] Initializing contract addresses...");
    let factory_address: ContractAddress = FACTORY_ADDRESS.try_into().unwrap();
    let router_address: ContractAddress = ROUTER_ADDRESS.try_into().unwrap();
    let eth_holder_address: ContractAddress = ETH_HOLDER.try_into().unwrap();
    let eth_address: ContractAddress = ETH.try_into().unwrap();

    // Initialize dispatchers
    let factory = IFactoryDispatcher { contract_address: factory_address };
    let  router = IRouterDispatcher { contract_address: router_address };

    let eth = IExternalDispatcher { contract_address: eth_address };


    // Deploy tax token
    println!("[*] Deploying Tax ERC20 token...");
    let tax_token_address = deploy_tax_erc20();
    println!("[+] Tax token deployed at: {:?}", tax_token_address);
    let tax_token = ITaxERC20Dispatcher { contract_address: tax_token_address };

    // Create pair and verify
    println!("[*] Checking initial pool count...");
    let num_pools_before = factory.num_of_pairs();
    println!("Current number of pools: {} ", num_pools_before);
    assert!(num_pools_before > 0, "ERROR: No pools found in factory");

    println!("[*] Creating new token pair...");
    let pair_address = factory.create_pair(tax_token_address, eth_address);
    println!("[+] Pair created at address: {:?}", pair_address);

    // Approve tokens
    println!("[*] Setting token approvals...");
    start_cheat_caller_address(tax_token_address, eth_holder_address);
    tax_token.set_is_pool(pair_address);
    tax_token.set_buy_tax(5000);
    tax_token.set_sell_tax(5000);

    tax_token.approve(router_address, ~0_u256);
    // tax_token.transfer(pair_address, 1000);
    println!("[+] Tax token approval set");
    stop_cheat_caller_address(tax_token_address);

    start_cheat_caller_address(eth_address, eth_holder_address);
    eth.approve(router_address, ~0_u256);
    // eth.transfer(pair_address, 1000);
    println!("[+] ETH approval set");
    stop_cheat_caller_address(eth_address);

    let num_pools_after = factory.num_of_pairs();
    println!("New pool count: {}", num_pools_after);
    assert!(num_pools_after == num_pools_before + 1, "ERROR: Pool count not incremented");

    //Check eth amount


    // Add liquidity
    println!("[*] Adding initial liquidity...");
    start_cheat_caller_address(router_address, eth_holder_address);
    let (amount_a, amount_b, minted_token) = router
        .add_liquidity(
            pair_address, 100000000000000000, 100000000000000000, 1, 1, eth_holder_address, 1798675200,
        );
    stop_cheat_caller_address(router_address);
    println!("[+] Liquidity added successfully:");
    println!("    - Amount A: {}", amount_a);
    println!("    - Amount B: {}", amount_b);
    println!("    - LP tokens minted: {}", minted_token);
    assert!(minted_token > 0, "ERROR: No LP tokens minted");

    start_cheat_caller_address(router_address, eth_holder_address);
    swap_test( tax_token_address, pair_address, eth_holder_address);
    stop_cheat_caller_address(router_address);
    println!(">>> Test completed successfully!");
}


pub fn swap_test( tax_token_address: ContractAddress, pair_address: ContractAddress, eth_holder_address: ContractAddress) {
    let tax_token = IExternalDispatcher { contract_address: tax_token_address };
    let eth = IExternalDispatcher { contract_address: ETH.try_into().unwrap() };
    let  router = IRouterDispatcher { contract_address: ROUTER_ADDRESS.try_into().unwrap() };
    let amount_eth = tax_token.balance_of(eth_holder_address);
    println!("[*] Checking ETH balances...");
    let eth_balance = eth.balance_of(eth_holder_address);
    println!("ETH balance: {}", eth_balance);
    assert!(eth_balance > 0, "ERROR: ETH balance is zero");
    println!("[*] Checking Tax token balances...");
    let tax_balance = tax_token.balance_of(eth_holder_address);
    println!("Tax token balance: {}", tax_balance);
    assert!(tax_balance > 0, "ERROR: Tax token balance is zero");
    router
        .swap_exact_tokens_for_tokens(
            10000, 1, tax_token_address, [pair_address].span(), eth_holder_address, 1798675200,
        );
    let post_tax_token_balance = tax_token.balance_of(eth_holder_address);
    let post_eth_balance = eth.balance_of(eth_holder_address);

    println!("[*] Checking updated balances...");
    println!("Tax address balance: {}", tax_token.balance_of(0x0439aF06A8F0302d4155C9bb5835FC73A57836243b126D5B8883A1eCe6A65958.try_into().unwrap()));
    println!("ETH balance: {}\n   DIff: {}",eth_balance,post_eth_balance -eth_balance  );
    println!("Tax token balance: {}\n   Diff{}", post_tax_token_balance,tax_balance - post_tax_token_balance );
}
pub fn deploy_tax_erc20() -> ContractAddress {
    println!("[*] Declaring TaxERC20 contract...");
    let contract = declare("TaxERC20").expect('Declaration failed').contract_class();

    println!("[*] Preparing deployment calldata...");
    let calldata: Array<felt252> = array![ETH_HOLDER.into(), 'Name'.into(), 'Symbol'.into(),5000.into()];

    println!("[*] Deploying TaxERC20...");
    let (contract_address, _) = contract.deploy(@calldata).expect('tax_erc20 deployment failed');
    println!("[+] TaxERC20 deployed successfully");

    contract_address
}
