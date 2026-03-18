# Tuxedo

Solidity smart contracts for ZTX.

## Dependencies

- [Foundry](https://github.com/foundry-rs/foundry)
- [npm](https://docs.npmjs.com/getting-started)
- [Slither](https://github.com/crytic/slither)

## Documentation

For further details, see the [docs](./doc/contracts).

For deployment and governance proposal information, see the [proposals README](./proposals/README.md).
And for information on the zk deployment cli see the [run manager docs](./script/zk/README.md).

## Setup

```console
npm install
```

The system also requires the following environment variables to be set:

| Variable               | Description                                                           |
|------------------------|-----------------------------------------------------------------------|
| `ADDRESS_FILE`         | Address JSON filename without extension (e.g. `creator-testnet`).     |
| `ENVIRONMENT`          | Used for metadata URI subdomain (e.g. `qa`, `mainnet`).               |
| `DOMAIN`               | Used for metadata URI domain (e.g. `ztx.io`).                         |
| `DEPLOYER_PRIVATE_KEY` | The private key of the deployer.                                      |

See the included `.env.example` for an example.

## Build

To build, run:

```console
forge build
```

## Tests

To run the unit tests:

```console
npm run test:unit
```

and the integration tests:

```console
npm run test:integration
```

## Creator Chain Deployment

Creator chain (Atlas VM) is fully EVM compatible. Deployment uses standard Foundry `forge script` with phased execution to support deploying without the token contract (canonical ZTX arrives via bridge from Arb One).

### Deployment Phases

**Phase 1** — Core infrastructure (deployer ADMIN is revoked after this phase):

```bash
ADDRESS_FILE=creator-mainnet ENVIRONMENT=mainnet DOMAIN=ztx.io \
  forge script script/deploy/BootstrapMainnet.s.sol:BootstrapMainnetPhase1 \
    -vvvv --rpc-url https://rpc.mainnet.oncreator.com \
    --broadcast --private-key $DEPLOYER_PRIVATE_KEY \
    --verify --verifier custom \
    --verifier-url https://explorer-api.mainnet.oncreator.com/api
```

Deploys: Core, GlobalReentrancyLock, Wearables, AdminMinter, BatchOperator, TimelockController.

**Manual step** — From ADMIN_MULTISIG (Safe), grant ADMIN role to the TimelockController:

```bash
# Generate calldata
cast calldata "grantRole(bytes32,address)" \
  0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775 \
  <ADMIN_TIMELOCK_CONTROLLER_ADDRESS>
```

Submit to the CORE contract address from ADMIN_MULTISIG.

**Phase 2** — NFT collections and minting infrastructure:

```bash
ADDRESS_FILE=creator-mainnet ENVIRONMENT=mainnet DOMAIN=ztx.io \
  forge script script/deploy/BootstrapMainnet.s.sol:BootstrapMainnetPhase2 \
    -vvvv --rpc-url https://rpc.mainnet.oncreator.com \
    --broadcast --private-key $DEPLOYER_PRIVATE_KEY \
    --verify --verifier custom \
    --verifier-url https://explorer-api.mainnet.oncreator.com/api
```

Deploys: Consumables, Placeables, Enhanceables, AutoGraphMinter, AutoGraphBatchMinter.

**Timelock governance** — After Phase 2, submit schedule+execute calldata for zip003 (role grants) and zip004 (supply caps) through ADMIN_MULTISIG → TimelockController:

```bash
ADDRESS_FILE=creator-mainnet ENVIRONMENT=mainnet DOMAIN=ztx.io \
DO_DEPLOY=false DO_SIMULATE=false DO_VALIDATE=false DO_PRINT=true \
  forge script script/deploy/PrintTimelockCalldata.s.sol:PrintTimelockCalldata \
    -vvvv --rpc-url https://rpc.mainnet.oncreator.com
```

Submit 4 Safe transactions to ADMIN_TIMELOCK_CONTROLLER (schedule+execute for each ZIP).

**Phase 3** (future) — ERC20Splitter + GameConsumer via zip005, after the bridged ZTX token address is known.

### Testnet

Same flow using `BootstrapTestnet.s.sol` with `ADDRESS_FILE=creator-testnet ENVIRONMENT=qa DOMAIN=ztx.io` and RPC `https://rpc.testnet.oncreator.com`.

### Legacy Deployment (zkSync Era VM)

The `script/zk/deploy.ts` CLI was used for zkSync Era VM deployments. Creator chain uses Atlas VM which is fully EVM compatible, so standard Foundry scripts are used instead. See the [zkSync deployment docs](./script/zk/README.md) for the legacy flow.

### Address Files

Deployed addresses are stored in `proposals/Addresses/`:
- `creator-mainnet.json` — Creator Mainnet (chain ID 2787)
- `creator-testnet.json` — Creator Testnet (chain ID 278701)

## Linter

To run the linter:

```console
npm run lint:check
```

## ABI

To generate the ABI files, simply run:

```console
npm run clean && npm run build
```

## Static Analysis

We use [Slither](https://github.com/crytic/slither) to analyse our contracts.

### Install

```console
npm run slither:install
```

### Run

```console
npm run slither
```

## Contracts

### Creator Mainnet (chain ID 2787)

| Address | Contract |
|---------|----------|
| [`0x4c256f578e599bff9f9bb74fd499b76a1130c008`](https://explorer.mainnet.oncreator.com/address/0x4c256f578e599bff9f9bb74fd499b76a1130c008) | [CORE](./src/core/Core.sol) |
| [`0xfba7148d6200fbb769dbcb0413aaf850ec93ab2e`](https://explorer.mainnet.oncreator.com/address/0xfba7148d6200fbb769dbcb0413aaf850ec93ab2e) | [GLOBAL_REENTRANCY_LOCK](./src/core/GlobalReentrancyLock.sol) |
| [`0xd3ebd6b64968b7b6fc98a9c5a11002ba65c71427`](https://explorer.mainnet.oncreator.com/address/0xd3ebd6b64968b7b6fc98a9c5a11002ba65c71427) | [ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES](./src/nfts/ERC1155MaxSupplyMintable.sol) |
| [`0xdfdeb60e5d3bca322fb5ffcb02f0718744e9d31f`](https://explorer.mainnet.oncreator.com/address/0xdfdeb60e5d3bca322fb5ffcb02f0718744e9d31f) | [ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES](./src/nfts/ERC1155MaxSupplyMintable.sol) |
| [`0x67e23d3c1353d88ee09a7e0860af59e8e5997577`](https://explorer.mainnet.oncreator.com/address/0x67e23d3c1353d88ee09a7e0860af59e8e5997577) | [ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES](./src/nfts/ERC1155MaxSupplyMintable.sol) |
| [`0x6300fcdbf06da84aeef3a8cecd525955757191cc`](https://explorer.mainnet.oncreator.com/address/0x6300fcdbf06da84aeef3a8cecd525955757191cc) | [ERC1155_MAX_SUPPLY_MINTABLE_ENHANCEABLES](./src/nfts/ERC1155MaxSupplyMintable.sol) |
| [`0xe83c2ec735c7a81ad33d37aadfde50a01e5fabc8`](https://explorer.mainnet.oncreator.com/address/0xe83c2ec735c7a81ad33d37aadfde50a01e5fabc8) | [ERC1155_MAX_SUPPLY_ADMIN_MINTER](./src/nfts/ERC1155AdminMinter.sol) |
| [`0xf2fdff2d3e8ff138a5d7cde4ecd99e49d7f58476`](https://explorer.mainnet.oncreator.com/address/0xf2fdff2d3e8ff138a5d7cde4ecd99e49d7f58476) | [ERC1155_BATCH_OPERATOR](./src/nfts/ERC1155BatchOperator.sol) |
| [`0xe9ab7510420cb2e9d8a01755e0e17c80f0766789`](https://explorer.mainnet.oncreator.com/address/0xe9ab7510420cb2e9d8a01755e0e17c80f0766789) | [ERC1155_AUTO_GRAPH_MINTER](./src/nfts/ERC1155AutoGraphMinter.sol) |
| [`0x8b83412f24b7927fd1ddf61fee4f90e8a910a873`](https://explorer.mainnet.oncreator.com/address/0x8b83412f24b7927fd1ddf61fee4f90e8a910a873) | [ERC1155_AUTO_GRAPH_BATCH_MINTER](./src/nfts/ERC1155AutoGraphBatchMinter.sol) |
| [`0xb0fb857af82a0041e9da37ccae29eacd29ddd433`](https://explorer.mainnet.oncreator.com/address/0xb0fb857af82a0041e9da37ccae29eacd29ddd433) | [ADMIN_TIMELOCK_CONTROLLER](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol) |

### Creator Testnet (chain ID 278701)

| Address | Contract |
|---------|----------|
| [`0x0b3fef37f518d0ef865b66889ea66188353b1f09`](https://explorer.testnet.oncreator.com/address/0x0b3fef37f518d0ef865b66889ea66188353b1f09) | [CORE](./src/core/Core.sol) |
| [`0xb68fd27ae67edd4da88ea9afd4333b66f62bdaa6`](https://explorer.testnet.oncreator.com/address/0xb68fd27ae67edd4da88ea9afd4333b66f62bdaa6) | [GLOBAL_REENTRANCY_LOCK](./src/core/GlobalReentrancyLock.sol) |
| [`0x84337af8f9f31340401ce273509b797a1f53e9f6`](https://explorer.testnet.oncreator.com/address/0x84337af8f9f31340401ce273509b797a1f53e9f6) | [ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES](./src/nfts/ERC1155MaxSupplyMintable.sol) |
| [`0x8aa808dea086dd7b6fbbcc87632915a309078fa9`](https://explorer.testnet.oncreator.com/address/0x8aa808dea086dd7b6fbbcc87632915a309078fa9) | [ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES](./src/nfts/ERC1155MaxSupplyMintable.sol) |
| [`0x6a4674c20d67bde3c2f193390a83bcc6c3d667b9`](https://explorer.testnet.oncreator.com/address/0x6a4674c20d67bde3c2f193390a83bcc6c3d667b9) | [ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES](./src/nfts/ERC1155MaxSupplyMintable.sol) |
| [`0xb8f6c8e23c94f2addde7284130fd8edc70a3139d`](https://explorer.testnet.oncreator.com/address/0xb8f6c8e23c94f2addde7284130fd8edc70a3139d) | [ERC1155_MAX_SUPPLY_MINTABLE_ENHANCEABLES](./src/nfts/ERC1155MaxSupplyMintable.sol) |
| [`0x6bad13dc8226a0fd0888844fed0f939ea764b512`](https://explorer.testnet.oncreator.com/address/0x6bad13dc8226a0fd0888844fed0f939ea764b512) | [ERC1155_MAX_SUPPLY_ADMIN_MINTER](./src/nfts/ERC1155AdminMinter.sol) |
| [`0xa312378f31fc261456e8edc7021229317bbd0a12`](https://explorer.testnet.oncreator.com/address/0xa312378f31fc261456e8edc7021229317bbd0a12) | [ERC1155_BATCH_OPERATOR](./src/nfts/ERC1155BatchOperator.sol) |
| [`0x882ce526a2598cfbdb0d917f7866c30520a366ca`](https://explorer.testnet.oncreator.com/address/0x882ce526a2598cfbdb0d917f7866c30520a366ca) | [ERC1155_AUTO_GRAPH_MINTER](./src/nfts/ERC1155AutoGraphMinter.sol) |
| [`0x597732c3c30c35d61a21a56ebf75bac81ea8106e`](https://explorer.testnet.oncreator.com/address/0x597732c3c30c35d61a21a56ebf75bac81ea8106e) | [ERC1155_AUTO_GRAPH_BATCH_MINTER](./src/nfts/ERC1155AutoGraphBatchMinter.sol) |
| [`0xdd8c9bfc476a76d42c4643a7bc706464a8d950f6`](https://explorer.testnet.oncreator.com/address/0xdd8c9bfc476a76d42c4643a7bc706464a8d950f6) | [ADMIN_TIMELOCK_CONTROLLER](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol) |

### Arbitrum Sepolia (devnet)

| Address                                                                                                                                 | Contract                                                                           | ABI                                                                                      |
|-----------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| [`0x68D6B4af6668A62Fc1B21ABF3DbfA366DD1d8eC7`](https://sepolia-explorer.arbitrum.io/address/0x68D6B4af6668A62Fc1B21ABF3DbfA366DD1d8eC7) | [CORE](./src/core/Core.sol)                                                        | [Core.abi.json](./dist/v1.0.0/abi/Core.abi.json)                                         |
| [`0x87D7b991540747522404c86b281E4880Cd6dE7f2`](https://sepolia-explorer.arbitrum.io/address/0x87D7b991540747522404c86b281E4880Cd6dE7f2) | [GLOBAL_REENTRANCY_LOCK](./src/core/GlobalReentrancyLock.sol)                      | [GlobalReentrancyLock.abi.json](./dist/v1.0.0/abi/GlobalReentrancyLock.abi.json)         |
| [`0x27564B8cf86aba79b398A39B75898fe8AFf30627`](https://sepolia-explorer.arbitrum.io/address/0x27564B8cf86aba79b398A39B75898fe8AFf30627) | [ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES](./src/nfts/ERC1155MaxSupplyMintable.sol)   | [ERC1155MaxSupplyMintable.abi.json](./dist/v1.0.0/abi/ERC1155MaxSupplyMintable.abi.json) |
| [`0x898C5e72Cb4121A8ae579faEAe2C5879196493fc`](https://sepolia-explorer.arbitrum.io/address/0x898C5e72Cb4121A8ae579faEAe2C5879196493fc) | [ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES](./src/nfts/ERC1155MaxSupplyMintable.sol) | [ERC1155MaxSupplyMintable.abi.json](./dist/v1.0.0/abi/ERC1155MaxSupplyMintable.abi.json) |
| [`0xa7654c44f0A4Da52a10469dC380f02F75d6E0631`](https://sepolia-explorer.arbitrum.io/address/0xa7654c44f0A4Da52a10469dC380f02F75d6E0631) | [ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES](./src/nfts/ERC1155MaxSupplyMintable.sol)  | [ERC1155MaxSupplyMintable.abi.json](./dist/v1.0.0/abi/ERC1155MaxSupplyMintable.abi.json) |
| [`0x8ccE22Fe7Bd3F4998E158De3c3a77ee85A6F6bBB`](https://sepolia-explorer.arbitrum.io/address/0x8ccE22Fe7Bd3F4998E158De3c3a77ee85A6F6bBB) | [SEASONS_TOKEN_ID_REGISTRY](./src/nfts/seasons/SeasonsTokenIdRegistry.sol)         | [SeasonsTokenIdRegistry.abi.json](./dist/v1.0.0/abi/SeasonsTokenIdRegistry.abi.json)     |
| [`0x3006b30E32dEA503503Bf9e3f909163834085A5C`](https://sepolia-explorer.arbitrum.io/address/0x3006b30E32dEA503503Bf9e3f909163834085A5C) | [ERC1155_SEASON_ONE](./src/nfts/seasons/ERC1155SeasonOne.sol)                      | [ERC1155SeasonOne.abi.json](./dist/v1.0.0/abi/ERC1155SeasonOne.abi.json)                 |
| [`0x34c775910e5CbB1511eF00Ea51cd0f6bd1E3E4Db`](https://sepolia-explorer.arbitrum.io/address/0x34c775910e5CbB1511eF00Ea51cd0f6bd1E3E4Db) | [ERC1155_MAX_SUPPLY_ADMIN_MINTER](./src/nfts/ERC1155AdminMinter.sol)               | [ERC1155AdminMinter.abi.json](./dist/v1.0.0/abi/ERC1155AdminMinter.abi.json)             |
| [`0x2a7093311D65550285AcA9650C9F9165f74337f3`](https://sepolia-explorer.arbitrum.io/address/0x2a7093311D65550285AcA9650C9F9165f74337f3) | [ERC1155_AUTO_GRAPH_MINTER](./src/nfts/ERC1155AutoGraphMinter.sol)                 | [ERC1155AutoGraphMinter.abi.json](./dist/v1.0.0/abi/ERC1155AutoGraphMinter.abi.json)     |
| [`0x5422a3De80BA3891d663fa4EC7506A7f263c1Fd9`](https://sepolia-explorer.arbitrum.io/address/0x5422a3De80BA3891d663fa4EC7506A7f263c1Fd9) | [TOKEN](./src/token/Token.sol)                                                     | [Token.abi.json](./dist/v1.0.0/abi/Token.abi.json)                                       |
| [`0xf052f3F94f6E71DfBA39544b8DF02c873De4469F`](https://sepolia-explorer.arbitrum.io/address/0xf052f3F94f6E71DfBA39544b8DF02c873De4469F) | [GAME_CONSUMABLE](./src/game/GameConsumer.sol)                                     | [GameConsumer.abi.json](./dist/v1.0.0/abi/GameConsumer.abi.json)                         |

### Arbitrum Sepolia (qa)

| Address                                                                                                                | Contract                                                                                                                                    | ABI                                                                                      |
|------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| [`0xeCd8CF66C8F44D8Ab0f257C2aC5220A943D8d8eE`](https://sepolia.arbiscan.io/address/0xeCd8CF66C8F44D8Ab0f257C2aC5220A943D8d8eE) | [CORE](./src/core/Core.sol)                                                                                                                 | [Core.abi.json](./dist/v1.0.0/abi/Core.abi.json)                                         |
| [`0x4FCAaCfed2E0F5A4fdbfE01EBe50748Cdc06CBB6`](https://sepolia.arbiscan.io/address/0x4FCAaCfed2E0F5A4fdbfE01EBe50748Cdc06CBB6) | [GLOBAL_REENTRANCY_LOCK](./src/utils/GlobalReentrancyLock.sol)                                                                              | [GlobalReentrancyLock.abi.json](./dist/v1.0.0/abi/GlobalReentrancyLock.abi.json)         |
| [`0x350aCe500A712D944Fb6De1D54C63340a5085b6f`](https://sepolia.arbiscan.io/address/0x350aCe500A712D944Fb6De1D54C63340a5085b6f) | [ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES](./src/nfts/ERC1155MaxSupplyMintable.sol)                                                            | [ERC1155MaxSupplyMintable.abi.json](./dist/v1.0.0/abi/ERC1155MaxSupplyMintable.abi.json) |
| [`0x95C68D9E3c0353a0CDd40000Cd1A06A87ED14744`](https://sepolia.arbiscan.io/address/0x95C68D9E3c0353a0CDd40000Cd1A06A87ED14744) | [ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES](./src/nfts/ERC1155MaxSupplyMintable.sol)                                                          | [ERC1155MaxSupplyMintable.abi.json](./dist/v1.0.0/abi/ERC1155MaxSupplyMintable.abi.json) |
| [`0x425Cdf97Cc3833B6C47c2EE708aE65dC19e7494f`](https://sepolia.arbiscan.io/address/0x425Cdf97Cc3833B6C47c2EE708aE65dC19e7494f) | [ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES](./src/nfts/ERC1155MaxSupplyMintable.sol)                                                           | [ERC1155MaxSupplyMintable.abi.json](./dist/v1.0.0/abi/ERC1155MaxSupplyMintable.abi.json) |
| [`0x11af076f2a418B7627b5Fb3eE2e17ebC4543f94d`](https://sepolia.arbiscan.io/address/0x11af076f2a418B7627b5Fb3eE2e17ebC4543f94d) | [SEASONS_TOKEN_ID_REGISTRY](./src/nfts/seasons/SeasonsTokenIdRegistry.sol)                                                                  | [SeasonsTokenIdRegistry.abi.json](./dist/v1.0.0/abi/SeasonsTokenIdRegistry.abi.json)     |
| [`0x14d9548b384dfd5612c5E421584645aE9a3eef38`](https://sepolia.arbiscan.io/address/0x14d9548b384dfd5612c5E421584645aE9a3eef38) | [ERC1155_SEASON_ONE](./src/nfts/seasons/ERC1155SeasonOne.sol)                                                                               | [ERC1155SeasonOne.abi.json](./dist/v1.0.0/abi/ERC1155SeasonOne.abi.json)                 |
| [`0xb0Cb1448b40789302D371CdAC2881D2570DE1CAc`](https://sepolia.arbiscan.io/address/0xb0Cb1448b40789302D371CdAC2881D2570DE1CAc) | [ERC1155_MAX_SUPPLY_ADMIN_MINTER](./src/nfts/ERC1155AdminMinter.sol)                                                                      | [ERC1155AdminMinter.abi.json](./dist/v1.0.0/abi/ERC1155AdminMinter.abi.json)             |
| [`0xd22040ACd20623c6ee507e8985a3FfdE7a270A63`](https://sepolia.arbiscan.io/address/0xd22040ACd20623c6ee507e8985a3FfdE7a270A63) | [ERC1155_AUTO_GRAPH_MINTER](./src/nfts/ERC1155AutoGraphMinter.sol)                                                                          | [ERC1155AutoGraphMinter.abi.json](./dist/v1.0.0/abi/ERC1155AutoGraphMinter.abi.json)     |
| [`0xfD1B439A292C3690FF5f052Df907Ae7817696537`](https://sepolia.arbiscan.io/address/0xfD1B439A292C3690FF5f052Df907Ae7817696537) | [TOKEN](./src/token/Token.sol)                                                                                                              | [Token.abi.json](./dist/v1.0.0/abi/Token.abi.json)                                       |
| [`0xede3f2c44a7cfF1292eAA72Fe828862B0a334317`](https://sepolia.arbiscan.io/address/0xede3f2c44a7cfF1292eAA72Fe828862B0a334317) | [GAME_CONSUMABLE](./src/game/GameConsumer.sol)                                                                                              | [GameConsumer.abi.json](./dist/v1.0.0/abi/GameConsumer.abi.json)                         |
| [`0xB6DE3d51297124030371B5ff6009f5A117EFd8b5`](https://sepolia.arbiscan.io/address/0xB6DE3d51297124030371B5ff6009f5A117EFd8b5) | [CONSUMABLE_SPLITTER](./src/finance/ERC20Splitter.sol)                                                                                      | [ERC20Splitter.abi.json](./dist/v1.0.0/abi/ERC20Splitter.abi.json)                       |
| [`0x8e5961897d0E1Db128a972c0937Eb08fa9a16C2C`](https://sepolia.arbiscan.io/address/0x8e5961897d0E1Db128a972c0937Eb08fa9a16C2C) | [ADMIN_TIMELOCK_CONTROLLER](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol) | [TimelockController.abi.json](./dist/v1.0.0/abi/TimelockController.abi.json)             | 

### Arbitrum (mainnet)

| Address                                                                                                                | Contract                                                                                                                                    | ABI                                                                                      |
|------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| [`0xb2F009749260ddbEFe5E1687895f0A0E411613EA`](https://arbiscan.io/address/0xb2F009749260ddbEFe5E1687895f0A0E411613EA) | [CORE](./src/core/Core.sol)                                                                                                                 | [Core.abi.json](./dist/v1.0.0/abi/Core.abi.json)                                         |
| [`0x90eAa68fAe4703ff5328f2E86982e77EBc10539a`](https://arbiscan.io/address/0x90eAa68fAe4703ff5328f2E86982e77EBc10539a) | [GLOBAL_REENTRANCY_LOCK](./src/utils/GlobalReentrancyLock.sol)                                                                              | [GlobalReentrancyLock.abi.json](./dist/v1.0.0/abi/GlobalReentrancyLock.abi.json)         |
| [`0x792E36c772f6dA6280fa43159792F89e7444CF18`](https://arbiscan.io/address/0x792E36c772f6dA6280fa43159792F89e7444CF18) | [ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES](./src/nfts/ERC1155MaxSupplyMintable.sol)                                                            | [ERC1155MaxSupplyMintable.abi.json](./dist/v1.0.0/abi/ERC1155MaxSupplyMintable.abi.json) |
| [`0x163b2E7696F661F86DBB39Ce4b03e38Bfe22a1C9`](https://arbiscan.io/address/0x163b2E7696F661F86DBB39Ce4b03e38Bfe22a1C9) | [ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES](./src/nfts/ERC1155MaxSupplyMintable.sol)                                                          | [ERC1155MaxSupplyMintable.abi.json](./dist/v1.0.0/abi/ERC1155MaxSupplyMintable.abi.json) |
| [`0x2C154Ae907652A1a9939DBe0622915111816942C`](https://arbiscan.io/address/0x2C154Ae907652A1a9939DBe0622915111816942C) | [ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES](./src/nfts/ERC1155MaxSupplyMintable.sol)                                                           | [ERC1155MaxSupplyMintable.abi.json](./dist/v1.0.0/abi/ERC1155MaxSupplyMintable.abi.json) |
| [`0x5cb7431a545523F25AbD3948c648329636a4b1E5`](https://arbiscan.io/address/0x5cb7431a545523F25AbD3948c648329636a4b1E5) | [SEASONS_TOKEN_ID_REGISTRY](./src/nfts/seasons/SeasonsTokenIdRegistry.sol)                                                                  | [SeasonsTokenIdRegistry.abi.json](./dist/v1.0.0/abi/SeasonsTokenIdRegistry.abi.json)     |
| [`0x59AFA38214C9CCCFB56f72DE7f9a2B47fA17C270`](https://arbiscan.io/address/0x59AFA38214C9CCCFB56f72DE7f9a2B47fA17C270) | [ERC1155_SEASON_ONE](./src/nfts/seasons/ERC1155SeasonOne.sol)                                                                               | [ERC1155SeasonOne.abi.json](./dist/v1.0.0/abi/ERC1155SeasonOne.abi.json)                 |
| [`0xd778a415A3AB81eF27da61218c71a5F31A4D10BE`](https://arbiscan.io/address/0xd778a415A3AB81eF27da61218c71a5F31A4D10BE) | [ERC1155_MAX_SUPPLY_ADMIN_MINTER](./src/nfts/ERC1155AdminMinter.sol)                                                                      | [ERC1155AdminMinter.abi.json](./dist/v1.0.0/abi/ERC1155AdminMinter.abi.json)             |
| [`0xD031aD02aD4bADFc06b64ec64eBA32cFc781FB9b`](https://arbiscan.io/address/0xD031aD02aD4bADFc06b64ec64eBA32cFc781FB9b) | [ERC1155_AUTO_GRAPH_MINTER](./src/nfts/ERC1155AutoGraphMinter.sol)                                                                          | [ERC1155AutoGraphMinter.abi.json](./dist/v1.0.0/abi/ERC1155AutoGraphMinter.abi.json)     |
| [`0x1C43D05be7E5b54D506e3DdB6f0305e8A66CD04e`](https://arbiscan.io/address/0x1C43D05be7E5b54D506e3DdB6f0305e8A66CD04e) | [TOKEN](./src/token/Token.sol)                                                                                                              | [Token.abi.json](./dist/v1.0.0/abi/Token.abi.json)                                       |
| [`0xeD3ed10Bd8FD4093528B38B6fD7c5a5C616EB28f`](https://arbiscan.io/address/0xeD3ed10Bd8FD4093528B38B6fD7c5a5C616EB28f) | [GAME_CONSUMABLE](./src/game/GameConsumer.sol)                                                                                              | [GameConsumer.abi.json](./dist/v1.0.0/abi/GameConsumer.abi.json)                         |
| [`0x85454964Db79620e239C5425F047eAAe027d0E08`](https://arbiscan.io/address/0x85454964Db79620e239C5425F047eAAe027d0E08) | [CONSUMABLE_SPLITTER](./src/finance/ERC20Splitter.sol)                                                                                      | [ERC20Splitter.abi.json](./dist/v1.0.0/abi/ERC20Splitter.abi.json)                       |
| [`0xf16A0E806A4CF6e9031A0dA028c80eF8A771aE48`](https://arbiscan.io/address/0xf16A0E806A4CF6e9031A0dA028c80eF8A771aE48) | [ADMIN_TIMELOCK_CONTROLLER](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol) | [TimelockController.abi.json](./dist/v1.0.0/abi/TimelockController.abi.json)             | 
