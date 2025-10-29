// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import {CoreRef} from "@protocol/refs/CoreRef.sol";
import {ERC1155MaxSupplyMintable} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";
import {Roles} from "@protocol/core/Roles.sol";

/// @notice Helper contract to mint tokens with proper lock management
/// This wraps the mint call in a globalLock(1) context so that mint's globalLock(2) works
contract MintHelper is CoreRef {
    constructor(address _core) CoreRef(_core) {}

    /// @notice Mint tokens with proper lock level management
    function mintWithLock(
        address nftContract,
        address recipient,
        uint256 tokenId,
        uint256 amount
    ) external onlyRole(Roles.MINTER_PROTOCOL_ROLE) whenNotPaused globalLock(1) {
        ERC1155MaxSupplyMintable(nftContract).mint(recipient, tokenId, amount);
    }
}
