use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::testing::set_caller_address;

// Constants
const ETH: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
const ETH_HOLDER: felt252 = 0x07170f54dd61ae85377f75131359e3f4a12677589bb7ec5d61f362915a5c0982;

#[starknet::interface]
pub trait IExternal<ContractState> {
    fn approve(ref self: ContractState, spender: ContractAddress, amount: u256);
    fn balance_of(self: @ContractState, owner: ContractAddress) -> u256;
    fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256);
}

#[starknet::interface]
pub trait IBondingCurve<TContractState> {
    fn get_current_price(ref self: TContractState) -> u256;
    fn get_price_for_market_cap(ref self: TContractState, market_cap: u256) -> u256;
    fn get_market_cap(ref self: TContractState) -> u256;
    fn simulate_buy(ref self: TContractState, eth_amount: u256) -> u256;
    fn simulate_sell(ref self: TContractState, token_amount: u256) -> u256;
    fn buy(ref self: TContractState, eth_amount: u256) -> u256;
    fn sell(ref self: TContractState, token_amount: u256) -> u256;
}

#[test]
#[fork("MAINNET_LATEST")]
fn test_bonding_curve() {
    println!(">>> Starting bonding curve test...");

    // Initialize addresses
    let eth_holder_address: ContractAddress = ETH_HOLDER.try_into().unwrap();
    let eth_address: ContractAddress = ETH.try_into().unwrap();

    let eth = IExternalDispatcher { contract_address: eth_address };

    // Deploy bonding curve
    println!("[*] Deploying Bonding Curve contract...");
    let bonding_address = deploy_bonding_curve();
    // println!("[+] Bonding Curve deployed at: {:x}", bonding_address);
    let bonding = IBondingCurveDispatcher { contract_address: bonding_address };

    // Test initial price
    let initial_price = bonding.get_current_price();
    println!("[*] Initial price: {}", initial_price);

    // Test buy simulation
    let eth_amount = 1000000000000000000; // 1 ETH

    println!("[+] Actually  get_price_for_market_cap");
    bonding.get_price_for_market_cap(eth_amount);

    let tokens_to_receive = bonding.simulate_buy(eth_amount);
    println!("[*] Simulated tokens for 1 ETH: {}", tokens_to_receive);

    // Approve and buy
    println!("[*] Approving and buying tokens...");
    start_cheat_caller_address(eth_address, eth_holder_address);
    eth.approve(bonding_address, ~0_u256);
    stop_cheat_caller_address(eth_address);

    // Execute buy
    println!("[+] Actually  test_simulate_buy");
    bonding.get_price_for_market_cap(eth_amount);
    println!("[*] Actually buy tokens");
    start_cheat_caller_address(bonding_address, eth_holder_address);
    let bought_tokens = bonding.buy(eth_amount);
    stop_cheat_caller_address(eth_address);
    println!("[+] Actually bought tokens: {}", bought_tokens);
    assert!(bought_tokens == tokens_to_receive, "Bought tokens don't match simulation");

    // Test sell simulation
    let sell_amount = bought_tokens; // Sell half
    let eth_to_receive = bonding.simulate_sell(sell_amount);
    println!("[*] Simulated ETH return for {} tokens: {}", sell_amount, eth_to_receive);

    // Execute sell
    start_cheat_caller_address(bonding_address, eth_holder_address);
    let received_eth = bonding.sell(sell_amount);
    stop_cheat_caller_address(bonding_address);
    println!("[+] Actually received ETH: {}", received_eth);
    assert!(received_eth == eth_to_receive, "Received ETH doesn't match simulation");

    println!(">>> Test completed successfully!");
}

fn deploy_bonding_curve() -> ContractAddress {
    println!("[*] Declaring BondingCurve contract...");
    let contract = declare("BondingCurve").expect('Declaration failed').contract_class();

    println!("[*] Preparing deployment calldata...");
    let calldata: Array<felt252> = array![
        ETH_HOLDER.into(), // owner
        'BondingCurve'.into(), // name
        'BCURVE'.into(),
        100,
        300 // symbol
    ];

    println!("[*] Deploying BondingCurve...");
    let (contract_address, _) = contract.deploy(@calldata).expect('tax_erc20 deployment failed');

    contract_address
}
