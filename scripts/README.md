# Deployment CLI Tool

Interactive CLI tool for deploying ZTX contracts using Clack prompts.

## Installation

First, install the dependencies:

```bash
npm install
```

## Usage

Run the deployment CLI:

```bash
npm run deploy
```

## Interactive Steps

The CLI will guide you through the following steps:

### 1. Select Network

Choose from available networks:
- **Creator Testnet** - `https://creator-testnet.rpc.caldera.xyz/http`
- **Local Network** - `http://127.0.0.1:8545`
- **Mainnet** - `https://arb1.arbitrum.io/rpc`
- **QA Network** - `https://qa.rpc.caldera.xyz/http`

Networks are automatically detected from the `proposals/Addresses/` directory.

### 2. Select Proposals

Choose which proposals to deploy:
- **All proposals** - Deploy all available zip files
- **Select specific proposals** - Choose individual proposals (zip000, zip001, etc.)

### 3. Optional Private Key

If you want to broadcast transactions:
- Provide a private key (must start with `0x` and be 66 characters)
- This will add `--broadcast` and `--private-key` flags to the forge command

If you skip this step, the deployment will simulate only (no broadcasting).

### 4. Deployment Summary & Confirmation

Review the deployment configuration:
- Network name and RPC URL
- Selected proposals
- Broadcasting status

Confirm to proceed with deployment.

## Command Structure

The CLI builds and executes forge script commands with the following structure:

```bash
forge script proposals/zips/{proposal}.sol \
  --rpc-url {rpcUrl} \
  --zksync \
  -vvvv \
  [--broadcast --private-key {privateKey}]
```

## Features

- ✅ Interactive network selection with RPC URL hints
- ✅ Multi-select proposals or deploy all
- ✅ Optional private key for broadcasting
- ✅ Deployment progress tracking with spinners
- ✅ Error handling with option to continue on failure
- ✅ Clear deployment summary before execution
- ✅ Automatically detects available proposals from filesystem

## Network Configuration

Networks are configured in `scripts/deploy.ts`:

```typescript
const NETWORKS = {
  'creator-testnet': {
    name: 'Creator Testnet',
    rpcUrl: 'https://creator-testnet.rpc.caldera.xyz/http',
  },
  // ... other networks
}
```

To add a new network:
1. Add the network configuration to the `NETWORKS` object
2. Create a corresponding JSON file in `proposals/Addresses/`

## Examples

### Deploy all proposals to Creator Testnet (simulation only)

```bash
npm run deploy
# Select: Creator Testnet
# Select: All proposals
# Select: No (for private key)
```

### Deploy specific proposals with broadcasting

```bash
npm run deploy
# Select: Creator Testnet
# Select: Select specific proposals
# Choose: zip000, zip001, zip002
# Select: Yes (for private key)
# Enter: 0x...
```

## Troubleshooting

### Missing dependencies

If you see import errors, install dependencies:

```bash
npm install
```

### Command not found

Make sure you're running from the project root:

```bash
cd /path/to/creator-chain
npm run deploy
```

### Forge errors

Ensure Foundry is installed and up to date:

```bash
foundryup
```
