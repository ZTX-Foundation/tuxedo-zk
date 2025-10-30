# ZIP Proposals Analysis Report

## 1. Dependency Analysis: Build() to Deploy() Dependencies

### Summary
**NO CRITICAL DEPENDENCIES FOUND** - You can safely run all deploy() methods to testnet first, then export and process all governance actions at once.

### Detailed Analysis

#### ZIP000 (MultisigProposal)
- **File**: `proposals/zips/zip000.sol`
- **Has build()**: No
- **Dependency Risk**: None - Simple token deployment and transfer

#### ZIP001 (MultisigProposal)
- **File**: `proposals/zips/zip001.sol`
- **Has build()**: No
- **deploy()**: Lines 28-71 - Deploys Core, GlobalReentrancyLock, NFT contracts, grants roles
- **Important**: All role grants happen in deploy(), not build()
- **Dependency Risk**: None

#### ZIP002 (MultisigProposal)
- **File**: `proposals/zips/zip002.sol`
- **Has build()**: No
- **deploy()**: Lines 30-51 - Deploys TimelockController
- **Note**: Line 46 grants ADMIN role on testnet only (not mainnet)
- **Dependency Risk**: None

#### ZIP003 (TimelockProposal)
- **File**: `proposals/zips/zip003.sol`
- **deploy()**: Lines 31-111 - Deploys multiple contracts
- **build()**: Lines 113-133 - Grants roles through timelock
  - GUARDIAN role to GUARDIAN_MULTISIG (line 115)
  - LOCKER_PROTOCOL_ROLE to new contracts (lines 118-120)
  - MINTER_PROTOCOL_ROLE (line 123)
  - REGISTRY_OPERATOR_PROTOCOL_ROLE (line 126)
  - MINTER_NOTARY_PROTOCOL_ROLE (line 129)
  - GAME_CONSUMER_NOTARY_PROTOCOL_ROLE (line 132)
- **Dependency Check**: Line 33 asserts timelock has ADMIN role
- **Dependency Risk**: **LOW** - Only depends on ZIP002's timelock deployment and manual ADMIN role grant (which must happen between ZIP002 and ZIP003)

#### ZIP004-021 (All TimelockProposals)
- **Files**: `proposals/zips/zip004.sol` through `zip021.sol`
- **deploy()**: Empty/No new contracts
- **build()**: All use `buildModifier(addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER"))`
- **Operations**: Only supply cap settings via `setSupplyCap()`
- **Dependency Risk**: **NONE** - All proposals are independent configuration changes

### Conclusion
You can safely:
1. Run all deploy() methods on testnet
2. Export all governance actions from build() methods
3. Process them in batch or sequentially

**Exception**: ZIP003 requires that ADMIN_TIMELOCK_CONTROLLER has the ADMIN role on Core before its build() executes (line 33 assertion). This manual step must be done after ZIP002.

---

## 2. Build Modifier Analysis

### Summary
**ALL build() methods use the same modifier** - They all intend transactions to be sent from ADMIN_TIMELOCK_CONTROLLER.

### Detailed Findings

| ZIP | Has build() | Modifier Address | Line Reference |
|-----|-------------|------------------|----------------|
| ZIP000 | No | N/A | N/A |
| ZIP001 | No | N/A | N/A |
| ZIP002 | No | N/A | N/A |
| ZIP003 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 113 |
| ZIP004 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 207 |
| ZIP005 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 140 |
| ZIP006 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 57 |
| ZIP007 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 57 |
| ZIP008 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 57 |
| ZIP009 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 57 |
| ZIP010 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 57 |
| ZIP011 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 65 |
| ZIP012 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 55 |
| ZIP013 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 65 |
| ZIP014 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 55 |
| ZIP016 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 55 |
| ZIP017 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 65 |
| ZIP018 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 94 |
| ZIP019 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 62 |
| ZIP020 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 94 |
| ZIP021 | Yes | `addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")` | Line 65 |

### Conclusion
**100% consistency** - All proposals with build() methods use `ADMIN_TIMELOCK_CONTROLLER` as the transaction sender.

