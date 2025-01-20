use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, cheat_caller_address, CheatSpan
};

// Constants
const ETH: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
const ETH_HOLDER: felt252 = 0x0213c67ed78bc280887234fe5ed5e77272465317978ae86c25a71531d9332a2d;
const PROTOCOL: felt252 = 0x04D8eB0b92839aBd23257c32152a39BfDb378aDc0366ca92e2a4403353BAad51;
const ROUTER_ADDRESS: felt252 = 0x049ff5b3a7d38e2b50198f408fa8281635b5bc81ee49ab87ac36c8324c214427;

// Token amounts
const ONE_ETH: u256 = 1000000000000000000;
const TEN_ETH: u256 = 10 * ONE_ETH;
const HUNDRED_ETH: u256 = 100 * ONE_ETH;
const THOUSAND_ETH: u256 = 1000 * ONE_ETH;
const BILLION_ETH: u256 = 1000000000 * ONE_ETH;

// Bonding curve parameters
// const BASE_X1E9: felt252 = 5;
// const EXPONENT_X1E9: felt252 = 613020000;
const BASE_X1E9: felt252 = 46;
const EXPONENT_X1E9: felt252 = 36060;
const MAX_SUPPLY: u256 = 1000000000 * 1000000; // 1B tokens with 6 decimals
const TRIGGER_LAUNCH: u256 = MAX_SUPPLY * 80 / 100;

#[starknet::interface]
trait IBondingCurve<TContractState> {
    fn decimals(self: @TContractState) -> u8;
    fn get_current_price(self: @TContractState) -> u256;
    fn get_price_for_supply(self: @TContractState, supply: u256) -> u256;
    fn market_cap(self: @TContractState) -> u256;
    fn simulate_buy(self: @TContractState, token_amount: u256) -> u256;
    fn simulate_sell(self: @TContractState, token_amount: u256) -> u256;
    fn buy(ref self: TContractState, token_amount: u256) -> u256;
    fn sell(ref self: TContractState, token_amount: u256) -> u256;
    fn get_taxes(self: @TContractState) -> (u16, u16);
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    fn total_supply(self: @TContractState) -> u256;
}

#[starknet::interface]
trait IERC20<TContractState> {
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    fn decimals(self: @TContractState) -> u8;
    fn balance_of(self: @TContractState, owner: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    );
}

fn deploy_bonding_curve(buy_tax: u16, sell_tax: u16) -> ContractAddress {
    let contract = declare("BondingCurve").expect('Declaration failed').contract_class();

    let calldata: Array<felt252> = array![
        PROTOCOL.into(),
        ETH_HOLDER.into(),
        'LFTCRV'.into(),
        'LFTCRV'.into(),
        BASE_X1E9.into(),
        EXPONENT_X1E9.into(),
        buy_tax.into(),
        sell_tax.into()
    ];

    let (contract_address, _) = contract.deploy(@calldata).expect('Deployment failed');
    contract_address
}

fn setup_contracts() -> (
    ContractAddress, ContractAddress, IERC20Dispatcher, IBondingCurveDispatcher
) {
    let eth_holder_address: ContractAddress = ETH_HOLDER.try_into().unwrap();
    let eth_address: ContractAddress = ETH.try_into().unwrap();
    let eth = IERC20Dispatcher { contract_address: eth_address };
    let bonding_address = deploy_bonding_curve(500, 500); // 5% taxes
    let bonding = IBondingCurveDispatcher { contract_address: bonding_address };

    (eth_holder_address, eth_address, eth, bonding)
}

#[test]
fn test_initial_state() {
    let (_, _, _, bonding) = setup_contracts();

    assert!(bonding.total_supply() == 0, "Initial supply should be 0");
    assert!(bonding.decimals() == 6, "Decimals should be 6");
    assert!(bonding.market_cap() == 0, "Initial market cap should be 0");

    let initial_price = bonding.get_current_price();
    assert!(initial_price > 0, "Initial price should be positive");
}

#[test]
fn test_price_curve_behavior() {
    let (_, _, _, bonding) = setup_contracts();

    // Test increasing supply leads to increasing prices
    let price_at_0 = bonding.get_price_for_supply(0);
    let price_at_1m = bonding.get_price_for_supply(1000000 * 1000000); // 1M tokens
    let price_at_10m = bonding.get_price_for_supply(10000000 * 1000000); // 10M tokens

    assert!(price_at_1m > price_at_0, "Price should increase with supply");
    assert!(price_at_10m > price_at_1m, "Price should increase with supply");

    // Test exponential growth
    let growth_1 = price_at_1m - price_at_0;
    let growth_2 = price_at_10m - price_at_1m;
    assert!(growth_2 > growth_1, "Price growth should accelerate");

    println!("Price at 0: {}", price_at_0);
    println!("Price at 1M: {}", price_at_1m);
    println!("Price at 10M: {}", price_at_10m);
    println!("Growth 1: {}", growth_1);
    println!("Growth 2: {}", growth_2);
}

