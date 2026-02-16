// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import {Roles} from "@protocol/core/Roles.sol";
import {CoreRef} from "@protocol/refs/CoreRef.sol";
import {ERC1155MaxSupplyMintable} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";

/// @notice Batch operations helper for ERC1155MaxSupplyMintable contracts.
/// @dev Deployed separately to keep the main token contract's bytecode small
/// enough to deploy on chains with tight block gas limits (e.g. zkSync OS).
/// Must be granted ADMIN role on Core to call the token contract's admin functions.
contract ERC1155BatchOperator is CoreRef {
    constructor(address _core) CoreRef(_core) {}

    /// @notice Set multiple supply caps in a single transaction.
    /// @param tokenContract the ERC1155MaxSupplyMintable to configure
    /// @param tokenIds array of token IDs
    /// @param maxSupplies array of max supplies (same length)
    function setSupplyCapBatch(
        ERC1155MaxSupplyMintable tokenContract,
        uint256[] calldata tokenIds,
        uint256[] calldata maxSupplies
    ) external onlyRole(Roles.ADMIN) {
        require(tokenIds.length == maxSupplies.length, "ERC1155: length mismatch");
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            tokenContract.setSupplyCap(tokenIds[i], maxSupplies[i]);
        }
    }

    /// @notice Set non-transferable flags in batch.
    /// @param tokenContract the ERC1155MaxSupplyMintable to configure
    /// @param tokenIds array of token IDs
    /// @param flags matching array of bools; true = non-transferable
    function setNonTransferableBatch(
        ERC1155MaxSupplyMintable tokenContract,
        uint256[] calldata tokenIds,
        bool[] calldata flags
    ) external onlyRole(Roles.ADMIN) {
        require(tokenIds.length == flags.length, "ERC1155: length mismatch");
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            tokenContract.setNonTransferable(tokenIds[i], flags[i]);
        }
    }

    /// @notice Set supply caps and non-transferable flags in one atomic batch.
    /// @param tokenContract the ERC1155MaxSupplyMintable to configure
    /// @param tokenIds array of token IDs
    /// @param maxSupplies array of max supplies
    /// @param flags array of non-transferable flags
    function setSupplyCapAndNonTransferableBatch(
        ERC1155MaxSupplyMintable tokenContract,
        uint256[] calldata tokenIds,
        uint256[] calldata maxSupplies,
        bool[] calldata flags
    ) external onlyRole(Roles.ADMIN) {
        require(
            tokenIds.length == maxSupplies.length && tokenIds.length == flags.length,
            "ERC1155: length mismatch"
        );
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            tokenContract.setSupplyCapAndNonTransferable(tokenIds[i], maxSupplies[i], flags[i]);
        }
    }
}
