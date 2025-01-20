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


// Supply constants (in token units with 6 decimals)
const ONE_TOKEN: u256 = 1000000; // 1e6
const THOUSAND_TOKENS: u256 = 1000 * ONE_TOKEN;
const MILLION_TOKENS: u256 = 1000 * THOUSAND_TOKENS;
const MAX_SUPPLY: u256 = 1000000000 * ONE_TOKEN; // 1B tokens
const TRIGGER_LAUNCH: u256 = MAX_SUPPLY * 80 / 100; // 80% of max supply
// Bonding curve parameters
// const BASE_X1E9: felt252 = 5;
// const EXPONENT_X1E9: felt252 = 613020000;
const BASE_X1E9: felt252 = 5;
const EXPONENT_X1E9: felt252 = 2555;

const STEP: u32 = 1000; 
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
        STEP.into(),
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
    println!("Initial price: {}", initial_price);
    assert!(initial_price > 0, "Initial price should be positive");
}

#[test]
fn test_price_increases() {
    let (_, _, _, bonding) = setup_contracts();

    // Test prices at different supply points
    let price_0 = bonding.get_price_for_supply(0);
    let price_1k = bonding.get_price_for_supply(THOUSAND_TOKENS);
    let price_1m = bonding.get_price_for_supply(MILLION_TOKENS);

    println!("Price at 0 supply: {}", price_0);
    println!("Price at 1K tokens: {}", price_1k);
    println!("Price at 1M tokens: {}", price_1m);

    assert!(price_1k > price_0, "Price should increase with supply");
    assert!(price_1m > price_1k, "Price should increase with supply");

    // Test price acceleration (exponential growth)
    let diff_1 = price_1k - price_0;
    let diff_2 = price_1m - price_1k;
    assert!(diff_2 > diff_1, "Price increase should accelerate");
}

#[test]
fn test_buy_simulation() {
    let (_, _, _, bonding) = setup_contracts();

    // Test buying different amounts
    let base = 1000000 * THOUSAND_TOKENS;
    let base_buy = bonding.simulate_buy(base);
    let base_buy_x10 = bonding.simulate_buy(base * 10);
    let base_buy_x100 = bonding.simulate_buy(base * 100);
    println!("Base buy: {}", base_buy);
    println!("Base buy x10: {}", base_buy_x10);
    println!("Base buy x100: {}", base_buy_x100);

    // Verify exponential price increase
    let cost_ratio_1 = base_buy_x10 / base_buy;
    let cost_ratio_2 = base_buy_x100 / base_buy_x10;
    println!("Cost ratio 1: {}", cost_ratio_1);
    println!("Cost ratio 2: {}", cost_ratio_2);
    assert!(cost_ratio_2 > cost_ratio_1, "Cost increase should accelerate");
}

#[test]
fn test_price_simulation() {
    let (_, _, _, bonding) = setup_contracts();

    // Test buying different amounts
    let base = TRIGGER_LAUNCH / 100;
    let start_price = bonding.get_current_price();
    let base_1_perc = bonding.get_price_for_supply(base);
    let base_10_perc = bonding.get_price_for_supply(base * 10);
    let base_20_perc = bonding.get_price_for_supply(base * 20);
    let base_30_perc = bonding.get_price_for_supply(base * 30);
    let base_40_perc = bonding.get_price_for_supply(base * 40);
    let base_50_perc = bonding.get_price_for_supply(base * 50);
    let base_60_perc = bonding.get_price_for_supply(base * 60);
    let base_70_perc = bonding.get_price_for_supply(base * 70);
    let base_80_perc = bonding.get_price_for_supply(base * 80);
    let base_90_perc = bonding.get_price_for_supply(base * 90);
    let base_buy_x100 = bonding.get_price_for_supply(base * 100);
    println!("[\n{},\n{},\n{},\n{},\n{},\n{},\n{},\n{},\n{},\n{},\n{},\n{}\n]",start_price, base_1_perc, base_10_perc, base_20_perc, base_30_perc, base_40_perc, base_50_perc, base_60_perc, base_70_perc, base_80_perc, base_90_perc, base_buy_x100);

    // let base_buy_x10 = bonding.simulate_buy(base * 10);
    // let base_buy_x100 = bonding.simulate_buy(base * 100);
    // println!("Base buy: {}", base_buy);
    // println!("Base buy x10: {}", base_buy_x10);
    // println!("Base buy x100: {}", base_buy_x100);

    // // Verify exponential price increase
    // let cost_ratio_1 = base_buy_x10 / base_buy;
    // let cost_ratio_2 = base_buy_x100 / base_buy_x10;
    // println!("Cost ratio 1: {}", cost_ratio_1);
    // println!("Cost ratio 2: {}", cost_ratio_2);
    // assert!(cost_ratio_2 > cost_ratio_1, "Cost increase should accelerate");
}


#[test]
#[fork("MAINNET_LATEST")]
fn test_buy_sell_cycle() {
    let (eth_holder, eth_address, eth, bonding) = setup_contracts();

    // Setup approvals
    start_cheat_caller_address(eth_address, eth_holder);
    eth.approve(bonding.contract_address, ~0_u256);
    stop_cheat_caller_address(eth_address);

    // Buy tokens
    let buy_amount = THOUSAND_TOKENS;
    start_cheat_caller_address(bonding.contract_address, eth_holder);
    let eth_spent = bonding.buy(buy_amount);
    stop_cheat_caller_address(bonding.contract_address);

    println!("ETH spent for buy: {}", eth_spent);
    println!("New total supply: {}", bonding.total_supply());

    // Try to sell half
    let sell_amount = buy_amount / 2;
    let expected_eth = bonding.simulate_sell(sell_amount);

    println!("Expected ETH from sell: {}", expected_eth);
    start_cheat_caller_address(bonding.contract_address, eth_holder);
    let received_eth = bonding.sell(sell_amount);
    stop_cheat_caller_address(bonding.contract_address);

    println!("Actually received ETH: {}", received_eth);
    assert!(received_eth == expected_eth, "Sell simulation should match actual");
}


#[test]
#[should_panic(expected: "Insufficient balance")]
#[fork("MAINNET_LATEST")]
fn test_sell_insufficient_balance() {
    let (_, _, _, bonding) = setup_contracts();

    start_cheat_caller_address(
        bonding.contract_address,
        0x04D8eB0b92839aBd23257c32152a39BfDb378aDc0366ca92e2a4403353BAad51.try_into().unwrap()
    );
    bonding.sell(THOUSAND_TOKENS);
    stop_cheat_caller_address(bonding.contract_address);
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
