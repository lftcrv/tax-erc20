"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g = Object.create((typeof Iterator === "function" ? Iterator : Object).prototype);
    return g.next = verb(0), g["throw"] = verb(1), g["return"] = verb(2), typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (g && (g = 0, op[0] && (_ = 0)), _) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RPC_URLS = void 0;
exports.deployBondingCurve = deployBondingCurve;
exports.get_price = get_price;
exports.decimals = decimals;
exports.getCurrentPrice = getCurrentPrice;
exports.getPriceForMarketCap = getPriceForMarketCap;
exports.getMarketCapForPrice = getMarketCapForPrice;
exports.getMarketCap = getMarketCap;
exports.simulateBuy = simulateBuy;
exports.simulateSell = simulateSell;
exports.buy = buy;
exports.sell = sell;
exports.getTaxes = getTaxes;
exports.approve = approve;
var starknet_1 = require("starknet");
var fs_1 = require("fs");
var dotenv = require("dotenv");
dotenv.config();
// RPC endpoints
var RPC_URLS = {
    MAINNET: "https://starknet-mainnet.public.blastapi.io/rpc/v0_7",
    TESTNET: "https://starknet-sepolia.public.blastapi.io",
};
exports.RPC_URLS = RPC_URLS;
/**
 * Deploys a bonding curve contract
 * @param args Constructor arguments for the contract
 * @param isTestnet Whether to deploy to testnet or mainnet
 * @returns The deployed contract instance and deployment details
 */
