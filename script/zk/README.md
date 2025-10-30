# Deployment CLI

Interactive CLI for deploying ZTX contracts with run tracking and governance workflow support.

## Setup

Install dependencies:

```bash
npm install
```

Create a `.env` file with your deployer private key, refer to [the env example](../../.env.example)

```bash
DEPLOYER_PRIVATE_KEY=0x...
```

Private key must start with `0x` and be 66 characters long.

## Usage

```bash
npm run deploy
```

## Workflow

### 1. Select Network

- Creator Testnet (Chain ID: 4654)
- Local Network (Chain ID: 31337)
- Mainnet (Chain ID: 42161)
- QA Network (Chain ID: 99999)

### 2. Choose Run Type

Start a new deployment or resume a previous one. When resuming, select from available runs showing the last completed proposal.

### 3. Deploy Mode

- **Simulate** - Dry run without broadcasting
- **Broadcast** - Live deployment using `DEPLOYER_PRIVATE_KEY`

### 4. Governance Workflow

Proposals zip003-zip021 (excluding zip015) require governance submission. For these proposals, the CLI will:

1. Deploy contracts via `deploy()`
2. Generate governance calldata via `build()`
3. Display calldata with submission instructions
4. Pause for manual submission confirmation

To submit governance actions:
1. Copy the Schedule Calldata
2. Call `scheduleBatch()` on TimelockController from ADMIN_MULTISIG
3. Wait for timelock delay
4. Call `executeBatch()` on TimelockController
5. Confirm in CLI to continue

Deployments can be paused at governance checkpoints and resumed later.

## Run Files

Deployment state is tracked in `deployments/{chainId}/{timestamp}-{nanoid}.json`:

```json
{
  "createdAt": 1706627130000,
  "lastCompletedProposal": 3,
  "deployedAddresses": [...]
}
```

Resume deployments after:
- Manual governance submission
- Deployment failures
- Interruptions (Ctrl+C)

## Network Configuration

Edit `script/zk/deploy.ts`:

```typescript
const NETWORKS = {
  'creator-testnet': {
    name: 'Creator Testnet',
    rpcUrl: 'https://creator-testnet.rpc.caldera.xyz/http',
    chainId: 4654,
  },
}
```

Add new networks:
1. Update `NETWORKS` in `script/zk/deploy.ts`
2. Create `proposals/Addresses/{network-name}.json`

## Examples

Simulate deployment:
```bash
npm run deploy
# Creator Testnet -> New run -> Simulate
```

Live deployment with governance:
```bash
npm run deploy
# Creator Testnet -> New run -> Broadcast
# Submit governance actions when prompted
```

Resume paused deployment:
```bash
npm run deploy
# Creator Testnet -> Resume run -> Select run -> Broadcast
```

## Troubleshooting

**Missing DEPLOYER_PRIVATE_KEY**

Create `.env` with `DEPLOYER_PRIVATE_KEY=0x...` (66 characters).

**Ctrl+C during forge execution**

SIGINT handler exits gracefully but cannot interrupt forge mid-execution.

**Run file not found**

Check `deployments/{chainId}/` exists. Start new run if data is lost.

**Script logs "Script ran successfully" but transactions fail**

Addresses are saved to the run file before transactions broadcast. If broadcast fails after address logging, the run file contains addresses but `lastCompletedProposal` doesn't increment. Re-running attempts to deploy the same contracts, causing address conflicts.

Fix:
1. Check if addresses were actually deployed on-chain
2. If deployed: Manually increment `lastCompletedProposal` in the run file
3. If not deployed: Remove the addresses from `deployedAddresses` array in run file, or start a new run

## Local zkSync Node Testing

To test deployments against a local zkSync node:

**1. Start the zkSync node**

```bash
npx zksync-cli dev start
```

**2. Fund your deployer wallet**

```bash
cast send {address} \
    --value 100ether \
    --private-key {private_key} \
    --rpc-url http://127.0.0.1:8011
```

Replace `{address}` with your deployer address and `{private_key}` with a funded account from the zkSync node.

**3. Run the CLI**

```bash
npm run deploy
# Select: localnet-zk
```

The zkSync local node runs on port 8011 by default with chain ID 260.

## Architecture

**Two-Phase Deployment**

Phase 1: Deploy contracts
- Executes `deploy()` methods
- Broadcasts to network
- Tracks deployed addresses

Phase 2: Governance actions
- Generates calldata via `build()`
- Pauses for manual TimelockController submission
- Resumes after confirmation

This ensures contracts deploy immediately while governance actions go through proper timelock.

## Related Documentation

- [Proposals README](../../proposals/README.md)
- [Proposal Governance Analysis](../../PROPOSAL_GOVERNANCE_ANALYSIS.md)
