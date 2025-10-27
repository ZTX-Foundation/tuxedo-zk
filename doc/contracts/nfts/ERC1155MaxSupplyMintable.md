# ERC1155MaxSupplyMintable.sol

## Introduction
An extension of the standard ERC1155 multi-token interface. Designed to cater to both fungible and non-fungible tokens, it introduces a mechanism to manage the maximum supply of each individual token and supports EIP-5633/5192 compliant soulbound (non-transferable) tokens.

### Overview
The diagrams below provide a visual representation of how `ERC1155MaxSupplyMintable.sol` interacts with its various features and dependencies. It primarily shows the flow of actions a user can initiate and how the contract interacts with other referenced contracts and utilities.

#### Top-down
```mermaid
graph TD
    ERC1155MaxSupplyMintable --> ERC1155Burnable
    ERC1155MaxSupplyMintable --> CoreRef
    ERC1155MaxSupplyMintable --> IERC5633
    ERC1155MaxSupplyMintable --> IERC5192
    ERC1155MaxSupplyMintable --> Roles
    ERC1155MaxSupplyMintable --> Strings

    ERC1155Burnable --> ERC1155
```

#### Sequence
```mermaid
sequenceDiagram
    participant User as User
    participant ERC1155MaxSupplyMintable
    participant Core as CoreRef
    participant ERC1155

    User->>+ERC1155MaxSupplyMintable: setSupplyCap(...)
    alt ADMIN role
        ERC1155MaxSupplyMintable->>ERC1155MaxSupplyMintable: _setSupplyCap(...)
        ERC1155MaxSupplyMintable-->>ERC1155MaxSupplyMintable: Emit SupplyCapUpdated event
    else
        ERC1155MaxSupplyMintable-->>-User: Revert
    end

    User->>+ERC1155MaxSupplyMintable: setSupplyCapAndNonTransferable(...)
    alt ADMIN role
        ERC1155MaxSupplyMintable->>ERC1155MaxSupplyMintable: _setSupplyCap(...)
        ERC1155MaxSupplyMintable->>ERC1155MaxSupplyMintable: _setNonTransferable(...)
    else
        ERC1155MaxSupplyMintable-->>-User: Revert
    end

    User->>+ERC1155MaxSupplyMintable: setNonTransferable(...)
    alt ADMIN role and token initialized
        ERC1155MaxSupplyMintable->>ERC1155MaxSupplyMintable: _setNonTransferable(...)
    else
        ERC1155MaxSupplyMintable-->>-User: Revert
    end

    User->>+ERC1155MaxSupplyMintable: setURI(...)
    alt ADMIN role
        ERC1155MaxSupplyMintable->>ERC1155: _setURI(...)
        ERC1155MaxSupplyMintable-->>ERC1155MaxSupplyMintable: Emit URIUpdated event
    else
        ERC1155MaxSupplyMintable-->>-User: Revert
    end

    User->>+ERC1155MaxSupplyMintable: mint(...)
    alt MINTER role and Contract is not paused
        ERC1155MaxSupplyMintable->>ERC1155MaxSupplyMintable: Check totalSupply(...) <= maxTokenSupply[...]
        ERC1155MaxSupplyMintable->>ERC1155: _mint(...)
        ERC1155MaxSupplyMintable->>ERC1155MaxSupplyMintable: Check totalSupply(...) <= maxTokenSupply[...]
        ERC1155MaxSupplyMintable-->>ERC1155MaxSupplyMintable: Emit TokenMinted event
    else
        ERC1155MaxSupplyMintable-->>-User: Revert
    end

    User->>+ERC1155MaxSupplyMintable: mintBatch(...)
    alt MINTER role and contract is not paused
        ERC1155MaxSupplyMintable->>ERC1155: _mintBatch(...)
        loop For each tokenId
            ERC1155MaxSupplyMintable-->>ERC1155MaxSupplyMintable: Check totalSupply(...) <= maxTokenSupply[...]
        end
        ERC1155MaxSupplyMintable-->>ERC1155MaxSupplyMintable: Emit BatchMinted event
    else
        ERC1155MaxSupplyMintable-->>-User: Revert
    end

    User->>+ERC1155MaxSupplyMintable: getMintAmountLeft(tokenId)
    ERC1155MaxSupplyMintable-->>-User: Return mint amount left

    User->>+ERC1155MaxSupplyMintable: name()
    ERC1155MaxSupplyMintable-->>-User: Return token name

    User->>+ERC1155MaxSupplyMintable: symbol()
    ERC1155MaxSupplyMintable-->>-User: Return token symbol

    User->>+ERC1155MaxSupplyMintable: uri(_id)
    ERC1155MaxSupplyMintable->>ERC1155: Get base URI
    ERC1155->>ERC1155MaxSupplyMintable: Return base URI
    ERC1155MaxSupplyMintable-->>-User: Return combined URI
```

