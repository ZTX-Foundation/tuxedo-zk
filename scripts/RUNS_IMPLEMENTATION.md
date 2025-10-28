# Deployment Runs Implementation

## Overview

This implementation provides a resumable deployment system that tracks deployment state across proposals and allows resuming from failures.

## File Structure

```
deployments/
  {chainId}/
    deployment-latest.json      # Points to latest run
    deployment-{timestamp}.json # Run files
```

## Run File Format

```json
{
  "createdAt": 1730123456789,
  "lastCompletedProposal": 1,
  "deployedAddresses": [
    {
      "addr": "0x1234...",
      "name": "TOKEN",
      "chainId": 4654,
      "isContract": true
    },
    {
      "addr": "0x5678...",
      "name": "CORE",
      "chainId": 4654,
      "isContract": true
    }
  ]
}
```

## Implementation Details

### CLI Tool (`scripts/deploy.ts`)

**New/Resume Flow:**
1. Select network → determines chainId
2. Choose "New run" or "Resume run"
3. If resuming:
   - Lists all runs sorted by date (newest first)
   - Shows format: "HH:mm MM/dd/yyyy - Last completed: zipXXX"
   - Automatically starts from next proposal after last completed

**Environment Variables Set:**
- `RUN_ID`: The run timestamp
- `RUN_FILE_PATH`: Absolute path to the run JSON file
- `ENVIRONMENT`: Network name (creator-testnet, localnet, etc.)

**After Each Proposal:**
- Calls `runManager.markProposalCompleted(proposalIndex)`
- This updates `lastCompletedProposal` in the run file

### RunManager (`scripts/RunManager.ts`)

**Design**: Stateless - always reads from file, never caches run state internally.

**Methods:**
- `constructor(chainId, runId?)` - Create new or reference existing run file
- `getNextProposalIndex()` - Reads file, returns `lastCompletedProposal + 1`
- `markProposalCompleted(index)` - Reads file, updates only `lastCompletedProposal`, writes back
- `getRunFilePath()` - Returns absolute path for env var
- `static listRuns(chainId)` - Lists all runs for a network
- `static getLatestRunId(chainId)` - Gets latest run from deployment-latest.json

**Note**: Does NOT manage `deployedAddresses` - that's handled entirely by Proposal.sol

### Proposal.sol

**setUp() Function:**
1. Loads base addresses from `proposals/Addresses/{environment}.json`
2. Checks for `RUN_FILE_PATH` env var
3. If present, calls `_loadRunAddresses()` to load previously deployed contracts

**run() Function:**
After `deploy()` completes:
1. Checks for `RUN_FILE_PATH` env var
2. If present, calls `_saveAddressesToRunFile()` to append new addresses

**_loadRunAddresses():**
- Reads run file
- Parses `.deployedAddresses` array
- Calls `addresses.addAddress()` for each

**_saveAddressesToRunFile():**
- Gets newly deployed addresses via `addresses.getRecordedAddresses()`
- Reads existing run file
- Merges existing + new addresses
- Rebuilds JSON and writes back
- Preserves `createdAt` and `lastCompletedProposal` fields

## Usage

### Start New Deployment

```bash
npm run deploy
# Select: creator-testnet
# Select: New run
# Enter private key or skip
```

Creates: `deployments/4654/deployment-{timestamp}.json`

### Resume Deployment

```bash
npm run deploy
# Select: creator-testnet
# Select: Resume run
# Choose run from list
# Enter private key or skip
```

Continues from `lastCompletedProposal + 1`

### Resume Latest

If `deployment-latest.json` exists, you can programmatically resume:

```typescript
const latestRunId = RunManager.getLatestRunId(chainId);
const runManager = new RunManager(chainId, latestRunId);
```

## Resumability

**Automatic Resume Points:**
- After each proposal completes successfully, `lastCompletedProposal` increments
- On resume, starts from next proposal automatically
- All previously deployed addresses are loaded into the Addresses contract
- Each proposal can reference previous deployments (e.g., zip002 getting CORE from zip001)

**Adding New Proposals:**
1. Add new zipXXX.sol file
2. Resume latest run
3. System detects new proposals after `lastCompletedProposal`
4. Deploys only new ones

**Failure Handling:**
- If a proposal fails, `lastCompletedProposal` doesn't increment
- On resume, retries the failed proposal
- Previously deployed addresses from earlier proposals are preserved

## Chain ID Mapping

```typescript
const NETWORKS = {
  "creator-testnet": { chainId: 4654, ... },
  "localnet": { chainId: 31337, ... },
  "mainnet": { chainId: 42161, ... },
  "qa": { chainId: 99999, ... }
}
```

Update QA chain ID when known.

## Testing

1. **Test new run:**
   ```bash
   npm run deploy
   # Select creator-testnet → New run → No private key
   # Should create deployment-{timestamp}.json with lastCompletedProposal: -1
   ```

2. **Test resume:**
   ```bash
   # After partial deployment
   npm run deploy
   # Select creator-testnet → Resume run → Select latest
   # Should continue from correct proposal
   ```

3. **Test address persistence:**
   - Deploy zip000 and zip001
   - Resume and deploy zip002
   - Verify zip002 can access CORE address from zip001

## Notes

- Run files are never deleted (provides full deployment history)
- `deployment-latest.json` always points to most recent run
- Dates formatted with date-fns: `format(date, 'HH:mm MM/dd/yyyy')`
- All addresses have `isContract: true` when saved from proposals
