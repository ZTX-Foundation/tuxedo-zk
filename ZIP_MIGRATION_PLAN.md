# ZIP Proposal Migration Plan: build() → deploy()

## Overview

The current proposal architecture uses `build()` + `simulate()` to record and execute governance actions locally, but these changes are never broadcast to the testnet. This causes sequential testnet deployments to fail because later proposals depend on state changes that only exist locally.

**Solution:** Move all configuration logic from `build()` to `deploy()` so changes are broadcast to the network.

---

## Migration Strategy

### Key Question: Can deployer execute these actions?

All `build()` functions use `buildModifier(ADMIN_TIMELOCK_CONTROLLER)` to prank as the timelock. We need to determine if the **DEPLOYER_EOA** can execute these same actions instead.

**Analysis:**
- The deployer has ADMIN role on Core (until revoked on mainnet in zip001:70)
- The ADMIN role can grant other roles and call administrative functions
- `setSupplyCap()` requires ADMIN role on Core
- `initalizeSeasonDistribution()` likely requires ADMIN or specific role

**Conclusion:** ✅ The deployer CAN execute all these actions on testnet since they retain ADMIN role.

---

## Files Requiring Migration

### ✅ zip000.sol - No changes needed
- **Status:** ✅ Already complete
- **Reason:** Only has `deploy()`, no `build()` or `simulate()`
- **Actions:** None

---

### ✅ zip001.sol - No changes needed
- **Status:** ✅ Already complete
- **Reason:** Only has `deploy()` which already grants roles directly, no `build()` or `simulate()`
- **Actions:** None

---

### ✅ zip002.sol - No changes needed
- **Status:** ✅ Already complete
- **Reason:** Only has `deploy()`, no `build()` or `simulate()`
- **Note:** Line 46 grants ADMIN role to timelock on testnet (this works because deployer still has ADMIN)
- **Actions:** None

---

### ⬜ zip003.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Medium
- **Items to migrate:** 8 role grants
- **Current:** Role grants in `build()` function (lines 118-136)
- **Target:** Move to end of `deploy()` function (after line 110)

**Operations to migrate:**
```solidity
// 8 role grant operations:
_core.grantRole(Roles.GUARDIAN, addresses.getAddress("GUARDIAN_MULTISIG"));
_core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES"));
_core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES"));
_core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_AUTO_GRAPH_MINTER"));
_core.grantRole(Roles.MINTER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_AUTO_GRAPH_MINTER"));
_core.grantRole(Roles.REGISTRY_OPERATOR_PROTOCOL_ROLE, addresses.getAddress("ERC1155_SEASON_ONE"));
_core.grantRole(Roles.MINTER_NOTARY_PROTOCOL_ROLE, addresses.getAddress("AUTOGRAPH_SERVICE_KMS_WALLET"));
_core.grantRole(Roles.GAME_CONSUMER_NOTARY_PROTOCOL_ROLE, addresses.getAddress("AUTOGRAPH_SERVICE_KMS_WALLET"));
```

**Validation:** The `validate()` function already checks these roles, so it will verify the migration worked.

**Decision needed:** Should we keep `build()` and `simulate()` for mainnet governance, or remove them entirely for testnet?
- [ ] Keep `build()` and `simulate()` for mainnet (add conditional: `if (block.chainid == Constants.ARBITRUM_MAINNET)`)
- [x] Remove `build()` and `simulate()` entirely (testnet-only approach)
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip004.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** High (many operations)
- **Items to migrate:** ~100+ setSupplyCap calls + 1 initialization call
- **Current:** Configuration in `build()` function (lines 204-238)
- **Target:** Create `deploy()` function with same logic

**Operations to migrate:**
- 80 placeable token supply caps
- 11 wearable token supply caps
- 3 consumable token supply caps
- 1 `initalizeSeasonDistribution()` call

**Special consideration:** This is a pure configuration proposal with no contract deployments. The deployer needs to have the necessary permissions to call these methods.

**Potential Issue:** `initalizeSeasonDistribution()` calls `registerBatch()` internally, which requires `REGISTRY_OPERATOR_PROTOCOL_ROLE`. This role is granted to `ERC1155_SEASON_ONE` in zip003's build(), so if we don't migrate zip003 first, this will fail.

**Dependencies:** ❗ MUST complete zip003 migration first

