import { RpcProvider, Account, Contract, json, CallData } from "starknet";
import fs from "fs";
import * as dotenv from "dotenv";
dotenv.config();
// RPC endpoints
const RPC_URLS = {
  MAINNET: "https://starknet-mainnet.public.blastapi.io/rpc/v0_7",
  DEVNET: "http://127.0.0.1:5050/rpc",
} as const;

interface TransactionResponse {
  transaction_hash: string;
  address?: string;
  status?: string;
}
// Constructor arguments interface
type ConstructorArgs = {
  _protocol_wallet: string;
  _owner: string;
  _name: string;
  _symbol: string;
  price_x1e9: number;
  exponent_x1e9: number;
  buy_tax_percentage_x100: number;
  sell_tax_percentage_x100: number;
};

/**
 * Deploys a bonding curve contract
 * @param args Constructor arguments for the contract
 * @param isDevnet Whether to deploy to devnet or mainnet
 * @returns The deployed contract instance and deployment details
 */
async function deployBondingCurve(
  args: ConstructorArgs,
  isDevnet: boolean = true
) {
  try {
    // Read and parse contract JSON
    const contractJson = json.parse(
      fs.readFileSync(
        "./target/dev/tax_erc20_BondingCurve.contract_class.json",
        "utf-8"
      )
    );

    const csmJson = json.parse(
      fs.readFileSync(
        "./target/dev/tax_erc20_BondingCurve.compiled_contract_class.json",
        "utf-8"
      )
    );
    // Initialize provider
    const provider = new RpcProvider({
      nodeUrl: isDevnet ? RPC_URLS.DEVNET : RPC_URLS.MAINNET,
    });

    // Initialize account
    const privateKey = isDevnet ? process.env.DEV_PK : process.env.MAIN_PK;
    const accountAddress = isDevnet
      ? process.env.DEV_ADDRESS
      : process.env.MAIN_ADDRESS;

    if (!privateKey || !accountAddress) {
      throw new Error(
        "Missing required environment variables for account setup"
      );
    }

    const account = new Account(provider, accountAddress, privateKey);

    // Prepare constructor calldata
    const contractCallData = new CallData(contractJson.abi);
    const constructorCalldata = contractCallData.compile("constructor", args);
    console.log("Pre deploy response");
    // Deploy contract
    const deployResponse = await account.declareAndDeploy({
      contract: contractJson,
      casm: csmJson,
      // constructorCalldata: constructorCalldata,
    });
    console.log("deployResponse");

    // Initialize contract instance
    const deployedContract = new Contract(
      contractJson.abi,
      deployResponse.deploy.contract_address,
      provider
    );

    console.log({
      //   classHash: deployResponse.declare.class_hash,
      contractAddress: deployedContract.address,
      //   network: isDevnet ? "devnet" : "mainnet",
    });

    return {
      contract: deployedContract,
      deployResponse,
    };
  } catch (error) {
    // console.error("Error deploying bonding curve:", error);
    throw error;
  }
}

