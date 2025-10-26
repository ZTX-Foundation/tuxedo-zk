# zkSync Deployment Issues for BootstrapTestnet Script

This document outlines all the cheatcode/opcode issues that prevent `script/deploy/BootstrapTestnet.s.sol` from running with the `--zksync` flag.

## Root Cause
When using `--zksync` flag, contract constructors run in the zkSync VM context where Foundry cheatcodes (like `vm.readFile()`, `vm.parseJson()`, `vm.envOr()`) are not supported. Only code running directly in the Script's `setUp()` or `run()` functions (host environment) can use cheatcodes.

---

## Critical Issues

### 1. Addresses Contract Constructor
- [ ] **File:** `lib/forge-proposal-simulator/addresses/Addresses.sol:57-77`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Problem:** Constructor tries to read and parse JSON file using cheatcodes
- **Called From:** `script/deploy/BootstrapTestnet.s.sol:54` - `new Addresses(addressPath)`
- **Impact:** BLOCKS ALL DEPLOYMENT - script fails immediately in setUp()

**Suggested Fix:**
```solidity
// Create a zkSync-compatible version without cheatcodes in constructor
// Move file reading/parsing to BootstrapTestnet.setUp() and populate via addAddress() calls

function setUp() public {
    // Read JSON in host environment (cheatcodes work here)
    string memory addressesData = vm.readFile(addressPath);
    bytes memory parsedJson = vm.parseJson(addressesData);
    SavedAddresses[] memory savedAddresses = abi.decode(parsedJson, (SavedAddresses[]));

    // Create empty contract (no cheatcodes in constructor)
    addresses = new ZkAddresses(); // New zkSync-compatible version

    // Populate from host context
    for (uint256 i = 0; i < savedAddresses.length; i++) {
        addresses.addAddress(
            savedAddresses[i].name,
            savedAddresses[i].addr,
            savedAddresses[i].chainId,
            savedAddresses[i].isContract
        );
    }
}
```

---

### 2. Proposal Base Class Constructor
- [ ] **File:** `lib/forge-proposal-simulator/src/proposals/Proposal.sol:51-60`
- **Opcodes:** `vm.envOr()` (called 7 times)
- **Problem:** All proposal contracts inherit from this base class, so ALL proposals fail on instantiation
- **Called From:**
  - `script/deploy/BootstrapTestnet.s.sol:57` - `new zip000()`
  - `script/deploy/BootstrapTestnet.s.sol:58` - `new zip001()`
  - `script/deploy/BootstrapTestnet.s.sol:59-77` - `new zip002()` through `new zip021()`
- **Impact:** BLOCKS ALL PROPOSALS - all 21 proposal contracts fail to instantiate

**Suggested Fix:**
```solidity
// Option 1: Remove constructor, initialize via setConfig() method called from host
constructor() {
    // Empty - no cheatcodes
}

function setConfig(
    bool _DEBUG,
    bool _DO_DEPLOY,
    bool _DO_AFTER_DEPLOY_MOCK,
    bool _DO_BUILD,
    bool _DO_SIMULATE,
    bool _DO_VALIDATE,
    bool _DO_PRINT
) public {
    DEBUG = _DEBUG;
    DO_DEPLOY = _DO_DEPLOY;
    DO_AFTER_DEPLOY_MOCK = _DO_AFTER_DEPLOY_MOCK;
    DO_BUILD = _DO_BUILD;
    DO_SIMULATE = _DO_SIMULATE;
    DO_VALIDATE = _DO_VALIDATE;
    DO_PRINT = _DO_PRINT;
}

// Then call from setUp():
proposals.push(Proposal(address(proposal = new zip000())));
proposal.setConfig(
    vm.envOr("DEBUG", false),
    vm.envOr("DO_DEPLOY", true),
    vm.envOr("DO_AFTER_DEPLOY_MOCK", true),
    vm.envOr("DO_BUILD", true),
    vm.envOr("DO_SIMULATE", true),
    vm.envOr("DO_VALIDATE", true),
    vm.envOr("DO_PRINT", true)
);
```

---

## Secondary Issues (In deploy() functions - only issues if proposals run)

These issues occur in the `deploy()` methods which are called from the `run()` function. They will only fail if we get past the constructor issues above.