---

## 3. Build Method Operations Summary

### Role Grants (ZIP003 only)
**File**: `proposals/zips/zip003.sol` (Lines 113-133)

| Role | Granted To | Line |
|------|------------|------|
| GUARDIAN | GUARDIAN_MULTISIG | 115 |
| LOCKER_PROTOCOL_ROLE | ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES | 118 |
| LOCKER_PROTOCOL_ROLE | ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES | 119 |
| LOCKER_PROTOCOL_ROLE | ERC1155_AUTO_GRAPH_MINTER | 120 |
| MINTER_PROTOCOL_ROLE | ERC1155_AUTO_GRAPH_MINTER | 123 |
| REGISTRY_OPERATOR_PROTOCOL_ROLE | ERC1155_SEASON_ONE | 126 |
| MINTER_NOTARY_PROTOCOL_ROLE | AUTOGRAPH_SERVICE_KMS_WALLET | 129 |
| GAME_CONSUMER_NOTARY_PROTOCOL_ROLE | AUTOGRAPH_SERVICE_KMS_WALLET | 132 |

**Total Role Operations**: 8 role grants in 1 proposal

### Supply Cap Settings (ZIP004-021)

#### By Proposal:

| ZIP | NFT Type | Operations Count | File Line Reference |
|-----|----------|------------------|---------------------|
| ZIP004 | Placeables | 80 | Lines 213-215 |
| ZIP004 | Wearables | 11 | Lines 222-224 |
| ZIP004 | Consumables | 3 | Lines 231-233 |
| ZIP004 | **Subtotal** | **94** | |
| ZIP005 | Placeables | 92 | Lines 144-146 |
| ZIP006 | Wearables | 25 | Lines 61-63 |
| ZIP007 | Wearables | 1 | Lines 61-63 |
| ZIP008 | Wearables | 24 | Lines 61-63 |
| ZIP009 | Wearables | 2 | Lines 61-63 |
| ZIP010 | Placeables | 1 | Line 61 |
| ZIP011 | Wearables | 12 | Lines 69-71 |
| ZIP012 | Wearables | 1 | Line 61 |
| ZIP013 | Wearables | 2 | Lines 71-73 |
| ZIP014 | Wearables | 1 | Line 61 |
| ZIP016 | Wearables | 1 | Line 61 |
| ZIP017 | Wearables | 15 | Lines 71-73 |
| ZIP018 | Placeables | 24 | Lines 97-99 |
| ZIP018 | Wearables | 5 | Lines 102-104 |
| ZIP019 | Wearables | 27 | Lines 67-69 |
| ZIP020 | Placeables | 155 | Lines 97-99 |
| ZIP020 | Wearables | 23 | Lines 102-104 |
| ZIP021 | Wearables | 29 | Lines 71-73 |
| **TOTAL** | | **535** | |

**Operation Type**: All use `ERC1155MaxSupplyMintable.setSupplyCap(tokenId, maxSupply)`

### Season/Registry Initialization (ZIP004 only)
**File**: `proposals/zips/zip004.sol` (Line 237)

| Operation | Contract | Line |
|-----------|----------|------|
| Initialize Season Distribution | ERC1155_SEASON_ONE | 237 |

**Details**: Initializes 3 token ID reward amounts for Season One

### Summary by Category:

1. **Role Grants**: 8 operations (1 proposal)
2. **Supply Cap Settings**: 535 operations (18 proposals)
3. **Season Initialization**: 1 operation (1 proposal)

**Total Governance Operations**: 544 across 19 proposals with build() methods

---

## 4. Governance Execution Documentation

### A. Core Proposal Framework Files

#### TimelockProposal.sol
**File**: `lib/forge-proposal-simulator/src/proposals/TimelockProposal.sol`

**Key Functions**:

1. **getCalldata()** (Lines 26-51)
   - Returns schedule calldata for TimelockController
   - Encodes: `scheduleBatch(address[],uint256[],bytes[],bytes32,bytes32,uint256)`
   - Uses salt from `keccak256(abi.encode(description()))`
   - Gets minimum delay from timelock

