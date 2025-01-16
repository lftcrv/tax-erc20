use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use cubit::f128::types::fixed::{Fixed, FixedTrait, FixedZero};
const ETH: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
const ETH_HOLDER: felt252 = 0x07170f54dd61ae85377f75131359e3f4a12677589bb7ec5d61f362915a5c0982;
const ONE_ETH: u256 = 1000000000000000000; // 1 ETH in wei
const TEN_ETH: u256 = 10 * ONE_ETH; // 1 ETH in wei
const HUNDRED_ETH: u256 = 100 * ONE_ETH; // 100 ETH in wei
const BILLION_ETH: u256 = 1000000000 * ONE_ETH; // 1B ETH in wei
const LP_CAP: u256 = BILLION_ETH * 8 / 10; // 1M ETH in wei

#[starknet::interface]
trait IExternal<ContractState> {
    fn approve(ref self: ContractState, spender: ContractAddress, amount: u256);
    fn balance_of(self: @ContractState, owner: ContractAddress) -> u256;
    fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256);
}

#[starknet::interface]
trait IBondingCurve<TContractState> {
    fn get_current_price(ref self: TContractState) -> u256;
    fn get_price_for_market_cap(ref self: TContractState, market_cap: u256) -> u256;
    fn get_market_cap_for_price(ref self: TContractState, price: u256) -> u256;
    fn get_market_cap(ref self: TContractState) -> u256;
    fn simulate_buy(ref self: TContractState, eth_amount: u256) -> u256;
    fn simulate_buy_for(ref self: TContractState, token_amount: u256) -> u256;
    fn simulate_sell(ref self: TContractState, token_amount: u256) -> u256;
    fn buy(ref self: TContractState, eth_amount: u256) -> u256;
    fn sell(ref self: TContractState, token_amount: u256) -> u256;
}

fn deploy_bonding_curve() -> ContractAddress {
    let contract = declare("BondingCurve").expect('Declaration failed').contract_class();

    let calldata: Array<felt252> = array![
        ETH_HOLDER.into(), // owner
         'BondingCurve'.into(), // name
         'BCURVE'.into(), // symbol
         0, 0
    ];

    let (contract_address, _) = contract.deploy(@calldata).expect('BondingCurve deployment failed');

    contract_address
}

#[test]
#[fork("MAINNET_LATEST")]
fn test_bonding_curve() {
    // Initialize contracts and addresses
    let eth_holder_address: ContractAddress = ETH_HOLDER.try_into().unwrap();
    let eth_address: ContractAddress = ETH.try_into().unwrap();
    let eth = IExternalDispatcher { contract_address: eth_address };
    let bonding_address = deploy_bonding_curve();
    let bonding = IBondingCurveDispatcher { contract_address: bonding_address };

    // Test initial price
    let initial_price = bonding.get_current_price();
    println!("Initial price: {}", initial_price);

    // Test price mechanics
    println!("Testing price mechanics");
    let starting_price = bonding.get_price_for_market_cap(0);
    println!("Testing price mechanics {}", starting_price);
    assert!(initial_price == starting_price, "Price should be constant with 0 market cap");
    let price_after_eth = bonding.get_price_for_market_cap(ONE_ETH * 10);
    assert!(starting_price < price_after_eth, "Price should increase with market cap");
    // 36220375000000000 should be the price

    // Verify market cap calculation
    println!("Calculating mcap");
    let mcap = bonding.get_market_cap_for_price(price_after_eth);
    println!("Price: {} | Market Cap: {}", price_after_eth, mcap);

    // Test buy simulation
    println!("Testing buy to liquidation eth needed");
    let eth_amount_lp = bonding.simulate_buy_for(LP_CAP);
    println!("Eth amount needed {}", eth_amount_lp);
    println!("Testing simulatebuy liquidation price");
    let tokens_to_receive = bonding.simulate_buy(eth_amount_lp / 10);
    println!("diff {}", LP_CAP - tokens_to_receive);

    // Execute buy

    start_cheat_caller_address(eth_address, eth_holder_address);
    eth.approve(bonding_address, ~0_u256);
    stop_cheat_caller_address(eth_address);

    start_cheat_caller_address(bonding_address, eth_holder_address);
    let bought_tokens = bonding.buy(ONE_ETH);
    stop_cheat_caller_address(eth_address);
    assert!(bought_tokens == tokens_to_receive, "Actual buy differs from simulation");

    // Test sell simulation and execution
    let eth_to_receive = bonding.simulate_sell(bought_tokens);

    start_cheat_caller_address(bonding_address, eth_holder_address);
    let received_eth = bonding.sell(bought_tokens);
    stop_cheat_caller_address(bonding_address);
    assert!(received_eth == eth_to_receive, "Actual sell differs from simulation");
}
// #[test]
// fn test_fixed() {
//     let a: Fixed = 3_u64.into();
//     let b: Fixed = 15_u64.into();
//     let b: Fixed = b / 10_u64.into();
//     let c: u64 = (a * b).try_into().unwrap();
//     println!("c: {}", c);

//     let a: felt252 = 3;
//     let a: Fixed = FixedTrait::from_felt(a);
//     let b: Fixed = 15_u64.into();
//     let b: Fixed = b / 10_u64.into();
//     let c: u64 = (a * b).try_into().unwrap();
//     println!("c: {}", c);

//     let a: felt252 = 3;
//     let a: Fixed = FixedTrait::from_unscaled_felt(a);
//     let b: Fixed = 15_u64.into();
//     let b: Fixed = b / 10_u64.into();
//     let c: u64 = (a * b).round().try_into().unwrap();
//     println!("c: {}", c);
// }