### 3. zip000 - Token Name/Symbol from Environment
- [ ] **File:** `proposals/zips/zip000.sol:26-27`
- **Opcodes:** `vm.envString()` (2 calls)
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Fails when trying to read TOKEN_NAME and TOKEN_SYMBOL environment variables

**Suggested Fix:**
```solidity
// Pass as constructor parameters or read in BootstrapTestnet.setUp() and set via method
```

### 4. zip001 - Metadata Base URI from Environment
- [ ] **File:** `proposals/zips/zip001.sol:40`
- **Opcodes:** `vm.envString()` (2 calls)
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Fails when constructing metadata base URI

**Suggested Fix:**
```solidity
// Read ENVIRONMENT and DOMAIN in BootstrapTestnet and pass to deploy via state variable
```

### 5. zip003 - Metadata Base URI from Environment
- [ ] **File:** `proposals/zips/zip003.sol:38`
- **Opcodes:** `vm.envString()` (2 calls)
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Fails when constructing metadata base URI

**Suggested Fix:**
```solidity
// Same as zip001 - read in host context and pass via state
```

### 6. zip006 - JSON File Reading
- [ ] **File:** `proposals/zips/zip006.sol:29-31`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read wearable data from JSON file

**Suggested Fix:**
```solidity
// Read JSON in setUp(), decode, and pass data to proposal via setter method
```

### 7. zip007 - JSON File Reading
- [ ] **File:** `proposals/zips/zip007.sol:29-31`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read wearable data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 8. zip008 - JSON File Reading
- [ ] **File:** `proposals/zips/zip008.sol:19-21`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read wearable data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 9. zip009 - JSON File Reading
- [ ] **File:** `proposals/zips/zip009.sol:29-31`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read wearable data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 10. zip010 - JSON File Reading
- [ ] **File:** `proposals/zips/zip010.sol:30-33`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read placeable data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 11. zip011 - JSON File Reading
- [ ] **File:** `proposals/zips/zip011.sol:30-33`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read wearable data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 12. zip012 - JSON File Reading
- [ ] **File:** `proposals/zips/zip012.sol:30-33`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read wearable data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 13. zip013 - JSON File Reading
- [ ] **File:** `proposals/zips/zip013.sol:30-33`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read wearable data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 14. zip014 - JSON File Reading
- [ ] **File:** `proposals/zips/zip014.sol:30-33`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read wearable data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 15. zip016 - JSON File Reading
- [ ] **File:** `proposals/zips/zip016.sol:30-33`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read wearable data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 16. zip017 - JSON File Reading
- [ ] **File:** `proposals/zips/zip017.sol:30-33`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read wearable data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 17. zip018 - JSON File Reading
- [ ] **File:** `proposals/zips/zip018.sol:40-43`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 18. zip019 - JSON File Reading
- [ ] **File:** `proposals/zips/zip019.sol:30-33`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read wearable data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 19. zip020 - JSON File Reading
- [ ] **File:** `proposals/zips/zip020.sol:40-43`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

### 20. zip021 - JSON File Reading
- [ ] **File:** `proposals/zips/zip021.sol:30-33`
- **Opcodes:** `vm.readFile()`, `vm.parseJson()`
- **Called From:** Within `deploy()` method during broadcast
- **Impact:** Cannot read wearable data from JSON file

**Suggested Fix:**
```solidity
// Same as zip006
```

---

## Summary

**Total Issues:** 20 locations
- **Critical (Blocking):** 2 (Addresses constructor, Proposal base constructor)
- **Secondary (Deploy phase):** 18 (various zip proposals)

**Priority:**
1. Fix `Addresses.sol` constructor (#1) - MUST FIX FIRST
2. Fix `Proposal.sol` constructor (#2) - MUST FIX SECOND
3. Fix individual zip proposals (#3-20) - Fix as you go, or batch fix

**General Solution Pattern:**
All cheatcodes must be called in the Script's `setUp()` or `run()` functions (host environment), then data passed to contracts via:
- Constructor parameters
- Setter methods
- State variables

**No cheatcodes can be called:**
- In contract constructors
- In functions called during broadcast (deploy() functions)
- In any contract code that runs in zkSync VM context