2. **getExecuteCalldata()** (Lines 54-75)
   - Returns execute calldata for TimelockController
   - Encodes: `executeBatch(address[],uint256[],bytes[],bytes32,bytes32)`
   - Uses same salt as schedule

3. **print()** (Lines 183-204)
   - Prints proposal description
   - Prints all proposal actions
   - Logs schedule calldata (line 198)
   - Logs execute calldata (line 203)

4. **_simulateActions()** (Lines 114-180)
   - Simulates the full timelock flow
   - Schedule → Wait for delay → Execute
   - Used in test/simulation mode

#### Proposal.sol (Base Class)
**File**: `lib/forge-proposal-simulator/src/proposals/Proposal.sol`

**Key Functions**:
- **getProposalActions()**: Returns arrays of targets, values, and payloads
- **buildModifier**: Captures actions during build() execution

### B. Example Usage: DeployProposal Script

**File**: `script/deploy/DeployProposal.s.sol`

```solidity
// Lines 32-35
function run() public {
    /// Run the proposal workflow
    newProposal.run();
}
```

**Usage Command** (Lines 11-16):
```bash
forge script script/deploy/DeployProposal.s.sol:DeployProposal \
    -vvvv \
    --rpc-url $ETH_RPC_URL \
    --broadcast
```

### C. Documentation Files

#### Proposals README
**File**: `proposals/README.md`

**Key Sections**:

1. **DeployProposal Script** (Lines 26-37)
   - Deploys latest zip to mainnet
   - Logs proposal calldata for admin timelock controller
   - Commands:
     - `npm run deploy:testnet:broadcast` - Deploy with gas
     - `npm run deploy:testnet` - Try locally first

2. **Integration Tests** (Lines 5-22)
   - Test proposals before execution
   - Environment: mainnet/qa/devnet/localnet
   - Command: `ENVIRONMENT=mainnet npm run test:integration`

### D. Workflow to Execute Governance Actions

Based on the codebase analysis:

#### Step 1: Deploy New Contracts
```bash
# Set environment (mainnet/testnet/devnet)
export ENVIRONMENT=testnet

# Run deploy script (this calls deploy() method)
forge script script/deploy/DeployProposal.s.sol:DeployProposal \
    --rpc-url $TESTNET_RPC_URL \
    --broadcast
```

#### Step 2: Export Proposal Actions

The `run()` method in each ZIP file:
- Calls `super.run()` which executes the full workflow
- With `DO_PRINT=true`, the `print()` function outputs calldata

**From TimelockProposal.sol lines 183-204**, the print() function logs:
1. Proposal description
2. All actions with targets and payloads
3. **Schedule calldata** (for scheduleBatch)
4. **Execute calldata** (for executeBatch)

To export calldata:
```bash
# Run with printing enabled
DO_PRINT=true forge script script/deploy/DeployProposal.s.sol:DeployProposal \
    --rpc-url $TESTNET_RPC_URL \
    > proposal_calldata.txt
```

#### Step 3: Schedule in TimelockController

Using the schedule calldata from step 2:

```solidity
// From ADMIN_MULTISIG (has PROPOSER_ROLE)
TimelockController(ADMIN_TIMELOCK_CONTROLLER).scheduleBatch(
    targets,      // From getProposalActions()
    values,       // From getProposalActions()
    payloads,     // From getProposalActions()
    predecessor,  // bytes32(0)
    salt,         // keccak256(abi.encode(description()))
    delay         // timelock.getMinDelay()
);
```

#### Step 4: Wait for Delay

```solidity
// Check if ready
bool ready = timelock.isOperationReady(proposalId);
```

#### Step 5: Execute Actions

```solidity
// From ADMIN_MULTISIG (has EXECUTOR_ROLE)
TimelockController(ADMIN_TIMELOCK_CONTROLLER).executeBatch(
    targets,      // Same as schedule
    values,       // Same as schedule
    payloads,     // Same as schedule
    predecessor,  // Same as schedule (bytes32(0))
    salt          // Same as schedule
);
```

