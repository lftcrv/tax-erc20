import {
  RpcProvider,
  Account,
  Contract,
  json,
  stark,
  uint256,
  shortString,
} from "starknet";

const provider = new RpcProvider({ baseUrl: "http://127.0.0.1:5050/rpc" });
// connect your account. To adapt to your own account:
const privateKey0 = process.env.OZ_ACCOUNT_PRIVATE_KEY!;
const account0Address: string =
  "0x0614d7b81d06b81363ec009e16861561b702ba9fdc335ff1a18d2169029fbfc8";

const account0 = new Account(provider, account0Address, privateKey0);

// Deploy Test contract in devnet
// ClassHash of the already declared contract
const testClassHash =
  "0xff0378becffa6ad51c67ac968948dbbd110b8a8550397cf17866afebc6c17d";

const deployResponse = await account0.deployContract({
  classHash: testClassHash,
});
await provider.waitForTransaction(deployResponse.transaction_hash);

// read abi of Test contract
const { abi: testAbi } = await provider.getClassByHash(testClassHash);
if (testAbi === undefined) {
  throw new Error("no abi.");
}

// Connect the new contract instance:
const myTestContract = new Contract(
  testAbi,
  deployResponse.contract_address,
  provider
);
console.log("✅ Test Contract connected at =", myTestContract.address);
