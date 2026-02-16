# ERC1155AutoGraphBatchMinter.sol

## Introduction
Batch minting extension for [ERC1155AutoGraphMinter](./ERC1155AutoGraphMinter.md). Deployed as a separate contract to keep bytecode within block gas limits on zkSync OS.

### Overview
The batch minter reads whitelist, payment recipient, and expiry config from the primary `ERC1155AutoGraphMinter` via cross-contract view calls. It maintains its own `completedJobs` mapping and rate limit buffer.

#### Top-down
```mermaid
graph TD
    ERC1155AutoGraphBatchMinter --> ECDSA
    ERC1155AutoGraphBatchMinter --> IERC20
    ERC1155AutoGraphBatchMinter --> SafeERC20
    ERC1155AutoGraphBatchMinter --> CoreRef
    ERC1155AutoGraphBatchMinter --> Roles
    ERC1155AutoGraphBatchMinter --> ERC1155MaxSupplyMintable
    ERC1155AutoGraphBatchMinter --> ERC1155AutoGraphMinter
    ERC1155AutoGraphBatchMinter --> RateLimited
```

#### Sequence
```mermaid
sequenceDiagram
    participant User as User/Caller
    participant BatchMinter as ERC1155AutoGraphBatchMinter
    participant AutoGraphMinter as ERC1155AutoGraphMinter
    participant IERC20
    participant ERC1155MaxSupplyMintable

    User->>+BatchMinter: mintBatchForFree(...)
    BatchMinter->>AutoGraphMinter: isWhitelistedAddress(nftContract)
    BatchMinter->>BatchMinter: _mintBatch(...) [verify hashes, deplete buffer]
    BatchMinter->>ERC1155MaxSupplyMintable: mintBatch(...)
    BatchMinter-->>-User: Emit ERC1155BatchMinted event

    User->>+BatchMinter: mintBatchWithPaymentTokenAsFee(...)
    BatchMinter->>AutoGraphMinter: isWhitelistedAddress(nftContract)
    BatchMinter->>BatchMinter: _mintBatch(...)
    BatchMinter->>AutoGraphMinter: paymentRecipient()
    BatchMinter->>IERC20: safeTransferFrom(sender, paymentRecipient, totalPayment)
    BatchMinter->>ERC1155MaxSupplyMintable: mintBatch(...)
    BatchMinter-->>-User: Emit ERC1155BatchMinted event

    User->>+BatchMinter: mintBatchWithEthAsFee(...)
    BatchMinter->>AutoGraphMinter: isWhitelistedAddress(nftContract)
    BatchMinter->>BatchMinter: _mintBatch(...)
    BatchMinter->>AutoGraphMinter: paymentRecipient()
    BatchMinter->>BatchMinter: Transfer ETH to paymentRecipient
    BatchMinter->>ERC1155MaxSupplyMintable: mintBatch(...)
    BatchMinter-->>-User: Emit ERC1155BatchMinted event

    User->>+BatchMinter: canMintBatchFree(...)
    BatchMinter->>ERC1155MaxSupplyMintable: maxTokenSupply(tokenId)
    BatchMinter->>ERC1155MaxSupplyMintable: totalSupply(tokenId)
    BatchMinter-->>-User: return (mintable[], available[])
```

## Base Contracts
### OpenZeppelin
- [ECDSA](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol): Elliptic Curve Digital Signature Algorithm for signature verification.
- [SafeERC20](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol): Safe wrappers for ERC20 transfer and approve.
- [IERC20](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol): Interface for the ERC20 standard.
### Protocol Specific
- [CoreRef](../refs/CoreRef.md): Provides a reference to the protocol's core contract.
- [Roles](../core/Roles.md): Manages different roles for access control.
- [ERC1155MaxSupplyMintable](./ERC1155MaxSupplyMintable.md): ERC-1155 with max supply minting.
- [ERC1155AutoGraphMinter](./ERC1155AutoGraphMinter.md): Primary minter, provides config via view functions.
- [RateLimited](../utils/extensions/RateLimited.md): Rate-limiting functionality.

## Features
- Batch minting of ERC-1155 tokens (free, ERC20 fee, or ETH fee).
- Reads whitelist and payment config from the primary `ERC1155AutoGraphMinter`.
- Independent `completedJobs` tracking and rate limit buffer.
- `canMintBatchFree` view function for supply and job pre-checks.

## Required Roles
- `MINTER_PROTOCOL_ROLE`: Required on Core to mint via `ERC1155MaxSupplyMintable`.
- `LOCKER_PROTOCOL_ROLE`: Required on Core for the global reentrancy lock.

## Events
### `ERC1155BatchMinted`
Emitted when a batch of ERC1155 tokens are minted.
Logs:
- `nftContract`: The address of the NFT contract.
- `recipient`: The address of the recipient.
- `tokenIds`: The IDs of the tokens minted.
- `units`: The number of tokens minted per token ID.

## Constructor
Accepts four arguments:
- `_core`: The address of the core contract.
- `_autoGraphMinter`: Reference to the primary `ERC1155AutoGraphMinter` for config lookups.
- `_replenishRatePerSecond`: Rate limit buffer replenish rate.
- `_bufferCap`: Maximum rate limit buffer capacity.

## Functions
### `mintBatchForFree`
Mints a batch of NFTs for free. Verifies whitelist, hashes, signatures, and expiry for each item.

### `mintBatchWithPaymentTokenAsFee`
Mints a batch of NFTs with an ERC20 token as fee. Aggregates total payment and transfers to the primary minter's `paymentRecipient`.

### `mintBatchWithEthAsFee`
Mints a batch of NFTs with ETH as fee. Verifies `msg.value` matches total payment and transfers to the primary minter's `paymentRecipient`.

### `canMintBatchFree`
View function that checks which items in a batch can be minted. Combines supply checks (maxSupply vs totalSupply) with completed job checks. Accounts for prior demand from duplicate tokenIds within the same batch.

### `getHash`
Computes the hash of a message based on `HashInputsParams` (same encoding as primary minter).

### `recoverSigner`
Recovers the address that signed a given message hash.
