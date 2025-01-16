use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use cubit::f128::types::fixed::{Fixed, FixedTrait, FixedZero};

// Constants for testing
const ETH: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
const ETH_HOLDER: felt252 = 0x07170f54dd61ae85377f75131359e3f4a12677589bb7ec5d61f362915a5c0982;
const ONE_ETH: u256 = 1000000000000000000;
const TEN_ETH: u256 = 10 * ONE_ETH;
const HUNDRED_ETH: u256 = 100 * ONE_ETH;
const THOUSAND_ETH: u256 = 1000 * ONE_ETH;
const BILLION_ETH: u256 = 1000000000 * ONE_ETH;
const LP_CAP: u256 = BILLION_ETH * 8 / 10;

// Contract interfaces
#[starknet::interface]
trait IExternal<ContractState> {
    fn approve(ref self: ContractState, spender: ContractAddress, amount: u256);
    fn balance_of(self: @ContractState, owner: ContractAddress) -> u256;
    fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256);
    fn transfer_from(
        ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    );
}

#[starknet::interface]
trait IBondingCurve<TContractState> {
    fn get_current_price(ref self: TContractState) -> u256;
    fn get_price_for_market_cap( self: @TContractState, market_cap: u256) -> u256;
    fn market_cap_for_price(ref self: TContractState, price: u256) -> u256;
    fn market_cap(ref self: TContractState) -> u256;
    fn simulate_buy(ref self: TContractState, eth_amount: u256) -> u256;
    fn simulate_buy_for(ref self: TContractState, token_amount: u256) -> u256;
    fn simulate_sell(ref self: TContractState, token_amount: u256) -> u256;
    fn buy(ref self: TContractState, eth_amount: u256) -> u256;
    fn sell(ref self: TContractState, token_amount: u256) -> u256;
    fn get_taxes(ref self: TContractState) -> (u16, u16);
}

// Helper functions
fn deploy_bonding_curve(buy_tax: u16, sell_tax: u16) -> ContractAddress {
    let contract = declare("BondingCurve").expect('Declaration failed').contract_class();

    let calldata: Array<felt252> = array![
        ETH_HOLDER.into(), // owner
        ETH_HOLDER.into(), // protocol
        'BondingCurve'.into(), // name
        'BCURVE'.into(), // symbol
        buy_tax.into(),
        sell_tax.into()
    ];

    let (contract_address, _) = contract.deploy(@calldata).expect('Deployment failed');
    contract_address
}

fn setup_contracts() -> (
    ContractAddress, ContractAddress, IExternalDispatcher, IBondingCurveDispatcher
) {
    let eth_holder_address: ContractAddress = ETH_HOLDER.try_into().unwrap();
    let eth_address: ContractAddress = ETH.try_into().unwrap();
    let eth = IExternalDispatcher { contract_address: eth_address };
    let bonding_address = deploy_bonding_curve(500, 500); // 5% taxes
    let bonding = IBondingCurveDispatcher { contract_address: bonding_address };

    (eth_holder_address, eth_address, eth, bonding)
}

// Test Suites

#[test]
#[fork("MAINNET_LATEST")]
fn test_contract_deployment() {
    let (_, _, _, bonding) = setup_contracts();

    let (buy_tax, sell_tax) = bonding.get_taxes();
    assert!(buy_tax == 500, "Buy tax should be 5%");
    assert!(sell_tax == 500, "Sell tax should be 5%");
    assert!(bonding.market_cap() == 0, "Initial market cap should be 0");
    assert!(bonding.get_current_price() > 0, "Initial price should be positive");
}


#[test]
fn test_market_cap_calculation() {
    let (_, _, _, bonding) = setup_contracts();

    // Test market cap calculation for different prices
    let test_caps = array![HUNDRED_ETH ,ONE_ETH, TEN_ETH];

    let mut i = 0;
    loop {
        println!("i = {}", i);
        if i >= test_caps.len() {
            break;
        }
        let cap = *test_caps.at(i);
        println!("testing price for cap: {}", cap);
        let price: u256 = bonding.get_price_for_market_cap(cap);
        println!("price: {}", price);
        // println!("testing calculate cap for price: {}", price);
        // let calculated_cap = bonding.market_cap_for_price(price);

        // // Allow for small rounding differences
        // let diff = if cap > calculated_cap {
        //     cap - calculated_cap
        // } else {
        //     calculated_cap - cap
        // };

        // assert!(diff <= cap / 1000, "Market cap calculation error too large"); // 0.1% tolerance
        i += 1;
    }
}
// #[test]
// fn test_price_mechanics() {
//     let (_, _, _, bonding) = setup_contracts();

//     // Test initial price
//     let initial_price = bonding.get_current_price();
//     let price_zero_mcap = bonding.get_price_for_market_cap(0);
//     assert!(initial_price == price_zero_mcap, "Price inconsistency at 0 market cap");

//     // Test price increases with market cap
//     let price_1eth = bonding.get_price_for_market_cap(ONE_ETH);
//     let price_10eth = bonding.get_price_for_market_cap(TEN_ETH);
//     let price_100eth = bonding.get_price_for_market_cap(HUNDRED_ETH);

