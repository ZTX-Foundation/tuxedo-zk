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

- Creator Testnet (QA) (Chain ID: 278701)
- Creator Mainnet (Chain ID: 2787)
- Local Network ZK (Chain ID: 260)

### 2. Choose Run Type

Start a new deployment or resume a previous one. When resuming, select from available runs showing the last completed proposal.

### 3. Governance Workflow

Certain proposals require governance submission (see PROPOSALS_WITH_BUILD in deploy.ts). For these proposals, the CLI will:

1. Deploy contracts and execute `deploy()`
2. Generate governance calldata via `build()`
3. Display "Schedule Calldata" and "Execute Calldata" sections
4. Pause and prompt for confirmation

To submit governance actions:
1. Scroll up to find the Schedule Calldata and Execute Calldata sections
2. Copy the transactions and submit them via the multisig to the TimelockController
3. Wait for timelock delay and execute the batch
4. Confirm in CLI to continue

Deployments can be paused at governance checkpoints and resumed later.

## Run Files

Deployment state is tracked in `deployments/{chainId}/deployment-{timestamp}.json`:

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
  'qa': {
    name: 'Creator Testnet (QA)',
    rpcUrl: 'https://rpc.testnet.oncreator.com',
    chainId: 278701,
  },
  'mainnet': {
    name: 'Creator Mainnet',
    rpcUrl: 'https://rpc.mainnet.oncreator.com',
    chainId: 2787,
  },
  'localnet-zk': {
    name: 'Local Network ZK',
    rpcUrl: 'http://127.0.0.1:8011',
    chainId: 260,
  },
}
```

Add new networks:
1. Update `NETWORKS` in `script/zk/deploy.ts`
2. Create `proposals/Addresses/{network-name}.json`

## Examples

Start new deployment:
```bash
npm run deploy
# Creator Testnet (QA) -> New run
# Submit governance actions when prompted
```

Resume paused deployment:
```bash
npm run deploy
# Creator Testnet (QA) -> Resume run -> Select run
```

Deploy to local zkSync node:
```bash
npm run deploy
# Local Network ZK -> New run
```

## Troubleshooting

**Missing DEPLOYER_PRIVATE_KEY**

Create `.env` with `DEPLOYER_PRIVATE_KEY=0x...` (66 characters).

**Ctrl+C during forge execution**

SIGINT handler exits gracefully but cannot interrupt forge mid-execution.

**Run file not found**

Check `deployments/{chainId}/` exists. Start new run if data is lost.

**Deployment fails but addresses are saved**

Addresses may be saved to the run file before transactions complete. If the deployment fails after addresses are logged, the run file contains addresses but `lastCompletedProposal` doesn't increment. Re-running attempts to deploy the same contracts, causing address conflicts.

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

The deployment process consists of two phases:

**Phase 1: Deploy contracts**
- Executes `deploy()` methods from each proposal script
- Broadcasts transactions to the network using `forge script --broadcast`
- Tracks deployed addresses in the run file

**Phase 2: Governance actions (for applicable proposals)**
- Automatically generates governance calldata via `build()`
- Displays Schedule and Execute calldata for TimelockController
- Pauses for manual multisig submission and confirmation
- Resumes after user confirms execution

This ensures contracts deploy immediately while governance actions go through proper timelock procedures.

## Related Documentation

- [Proposals README](../../proposals/README.md)
- [Proposal Governance Analysis](../../PROPOSAL_GOVERNANCE_ANALYSIS.md)