export { deployBondingCurve, ConstructorArgs, RPC_URLS };
async function main() {
  await deployBondingCurve({
    _protocol_wallet:
      "0x04D8eB0b92839aBd23257c32152a39BfDb378aDc0366ca92e2a4403353BAad51",
    _owner:
      "0x04D8eB0b92839aBd23257c32152a39BfDb378aDc0366ca92e2a4403353BAad51",
    _name: "LeftCurve",
    _symbol: "LFTCRV",
    price_x1e9: 5,
    exponent_x1e9: 613020000,
    buy_tax_percentage_x100: 500,
    sell_tax_percentage_x100: 1000,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

export async function get_price(bond: Contract, amount_token: BigInt) {
  const priceCalldata = bond.populate("get_price", {
    amount_token: amount_token,
  });
  const response = await bond.get_price(priceCalldata.calldata);
  console.log(response);
  return response; //check to return an object

  //check to return an object
}

export async function decimals(bond: Contract): Promise<number> {
  try {
    const response = await bond.decimals();
    return Number(response);
  } catch (error) {
    console.error("Error getting decimals:", error);
    throw error;
  }
}

export async function getCurrentPrice(bond: Contract): Promise<bigint> {
  try {
    const response = await bond.get_current_price();
    return BigInt(response);
  } catch (error) {
    console.error("Error getting current price:", error);
    throw error;
  }
}

export async function getPriceForMarketCap(
  bond: Contract,
  marketCap: bigint
): Promise<bigint> {
  try {
    const response = await bond.get_price_for_supply(marketCap);
    return BigInt(response);
  } catch (error) {
    console.error("Error getting price for market cap:", error);
    throw error;
  }
}

export async function getMarketCapForPrice(
  bond: Contract,
  price: bigint
): Promise<bigint> {
  try {
    const response = await bond.market_cap_for_price(price);
    return BigInt(response);
  } catch (error) {
    console.error("Error getting market cap for price:", error);
    throw error;
  }
}

export async function getMarketCap(bond: Contract): Promise<bigint> {
  try {
    const response = await bond.market_cap();
    return BigInt(response);
  } catch (error) {
    console.error("Error getting market cap:", error);
    throw error;
  }
}

export async function simulateBuy(
  bond: Contract,
  ethAmount: bigint
): Promise<bigint> {
  try {
    const response = await bond.simulate_buy(ethAmount);
    return BigInt(response);
  } catch (error) {
    console.error("Error simulating buy:", error);
    throw error;
  }
}

export async function simulateBuyFor(
  bond: Contract,
  tokenAmount: bigint
): Promise<bigint> {
  try {
    const response = await bond.simulate_buy_for(tokenAmount);
    return BigInt(response);
  } catch (error) {
    console.error("Error simulating buy for:", error);
    throw error;
  }
}

export async function simulateSell(
  bond: Contract,
  tokenAmount: bigint
): Promise<bigint> {
  try {
    const response = await bond.simulate_sell(tokenAmount);
    return BigInt(response);
  } catch (error) {
    console.error("Error simulating sell:", error);
    throw error;
  }
}

export async function buy(
  bond: Contract,
  provider: RpcProvider,
  ethAmount: bigint
): Promise<TransactionResponse> {
  try {
    const response = await bond.buy(ethAmount);
    console.log("Buy transaction submitted:", response);
    await provider.waitForTransaction(response.transaction_hash);
    return response;
  } catch (error) {
    console.error("Error buying tokens:", error);
    throw error;
  }
}

export async function buyFor(
  bond: Contract,
  provider: RpcProvider,
  ethAmount: bigint
): Promise<TransactionResponse> {
  try {
    const response = await bond.buy_for(ethAmount);
    console.log("Buy For transaction submitted:", response);
    await provider.waitForTransaction(response.transaction_hash);
    return response;
  } catch (error) {
    console.error("Error buying tokens for amount:", error);
    throw error;
  }
}

export async function sell(
  bond: Contract,
  provider: RpcProvider,
  tokenAmount: bigint
): Promise<TransactionResponse> {
  try {
    const response = await bond.sell(tokenAmount);
    console.log("Sell transaction submitted:", response);
    await provider.waitForTransaction(response.transaction_hash);
    return response;
  } catch (error) {
    console.error("Error selling tokens:", error);
    throw error;
  }
}

export async function getTaxes(bond: Contract): Promise<[number, number]> {
  try {
    const [buyTax, sellTax] = await bond.get_taxes();
    return [Number(buyTax), Number(sellTax)];
  } catch (error) {
    console.error("Error getting taxes:", error);
    throw error;
  }
}

export async function approve(
  bond: Contract,
  provider: RpcProvider,
  spender: string,
  amount: bigint
): Promise<TransactionResponse> {
  try {
    const response = await bond.approve(spender, amount);
    console.log("Approve transaction submitted:", response);
    await provider.waitForTransaction(response.transaction_hash);
    return response;
  } catch (error) {
    console.error("Error approving tokens:", error);
    throw error;
  }
}
