# tax-erc20

## About

Tax ERC20 with bonding curve and pool launch on Starknet.

## Project setup

### 📦 Requirements

- [scarb 2.8.5](https://docs.swmansion.com/scarb/download.html#install-via-asdf)

### ⛏️ Compile

```bash
scarb build
```

### 🌡️ Test

```bash
scarb test
```

## 📚 Deployment

### Token

```bash
starkli declare --keystore-password $KEYSTORE_PASSWORD target/dev/tax_erc20_integrationtest_BondingCurve.test.contract_class.json --watch
```

Constructor Arguments:
```rust
_protocol_wallet: ContractAddress,
_creator: ContractAddress,
_name: ByteArray,
_symbol: ByteArray,
price_x1e18: felt252,
exponent_x1e18: felt252,
_step: u32,
_buy_tax_percentage_x100: u16,
_sell_tax_percentage_x100: u16,
_locker: ContractAddress
```

Example
```bash
starkli deploy --keystore-password $KEYSTORE_PASSWORD <BONDING_CLASS_HASH> \
0xdeployer \
0xcreator \
0 str:'LEFTCURVE' 9 \
0 str:'LFTCRV' 6 \
5000000 \
2555000000000 \
3000 \
1000 \
1000 \
0x0locker --watch
```

### Locker

```bash
starkli declare --keystore-password $KEYSTORE_PASSWORD target/dev/tax_erc20_GradualLocker.contract_class.json --watch
starkli deploy --keystore-password $KEYSTORE_PASSWORD <LOCKER_CLASSHASH> --watch
```