**Decision needed:**
- [ ] Migrate all setSupplyCap calls to deploy()
- [ ] Skip this proposal for testnet (unnecessary configuration)
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip005.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Medium
- **Items to migrate:** 92 setSupplyCap calls for placeables
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip006.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 25 setSupplyCap calls for wearables (from zip006.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip007.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 1 setSupplyCap call for wearables (from zip007.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip008.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 24 setSupplyCap calls for wearables (from zip008.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip009.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 2 setSupplyCap calls for wearables (from zip009.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip010.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 1 setSupplyCap call for placeables (from zip010.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip011.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 12 setSupplyCap calls for wearables (from zip011.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip012.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 1 setSupplyCap call for wearables (from zip012.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip013.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 2 setSupplyCap calls for wearables (from zip013.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip014.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 1 setSupplyCap call for wearables (from zip014.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip016.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 1 setSupplyCap call for wearables (from zip016.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip017.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 15 setSupplyCap calls for wearables (from zip017.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip018.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 24 placeable + 5 wearable setSupplyCap calls (from zip018.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip019.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 27 setSupplyCap calls for wearables (from zip019.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip020.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Medium
- **Items to migrate:** 155 placeable + 23 wearable setSupplyCap calls (from zip020.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

### ⬜ zip021.sol - REQUIRES MIGRATION
- **Status:** ⬜ Pending
- **Complexity:** Low
- **Items to migrate:** 29 setSupplyCap calls for wearables (from zip021.json)
- **Current:** Configuration in `build()` function
- **Target:** Create `deploy()` function with same logic

**Decision needed:**
- [ ] Migrate to deploy()
- [ ] Skip for testnet
- [ ] Other (specify): _______________

**User Decision:**

---

## Summary

### Files requiring migration: 19 out of 22
- ✅ No changes: zip000, zip001, zip002 (3 files)
- ⬜ Requires migration: zip003-zip021 (19 files)

### Critical path:
1. **zip003** must be migrated first (grants required roles)
2. **zip004** depends on zip003 (needs REGISTRY_OPERATOR_PROTOCOL_ROLE)
3. All others (zip005-zip021) are independent supply cap updates

### Complexity breakdown:
- High complexity: zip004 (many operations + initialization)
- Medium complexity: zip003, zip005, zip020 (multiple operations)
- Low complexity: zip006-zip019, zip021 (simple setSupplyCap calls)

### Total operations to migrate:
- 8 role grants (zip003)
- 1 season initialization (zip004)
- ~500+ setSupplyCap calls (zip004-zip021)

---

## Implementation Notes

### General Migration Pattern

```solidity
// OLD: Configuration in build()
function build() public override buildModifier(addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")) {
    SomeContract contract = SomeContract(addresses.getAddress("CONTRACT_NAME"));
    contract.setSupplyCap(tokenId, maxSupply);
}

// NEW: Configuration in deploy()
function deploy() public override {
    SomeContract contract = SomeContract(addresses.getAddress("CONTRACT_NAME"));
    contract.setSupplyCap(tokenId, maxSupply);
}
```

### Role Permissions

All operations require ADMIN role on Core:
- `grantRole()` - requires ADMIN
- `setSupplyCap()` - requires ADMIN on Core (checked via CoreRef)
- `initalizeSeasonDistribution()` - requires REGISTRY_OPERATOR_PROTOCOL_ROLE on caller

On testnet, the DEPLOYER_EOA has ADMIN role (not revoked until mainnet), so all operations will work.

### What to do with build() and simulate()?

**Option A: Conditional preservation (recommended for mainnet governance)**
```solidity
function deploy() public override {
    // All configuration here for testnet
}

function build() public override buildModifier(addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")) {
    if (block.chainid == Constants.ARBITRUM_MAINNET) {
        // Same operations as deploy() but for governance proposal
    }
}
```

**Option B: Complete removal (simpler, testnet-only)**
```solidity
function deploy() public override {
    // All configuration here
}

// Remove build() and simulate() entirely
```

**Decision needed:** Which approach should we take?

**User Decision:**

---

## Validation Strategy

Each proposal has a `validate()` function that checks the state. After migration, these will verify that:
- Roles were granted correctly (zip003)
- Supply caps were set correctly (zip004-zip021)
- Season distribution was initialized (zip004)

No changes to `validate()` functions are needed.

---

## Next Steps

1. Get user decisions on:
   - Whether to keep `build()`/`simulate()` for mainnet or remove entirely
   - Whether to migrate all proposals or skip some for testnet

2. Migrate zip003 first (critical dependency)

3. Migrate zip004 (depends on zip003)

4. Migrate remaining proposals (zip005-zip021) in any order

5. Test sequential deployment on testnet

6. Update BootstrapTestnet.s.sol if needed
