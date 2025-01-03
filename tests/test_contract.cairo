use tax_erc20::contract::v2_pool_factory_interface::{IFactoryDispatcher,IFactoryDispatcherTrait};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use  starknet::{ContractAddress,contract_address_const};

const CONTRACT_ADDRESS: felt252 =
0x02a93ef8c7679a5f9b1fcf7286a6e1cadf2e9192be4bcb5cb2d1b39062697527;

#[test]
#[fork("MAINNET_LATEST")]
fn test_using_forked_state() {
    let factory = IFactoryDispatcher {
        contract_address: CONTRACT_ADDRESS.try_into().unwrap()
    };

    let tax_token_contract = declare("TaxERC20").unwrap().contract_class();
    println!("declared Tax token contract", );
    let stable_contract = declare("USDCarb").unwrap().contract_class();
    println!("declared stable_contract", );
    // Alternatively we could use `deploy_syscall` here
    let stable_address = deploy_erc20();
    println!("Stable address = {:?}", stable_address);
    let tax_token_address = deploy_tax_erc20();
    println!("tax_token address = {:?}", tax_token_address);

    // Create a Dispatcher object that will allow interacting with the deployed contract
    let numPoolBefore = factory.num_of_pairs();
    assert!(numPoolBefore > 0);
    
    
    
    let pair_address = factory.create_pair(tax_token_address, stable_address);
    






}

pub fn deploy_erc20() -> ContractAddress {
    let contract = declare("USDCarb").expect('Declaration failed').contract_class();
    let owner: ContractAddress = contract_address_const::<'OWNER'>();
    let mut calldata: Array<felt252> = array![];
    calldata.append(owner.into());
    calldata.append(owner.into());
    let (contract_address, _) = contract.deploy(@calldata).expect('Erc20 deployment failed');

    contract_address
}

pub fn deploy_tax_erc20() -> ContractAddress {
    let contract = declare("TaxERC20").expect('Declaration failed').contract_class();
    let owner: ContractAddress = contract_address_const::<'OWNER'>();
    let mut calldata: Array<felt252> = array![];
    calldata.append(owner.into());
    let name = 'Name';
    let symbol = 'Symbol';

    calldata.append(name);
    calldata.append(symbol);
    let (contract_address, _) = contract.deploy(@calldata).expect('Erc20 deployment failed');

    contract_address
}