use starknet::ContractAddress;

#[starknet::interface]
pub trait IBondingCurve<TContractState> {
    // View functions
    fn name(self: @TContractState) -> ByteArray;
    fn creator(self: @TContractState) -> ContractAddress;
    fn symbol(self: @TContractState) -> ByteArray;
    fn decimals(self: @TContractState) -> u8;
    fn get_current_price(self: @TContractState) -> u256;
    fn buy_tax_percentage_x100(self: @TContractState) -> u16;
    fn sell_tax_percentage_x100(self: @TContractState) -> u16;
    fn market_cap(self: @TContractState) -> u256;
    fn get_price_for_supply(self: @TContractState, supply: u256) -> u256;
    fn market_cap_for_price(self: @TContractState, price: u256) -> u256;
    fn simulate_buy(self: @TContractState, token_amount: u256) -> u256;
    fn simulate_sell(self: @TContractState, token_amount: u256) -> u256;
    fn get_taxes(self: @TContractState) -> (u16, u16);

    // ERC20 standard functions
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;

    // External functions
    fn buy(ref self: TContractState, token_amount: u256) -> u256;
    fn sell(ref self: TContractState, token_amount: u256) -> u256;
    fn skim(ref self: TContractState) -> u256;
}

// Events
#[derive(Drop, starknet::Event)]
pub struct Transfer {
    #[key]
    pub from: ContractAddress,
    #[key]
    pub to: ContractAddress,
    pub value: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Approval {
    #[key]
    pub owner: ContractAddress,
    #[key]
    pub spender: ContractAddress,
    pub value: u256,
}

#[derive(Drop, starknet::Event)]
pub struct BuyOrSell {
    #[key]
    pub from: ContractAddress,
    pub amount: u256,
    pub value: u256,
}

#[derive(Drop, starknet::Event)]
pub struct PoolLaunched {
    #[key]
    pub amount_token: u256,
    pub amount_eth: u256,
    pub amount_lp: u256,
    pub pair_address: ContractAddress,
    pub creator: ContractAddress,
}