### E. Simulate Function Analysis

**From ZIP003** (lines 144-149):
```solidity
function simulate() public override {
    address multisig = addresses.getAddress("ADMIN_MULTISIG");

    /// Multisig is proposer and executor
    _simulateActions(multisig, multisig);
}
```

**_simulateActions** (TimelockProposal.sol lines 114-180):
1. Gets schedule and execute calldata
2. Calls scheduleBatch as proposer
3. Warps time forward by delay
4. Calls executeBatch as executor

This shows the full flow that happens on-chain.

### F. TimelockController Details

**From README.md** (line 124):
- Mainnet: `0xf16A0E806A4CF6e9031A0dA028c80eF8A771aE48`
- Testnet (qa): `0x8e5961897d0E1Db128a972c0937Eb08fa9a16C2C`

**Roles** (from ZIP002 validation):
- PROPOSER_ROLE: ADMIN_MULTISIG
- EXECUTOR_ROLE: ADMIN_MULTISIG
- CANCELLER_ROLE: ADMIN_MULTISIG

### G. Complete Example Flow

```bash
# 1. Deploy contracts to testnet
ENVIRONMENT=testnet forge script script/deploy/DeployProposal.s.sol:DeployProposal \
    --rpc-url $TESTNET_RPC_URL \
    --broadcast

# 2. Get calldata (run again with print enabled)
DO_PRINT=true ENVIRONMENT=testnet \
    forge script script/deploy/DeployProposal.s.sol:DeployProposal \
    --rpc-url $TESTNET_RPC_URL

# 3. Copy the logged "Schedule Calldata" from console output

# 4. Submit to timelock from multisig
# Use the calldata to call scheduleBatch on TimelockController

# 5. Wait for delay period (check with isOperationReady)

# 6. Execute using the logged "Execute Calldata"
# Call executeBatch on TimelockController
```

### H. No Built-in Export to File

**Important Finding**: The codebase does not have a built-in function to export calldata to JSON/file. The workflow relies on:
1. Console logging via `print()` function
2. Manual copying of calldata from console output
3. Using that calldata in multisig/governance UI or scripts

To automate this, you would need to add custom scripting to:
1. Call `getCalldata()` and `getExecuteCalldata()`
2. Write the bytes to a file
3. Optionally decode and format as JSON

---

## Additional Notes

### Manual Steps Required

Between ZIP002 and ZIP003, a manual governance action is required:
- **Action**: Grant ADMIN role on Core contract to ADMIN_TIMELOCK_CONTROLLER
- **Why**: ZIP003 line 33 asserts this before proceeding
- **Note**: ZIP002 only does this automatically on testnet (line 46), not mainnet

### Timelock Configuration

**From ZIP002 deployment** (lines 35-40):
- Delay: 0 (zero delay)
- Proposers: [ADMIN_MULTISIG]
- Executors: [ADMIN_MULTISIG]
- Admin: address(0) - No admin required

### Recommended Two-Phase Deployment Strategy

Based on this analysis, the recommended approach for testnet/mainnet deployments is:

#### Phase 1: Deploy All Contracts
```bash
# Run all ZIP deploy() methods sequentially
# This deploys contracts but doesn't configure them
npm run deploy
# Select: Broadcast mode
# This runs zip000-021 deploy() methods only
```

#### Phase 2: Execute Governance Actions
```bash
# For each ZIP with build() method (zip003-021):
# 1. Run locally to generate calldata
DO_BUILD=true DO_PRINT=true forge script proposals/zips/zip003.sol

# 2. Extract schedule and execute calldata from output

# 3. Submit to TimelockController via multisig
#    - Call scheduleBatch with schedule calldata
#    - Wait for delay (0 seconds on testnet)
#    - Call executeBatch with execute calldata
```

This two-phase approach:
- ✅ Separates contract deployment from configuration
- ✅ Tests the actual governance mechanism
- ✅ Mirrors the production mainnet flow
- ✅ Allows for review between deployment and configuration