function deployBondingCurve(args_1) {
    return __awaiter(this, arguments, void 0, function (args, isTestnet) {
        var contractJson, csmJson, provider, privateKey, accountAddress, account, contractCallData, constructorCalldata, deployResponse, deployedContract, error_1;
        if (isTestnet === void 0) { isTestnet = true; }
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 2, , 3]);
                    contractJson = starknet_1.json.parse(fs_1.default.readFileSync("./target/dev/tax_erc20_BondingCurve.contract_class.json", "utf-8"));
                    csmJson = starknet_1.json.parse(fs_1.default.readFileSync("./target/dev/tax_erc20_BondingCurve.compiled_contract_class.json", "utf-8"));
                    provider = new starknet_1.RpcProvider({
                        nodeUrl: isTestnet ? RPC_URLS.TESTNET : RPC_URLS.MAINNET,
                    });
                    privateKey = isTestnet ? process.env.DEV_PK : process.env.MAIN_PK;
                    accountAddress = isTestnet
                        ? process.env.DEV_ADDRESS
                        : process.env.MAIN_ADDRESS;
                    if (!privateKey || !accountAddress) {
                        throw new Error("Missing required environment variables for account setup");
                    }
                    account = new starknet_1.Account(provider, accountAddress, privateKey);
                    contractCallData = new starknet_1.CallData(contractJson.abi);
                    constructorCalldata = contractCallData.compile("constructor", args);
                    console.log("Pre deploy response");
                    return [4 /*yield*/, account.declareAndDeploy({
                            contract: contractJson,
                            casm: csmJson,
                            constructorCalldata: constructorCalldata,
                        })];
                case 1:
                    deployResponse = _a.sent();
                    console.log("deployResponse");
                    deployedContract = new starknet_1.Contract(contractJson.abi, deployResponse.deploy.contract_address, provider);
                    console.log({
                        //   classHash: deployResponse.declare.class_hash,
                        contractAddress: deployedContract.address,
                        //   network: isTestnet ? "testnet" : "mainnet",
                    });
                    return [2 /*return*/, {
                            contract: deployedContract,
                            deployResponse: deployResponse,
                        }];
                case 2:
                    error_1 = _a.sent();
                    // console.error("Error deploying bonding curve:", error);
                    throw error_1;
                case 3: return [2 /*return*/];
            }
        });
    });
}
function main() {
    return __awaiter(this, void 0, void 0, function () {
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0: return [4 /*yield*/, deployBondingCurve({
                        _protocol_wallet: "0x04D8eB0b92839aBd23257c32152a39BfDb378aDc0366ca92e2a4403353BAad51",
                        _owner: "0x04D8eB0b92839aBd23257c32152a39BfDb378aDc0366ca92e2a4403353BAad51",
                        _name: "LeftCurve",
                        _symbol: "LFTCRV",
                        price_x1e9: 5,
                        exponent_x1e9: 613020000,
                        step: 1e6,
                        buy_tax_percentage_x100: 500,
                        sell_tax_percentage_x100: 1000,
                    })];
                case 1:
                    _a.sent();
                    return [2 /*return*/];
            }
        });
    });
}
main()
    .then(function () { return process.exit(0); })
    .catch(function (error) {
    console.error(error);
    process.exit(1);
});
function get_price(bond, amount_token) {
    return __awaiter(this, void 0, void 0, function () {
        var priceCalldata, response;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    priceCalldata = bond.populate("get_price", {
                        amount_token: amount_token,
                    });
                    return [4 /*yield*/, bond.get_price(priceCalldata.calldata)];
                case 1:
                    response = _a.sent();
                    console.log(response);
                    return [2 /*return*/, response]; //check to return an object
            }
        });
    });
}
function decimals(bond) {
    return __awaiter(this, void 0, void 0, function () {
        var response, error_2;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 2, , 3]);
                    return [4 /*yield*/, bond.decimals()];
                case 1:
                    response = _a.sent();
                    return [2 /*return*/, Number(response)];
                case 2:
                    error_2 = _a.sent();
                    console.error("Error getting decimals:", error_2);
                    throw error_2;
                case 3: return [2 /*return*/];
            }
        });
    });
}
function getCurrentPrice(bond) {
    return __awaiter(this, void 0, void 0, function () {
        var response, error_3;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 2, , 3]);
                    return [4 /*yield*/, bond.get_current_price()];
                case 1:
                    response = _a.sent();
                    return [2 /*return*/, BigInt(response)];
                case 2:
                    error_3 = _a.sent();
                    console.error("Error getting current price:", error_3);
                    throw error_3;
                case 3: return [2 /*return*/];
            }
        });
    });
}
function getPriceForMarketCap(bond, marketCap) {
    return __awaiter(this, void 0, void 0, function () {
        var response, error_4;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 2, , 3]);
                    return [4 /*yield*/, bond.get_price_for_supply(marketCap)];
                case 1:
                    response = _a.sent();
                    return [2 /*return*/, BigInt(response)];
                case 2:
                    error_4 = _a.sent();
                    console.error("Error getting price for market cap:", error_4);
                    throw error_4;
                case 3: return [2 /*return*/];
            }
        });
    });
}
function getMarketCapForPrice(bond, price) {
    return __awaiter(this, void 0, void 0, function () {
        var response, error_5;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 2, , 3]);
                    return [4 /*yield*/, bond.market_cap_for_price(price)];
                case 1:
                    response = _a.sent();
                    return [2 /*return*/, BigInt(response)];
                case 2:
                    error_5 = _a.sent();
                    console.error("Error getting market cap for price:", error_5);
                    throw error_5;
                case 3: return [2 /*return*/];
            }
        });
    });
}
function getMarketCap(bond) {
    return __awaiter(this, void 0, void 0, function () {
        var response, error_6;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 2, , 3]);
                    return [4 /*yield*/, bond.market_cap()];
                case 1:
                    response = _a.sent();
                    return [2 /*return*/, BigInt(response)];
                case 2:
                    error_6 = _a.sent();
                    console.error("Error getting market cap:", error_6);
                    throw error_6;
                case 3: return [2 /*return*/];
            }
        });
    });
}
function simulateBuy(bond, ethAmount) {
    return __awaiter(this, void 0, void 0, function () {
        var response, error_7;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 2, , 3]);
                    return [4 /*yield*/, bond.simulate_buy(ethAmount)];
                case 1:
                    response = _a.sent();
                    return [2 /*return*/, BigInt(response)];
                case 2:
                    error_7 = _a.sent();
                    console.error("Error simulating buy:", error_7);
                    throw error_7;
                case 3: return [2 /*return*/];
            }
        });
    });
}
function simulateSell(bond, tokenAmount) {
    return __awaiter(this, void 0, void 0, function () {
        var response, error_8;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 2, , 3]);
                    return [4 /*yield*/, bond.simulate_sell(tokenAmount)];
                case 1:
                    response = _a.sent();
                    return [2 /*return*/, BigInt(response)];
                case 2:
                    error_8 = _a.sent();
                    console.error("Error simulating sell:", error_8);
                    throw error_8;
                case 3: return [2 /*return*/];
            }
        });
    });
}
function buy(bond, provider, tokenAmount) {
    return __awaiter(this, void 0, void 0, function () {
        var response, error_9;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 3, , 4]);
                    return [4 /*yield*/, bond.buy(tokenAmount)];
                case 1:
                    response = _a.sent();
                    console.log("Buy transaction submitted:", response);
                    return [4 /*yield*/, provider.waitForTransaction(response.transaction_hash)];
                case 2:
                    _a.sent();
                    return [2 /*return*/, response];
                case 3:
                    error_9 = _a.sent();
                    console.error("Error buying tokens:", error_9);
                    throw error_9;
                case 4: return [2 /*return*/];
            }
        });
    });
}
function sell(bond, provider, tokenAmount) {
    return __awaiter(this, void 0, void 0, function () {
        var response, error_10;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 3, , 4]);
                    return [4 /*yield*/, bond.sell(tokenAmount)];
                case 1:
                    response = _a.sent();
                    console.log("Sell transaction submitted:", response);
                    return [4 /*yield*/, provider.waitForTransaction(response.transaction_hash)];
                case 2:
                    _a.sent();
                    return [2 /*return*/, response];
                case 3:
                    error_10 = _a.sent();
                    console.error("Error selling tokens:", error_10);
                    throw error_10;
                case 4: return [2 /*return*/];
            }
        });
    });
}
function getTaxes(bond) {
    return __awaiter(this, void 0, void 0, function () {
        var _a, buyTax, sellTax, error_11;
        return __generator(this, function (_b) {
            switch (_b.label) {
                case 0:
                    _b.trys.push([0, 2, , 3]);
                    return [4 /*yield*/, bond.get_taxes()];
                case 1:
                    _a = _b.sent(), buyTax = _a[0], sellTax = _a[1];
                    return [2 /*return*/, [Number(buyTax), Number(sellTax)]];
                case 2:
                    error_11 = _b.sent();
                    console.error("Error getting taxes:", error_11);
                    throw error_11;
                case 3: return [2 /*return*/];
            }
        });
    });
}
function approve(bond, provider, spender, amount) {
    return __awaiter(this, void 0, void 0, function () {
        var response, error_12;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 3, , 4]);
                    return [4 /*yield*/, bond.approve(spender, amount)];
                case 1:
                    response = _a.sent();
                    console.log("Approve transaction submitted:", response);
                    return [4 /*yield*/, provider.waitForTransaction(response.transaction_hash)];
                case 2:
                    _a.sent();
                    return [2 /*return*/, response];
                case 3:
                    error_12 = _a.sent();
                    console.error("Error approving tokens:", error_12);
                    throw error_12;
                case 4: return [2 /*return*/];
            }
        });
    });
}