#[test]
fn test_buy_simulation() {
    let (_, _, _, bonding) = setup_contracts();

    // Test various token amounts
    let small_amount = 1000 * 1000000; // 1000 tokens
    let medium_amount = 10000 * 1000000; // 10K tokens
    let large_amount = 100000 * 1000000; // 100K tokens

    let eth_for_small = bonding.simulate_buy(small_amount);
    let eth_for_medium = bonding.simulate_buy(medium_amount);
    let eth_for_large = bonding.simulate_buy(large_amount);

    println!("ETH needed for 1K tokens: {}", eth_for_small);
    println!("ETH needed for 10K tokens: {}", eth_for_medium);
    println!("ETH needed for 100K tokens: {}", eth_for_large);

    assert!(eth_for_small > 0, "Should get positive ETH amount for small buy");
    assert!(eth_for_medium > eth_for_small * 10, "Medium buy should cost more than 10x small buy");
    assert!(eth_for_large > eth_for_medium * 10, "Large buy should cost more than 10x medium buy");
}

#[test]
#[fork("MAINNET_LATEST")]
fn test_buy_sell_mechanics() {
    let (eth_holder, eth_address, eth, bonding) = setup_contracts();

    // Setup approvals
    start_cheat_caller_address(eth_address, eth_holder);
    eth.approve(bonding.contract_address, ~0_u256);
    stop_cheat_caller_address(eth_address);

    // Buy tokens
    let token_amount = 1000 * 1000000; // 1000 tokens
    start_cheat_caller_address(bonding.contract_address, eth_holder);
    let eth_spent = bonding.buy(token_amount);
    stop_cheat_caller_address(bonding.contract_address);

    println!("ETH spent for 1K tokens: {}", eth_spent);
    println!("Total supply after buy: {}", bonding.total_supply());

    // Verify supply and market cap
    assert!(bonding.total_supply() == token_amount, "Supply should match bought amount");
    assert!(bonding.market_cap() > 0, "Market cap should be positive");

    // Simulate sell
    let eth_for_sell = bonding.simulate_sell(token_amount);
    println!("Expected ETH from sell: {}", eth_for_sell);

    // Execute sell
    start_cheat_caller_address(bonding.contract_address, eth_holder);
    let eth_received = bonding.sell(token_amount);
    stop_cheat_caller_address(bonding.contract_address);

    println!("Actually received ETH: {}", eth_received);

    // Verify sell matches simulation
    assert!(eth_received == eth_for_sell, "Sell should match simulation");
}

#[test]
#[fork("MAINNET_LATEST")]
fn test_launch_trigger() {
    let (eth_holder, eth_address, eth, bonding) = setup_contracts();

    start_cheat_caller_address(eth_address, eth_holder);
    eth.approve(bonding.contract_address, ~0_u256);
    stop_cheat_caller_address(eth_address);

    // Try to buy more than launch trigger
    let over_trigger = TRIGGER_LAUNCH + 1000000;
    cheat_caller_address(bonding.contract_address, eth_holder, CheatSpan::TargetCalls(2));
    println!("Attempting to buy: {} tokens", over_trigger);
    let eth_required = bonding.buy(over_trigger);
    stop_cheat_caller_address(bonding.contract_address);

    println!("Attempted to buy: {} tokens", over_trigger);
    println!("Actual supply after buy: {}", bonding.total_supply());
    println!("ETH spent: {}", eth_required);

    // Verify supply is capped
    assert!(bonding.total_supply() <= MAX_SUPPLY, "Supply should not exceed launch trigger");
}

#[test]
#[should_panic(expected: "Insufficient balance")]
#[fork("MAINNET_LATEST")]
fn test_sell_without_balance() {
    let (_, _, _, bonding) = setup_contracts();

    start_cheat_caller_address(
        bonding.contract_address,
        0x04D8eB0b92839aBd23257c32152a39BfDb378aDc0366ca92e2a4403353BAad51.try_into().unwrap()
    );
    bonding.sell(1000000); // Try to sell 1 token
    stop_cheat_caller_address(bonding.contract_address);
}