## Base Contracts
### OpenZeppelin
- [ERC1155](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol): A standardized interface for multi-token contracts. Each token in ERC1155 can represent any value (fungible, non-fungible, or a mixture).
- [ERC1155Burnable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/extensions/ERC1155Burnable.sol): Extension of the ERC1155 standard that adds a burn function, allowing holders of tokens to destroy them.
### Protocol Specific
- [Strings](https://github.com/ZTX-Foundation/tuxedo/blob/develop/src/utils/Strings.sol): A utility library for handling string operations in Solidity.
- [Roles](https://github.com/ZTX-Foundation/tuxedo/blob/develop/src/core/Roles.sol): Manages different roles for access control.
- [CoreRef](https://github.com/ZTX-Foundation/tuxedo/blob/develop/src/refs/CoreRef.sol): Provides a reference to the protocol's core contract.

**Note:** This contract implements custom total supply tracking instead of using ERC1155Supply. The custom implementation ensures that burned tokens still count towards the max supply cap, preventing infinite minting through burn/mint cycles.

## Features
- Easily track the total supply of each token ID with custom logic that counts burned tokens towards the max supply.
- Enables token holders to burn (destroy) their tokens.
- Ability to change the metadata base URI.
- Setting and updating of supply caps for individual token IDs.
- **EIP-5633 & EIP-5192 compliant soulbound tokens**: Support for non-transferable tokens on a per-token basis with standard interface detection.
- Non-transferable tokens can still be minted and burned but cannot be transferred between addresses.
- Marketplace detection via `Locked`/`Unlocked` events (EIP-5192) and `Soulbound` events (EIP-5633).
- Query functions: `isSoulbound(tokenId)` and `locked(tokenId)` for checking token transferability status.
- Batch minting.

## Events
These events offer a mechanism to track and audit the various interactions and updates that occur within the `ERC1155MaxSupplyMintable` contract.

### `SupplyCapUpdated`
Emitted when a token's supply cap is updated.
Logs:
- `tokenId`: The ID of the token whose supply cap was updated.
- `previousMaxSupply`: The previous supply cap of the token.
- `maxSupply`: The new supply cap of the token.

### `URIUpdated`
Emitted when the metadata base URI is updated.
Logs:
- `newuri`: The new metadata base URI.

### `TokenMinted`
Emitted when a token is minted.
Logs:
- `account`: The recipient of the minted token.
- `tokenId`: The ID of the minted token.
- `amount`: The amount of tokens minted.

### `TokenBurned`
Emitted when a token is burned.
Logs:
- `account`: The holder of the burned token.
- `tokenId`: The ID of the burned token.
- `amount`: The amount of tokens burned.

### `BatchMinted`
Emitted when a batch of tokens is minted.
Logs:
- `account`: The recipient of the minted tokens.
- `tokenIds`: The IDs of the minted tokens.
- `amounts`: The amounts of tokens minted.

### `Soulbound` (EIP-5633)
Emitted when a token's soulbound (non-transferable) status changes.
Logs:
- `id`: The token ID whose soulbound status changed.
- `bounded`: Whether the token is now soulbound (true) or transferable (false).

### `Locked` (EIP-5192)
Emitted when a token becomes non-transferable (locked).
Logs:
- `tokenId`: The token ID that was locked.

### `Unlocked` (EIP-5192)
Emitted when a token becomes transferable (unlocked).
Logs:
- `tokenId`: The token ID that was unlocked.

## Constructor
The constructor accepts four arguments:

- `_core`: The address of a core contract that provides roles and access control.
- `_uri`: The base URI for the metadata of the tokens.
- `name_`: The name of the NFT contract.
- `symbol_`: The symbol of the NFT contract.

Upon deployment, The contract initializes several contract state variables, including:

- `_name`: Stores the name of the NFT contract.
- `_symbol`: Stores the symbol of the NFT contract.

and sets up the core functionality needed for minting and managing the supply cap of individual tokens within the contract.

## Functions
### `setSupplyCap()`
Allows `ADMIN` to set the supply cap for a specific token. The new supply cap must be greater than or equal to the current supply.

### `_setSupplyCap()`
An internal function to set the supply cap for a given token. Emits a `SupplyCapUpdated` event.

### `setSupplyCapAndNonTransferable()`
Allows `ADMIN` to set both the supply cap and non-transferability status for a specific token in a single transaction. This is useful when initializing a new token. The token must not already have a max supply set if setting to non-transferable.

**Parameters:**
- `tokenId`: The ID of the token to configure.
- `maxSupply`: The maximum supply cap for the token.
- `isNonTransferable`: Whether the token should be non-transferable (true) or transferable (false).

### `setNonTransferable()`
Allows `ADMIN` to toggle the transferability of a specific token. This can be used to make a token non-transferable (soulbound-like) or to re-enable transfers for a previously non-transferable token.

**Parameters:**
- `tokenId`: The ID of the token to update.
- `isNonTransferable`: Whether the token should be non-transferable (true) or transferable (false).

**Requirements:**
- The token must have a max supply greater than 0 (i.e., the token must be initialized).

### `_setNonTransferable()`
An internal function to set the non-transferability status for a given token. Validates that the token has been initialized with a max supply before allowing the transferability to be set. Emits `Soulbound` event and either `Locked` or `Unlocked` event depending on the new status.

### `setURI()`
Allows `ADMIN` to update the URI (metadata) for the token.

### `mint()`
Allows `MINTER` to mint tokens for a specific recipient. The number of tokens minted must not exceed the supply cap for the token. Emits a `TokenMinted` event.

### `mintBatch()`
Allows `MINTER` to mint a batch of tokens for a specific recipient. The total number of tokens minted across all IDs must not exceed the respective supply caps. Emits a `BatchMinted` event.

### `getMintAmountLeft()`
A view function that returns the amount of tokens that can still be minted before reaching the supply cap for a specific token. Note that this takes into account burned tokens, as they permanently count towards the max supply.

### `name()`
View function that returns the name of the collection.

### `symbol()`
View function that returns the symbol of the collection.

### `exists()`
A view function that returns whether any tokens with the given ID have been minted (based on total supply).

**Parameters:**
- `id`: The token ID to check.

**Returns:**
- `bool`: True if the token has been minted (total supply > 0), false otherwise.

### `isSoulbound()` (EIP-5633)
A view function that returns whether a token is soulbound (non-transferable).

**Parameters:**
- `id`: The token ID to check.

**Returns:**
- `bool`: True if the token is soulbound, false if transferable.

### `locked()` (EIP-5192)
A view function that returns whether a token is locked (non-transferable). This is an alias for `isSoulbound()` for EIP-5192 compatibility.

**Parameters:**
- `id`: The token ID to check.

**Returns:**
- `bool`: True if the token is locked, false if transferable.

### `supportsInterface()`
EIP-165 interface detection function. Returns true for supported interfaces including:
- ERC1155 (`0xd9b67a26`)
- EIP-5633 (`type(IERC5633).interfaceId`)
- EIP-5192 (`type(IERC5192).interfaceId`)

**Parameters:**
- `interfaceId`: The interface identifier to check.

**Returns:**
- `bool`: True if the interface is supported, false otherwise.

### `_beforeTokenTransfer()`
An internal override function that:
1. Enforces non-transferability rules: Blocks transfers (but not mints or burns) for tokens marked as non-transferable.
2. Tracks total supply: Only increments total supply on mints, not decrements on burns. This ensures burned tokens permanently count towards the max supply cap.

**Transfer Blocking Logic:**
- If a token is marked as non-transferable, any attempt to transfer it between addresses will revert with "BaseERC1155NFT: token is non-transferable".
- Minting (from address(0)) and burning (to address(0)) are always allowed, even for non-transferable tokens.

### `uri()`
A view function that generates the URI for a specific token ID, including its string representation.