//     assert!(price_1eth > initial_price, "Price should increase with market cap");
//     assert!(price_10eth > price_1eth, "Price should increase with market cap");
//     assert!(price_100eth > price_10eth, "Price should increase with market cap");
// }

// #[test]
// #[fork("MAINNET_LATEST")]
// fn test_buy_simulation() {
//     let (eth_holder, _, eth, bonding) = setup_contracts();

//     // Test buying with different amounts
//     let amounts = array![ONE_ETH, TEN_ETH, HUNDRED_ETH];

//     let mut i = 0;
//     loop {
//         if i >= amounts.len() {
//             break;
//         }
//         let amount = *amounts.at(i);

//         // Simulate buy
//         let tokens_expected = bonding.simulate_buy(amount);
//         assert!(tokens_expected > 0, "Should get tokens for ETH");

//         // Simulate buying specific token amount
//         let eth_needed = bonding.simulate_buy_for(tokens_expected);
//         let diff = if eth_needed > amount {
//             eth_needed - amount
//         } else {
//             amount - eth_needed
//         };

//         assert!(diff <= amount / 100, "Buy simulation inconsistency"); // 1% tolerance
//         i += 1;
//     }
// }

// #[test]
// #[fork("MAINNET_LATEST")]
// fn test_buy_sell_cycle() {
//     let (eth_holder, eth_address, eth, bonding) = setup_contracts();

//     // Setup approvals
//     start_cheat_caller_address(eth_address, eth_holder);
//     eth.approve(bonding.contract_address, ~0_u256);
//     stop_cheat_caller_address(eth_address);

//     // Buy tokens
//     start_cheat_caller_address(bonding.contract_address, eth_holder);
//     let test_amount = TEN_ETH;
//     let tokens_received = bonding.buy(test_amount);
//     stop_cheat_caller_address(bonding.contract_address);

//     assert!(tokens_received > 0, "Should receive tokens");

//     // Simulate sell
//     let eth_expected = bonding.simulate_sell(tokens_received);

//     // Actual sell
//     start_cheat_caller_address(bonding.contract_address, eth_holder);
//     let eth_received = bonding.sell(tokens_received);
//     stop_cheat_caller_address(bonding.contract_address);

//     assert!(eth_received == eth_expected, "Sell simulation mismatch");

//     // Account for taxes in buy-sell cycle
//     let (buy_tax, sell_tax) = bonding.get_taxes();

//     let total_tax_percentage = (buy_tax + sell_tax).into();
//     let expected_eth_after_taxes = test_amount * (10000 - total_tax_percentage) / 10000;

//     // Allow for small price impact
//     let diff = if eth_received > expected_eth_after_taxes {
//         eth_received - expected_eth_after_taxes
//     } else {
//         expected_eth_after_taxes - eth_received
//     };

//     assert!(
//         diff <= test_amount / 10, "Buy-sell cycle loss too high"
//     ); // 10% tolerance for price impact
// }

// #[test]
// #[fork("MAINNET_LATEST")]
// fn test_liquidity_pool_launch() {
//     let (eth_holder, eth_address, eth, bonding) = setup_contracts();

//     // Calculate amount needed to trigger pool launch
//     let eth_needed = bonding.simulate_buy_for(LP_CAP);

//     // Setup approvals
//     start_cheat_caller_address(eth_address, eth_holder);
//     eth.approve(bonding.contract_address, eth_needed);
//     stop_cheat_caller_address(eth_address);

//     // Buy enough to trigger launch
//     start_cheat_caller_address(bonding.contract_address, eth_holder);
//     let tokens_received = bonding.buy(eth_needed);
//     stop_cheat_caller_address(bonding.contract_address);

//     // Verify launch occurred
//     assert!(tokens_received <= LP_CAP, "Should not exceed LP cap");
//     // Add more post-launch verification as needed
// }

// #[test]
// #[should_panic(expected: 'Insufficient balance')]
// #[fork("MAINNET_LATEST")]
// fn test_buy_insufficient_balance() {
//     let (eth_holder, eth_address, eth, bonding) = setup_contracts();

//     // Try to buy without approval
//     start_cheat_caller_address(bonding.contract_address,
//     0x04D8eB0b92839aBd23257c32152a39BfDb378aDc0366ca92e2a4403353BAad51.try_into().unwrap());
//     bonding.buy(ONE_ETH);
//     stop_cheat_caller_address(bonding.contract_address);
// }

// #[test]
// #[should_panic(expected: 'Insufficient balance')]
// #[fork("MAINNET_LATEST")]
// fn test_sell_insufficient_balance() {
//     let (eth_holder, _, _, bonding) = setup_contracts();

//     // Try to sell without holding tokens
//     start_cheat_caller_address(bonding.contract_address, eth_holder);
//     bonding.sell(ONE_ETH);
//     stop_cheat_caller_address(bonding.contract_address);
// }


