// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CoreRef} from "@protocol/refs/CoreRef.sol";
import {Roles} from "@protocol/core/Roles.sol";
import {ERC1155MaxSupplyMintable} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";
import {ERC1155AutoGraphMinter} from "@protocol/nfts/ERC1155AutoGraphMinter.sol";
import {RateLimited} from "@protocol/utils/extensions/RateLimited.sol";

/// @notice Batch minting extension for ERC1155AutoGraphMinter.
/// @dev Deployed separately to keep contract sizes within block gas limits on zkSync OS.
/// Reads whitelist, payment recipient, and expiry config from the primary AutoGraphMinter.
/// Must be granted MINTER_PROTOCOL_ROLE and LOCKER_PROTOCOL_ROLE on Core.
contract ERC1155AutoGraphBatchMinter is CoreRef, RateLimited {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /// @notice reference to the primary AutoGraphMinter for config lookups
    ERC1155AutoGraphMinter public immutable autoGraphMinter;

    /// @notice jobs that have completed, keyed by jobId
    mapping(uint256 jobId => bool completed) public completedJobs;

    /// @notice Event emitted when the batch mint is successful
    event ERC1155BatchMinted(
        address indexed nftContract,
        address indexed recipient,
        uint256[] tokenIds,
        uint256[] units
    );

    constructor(
        address _core,
        ERC1155AutoGraphMinter _autoGraphMinter,
        uint128 _replenishRatePerSecond,
        uint128 _bufferCap
    ) CoreRef(_core) RateLimited(_replenishRatePerSecond, _bufferCap) {
        autoGraphMinter = _autoGraphMinter;
    }

    /// ----------- Internal Helpers ----------- ///

    function _checkWhitelist(address nftContract) internal view {
        require(
            autoGraphMinter.isWhitelistedAddress(nftContract),
            "WhitelistedAddress: Provided address is not whitelisted"
        );
    }

    function _verifyHashAndSignerRoleExpireHash(
        bytes32 inputHash,
        uint256 jobId,
        bytes32 generatedHash,
        bytes memory signature,
        uint256 expiryToken
    ) internal {
        require(_isExpiryTokenValid(expiryToken), "ERC1155AutoGraphMinter: Expiry token is expired");
        require(inputHash == generatedHash, "ERC1155AutoGraphMinter: Hash mismatch");
        require(!completedJobs[jobId], "ERC1155AutoGraphMinter: Job already completed");
        require(
            core.hasRole(Roles.MINTER_NOTARY_PROTOCOL_ROLE, recoverSigner(inputHash, signature)),
            "ERC1155AutoGraphMinter: Missing MINTER_NOTARY Role"
        );
        completedJobs[jobId] = true;
    }

    function _isExpiryTokenValid(uint256 expiryToken) internal view returns (bool) {
        require(expiryToken <= block.timestamp, "ERC1155AutoGraphMinter: Expiry token must be in the past");
        uint256 hoursInSeconds = uint256(autoGraphMinter.expiryTokenHoursValid()) * 1 hours;
        uint256 diff = block.timestamp - expiryToken;
        return diff < hoursInSeconds;
    }

    function _mintChecksForPaymentTokenFee(address paymentToken, uint256 paymentAmount) internal pure {
        require(paymentToken != address(0), "ERC1155AutoGraphMinter: paymentToken must not be address(0)");
        require(paymentAmount > 0, "ERC1155AutoGraphMinter: paymentAmount must be greater than 0");
    }

    function _mintChecksForEthFee(uint256 paymentAmount) internal view {
        require(paymentAmount > 0, "ERC1155AutoGraphMinter: paymentAmount must be greater than 0");
        require(msg.value == paymentAmount, "ERC1155AutoGraphMinter: Payment amount does not match msg.value");
    }

    /// @dev helper function to mint batch of NFTs
    /// Buffer is depleted once after the loop with accumulated totalUnits
    function _mintBatch(
        address nftContract,
        address recipient,
        address paymentToken,
        ERC1155AutoGraphMinter.MintBatchParams[] calldata inputs
    ) internal returns (uint256[] memory, uint256[] memory, uint256) {
        uint256[] memory tokenIds = new uint256[](inputs.length);
        uint256[] memory units = new uint256[](inputs.length);
        uint256 totalPayment = 0;

        unchecked {
            for (uint256 i = 0; i < inputs.length; i++) {
                tokenIds[i] = inputs[i].tokenId;
                units[i] = inputs[i].units;

                ERC1155AutoGraphMinter.HashInputsParams memory input = ERC1155AutoGraphMinter.HashInputsParams(
                    recipient,
                    inputs[i].jobId,
                    inputs[i].tokenId,
                    inputs[i].units,
                    inputs[i].salt,
                    nftContract,
                    paymentToken,
                    inputs[i].paymentAmount,
                    inputs[i].expiryToken
                );

                _verifyHashAndSignerRoleExpireHash(
                    inputs[i].hash,
                    inputs[i].jobId,
                    getHash(input),
                    inputs[i].signature,
                    inputs[i].expiryToken
                );

                totalPayment += inputs[i].paymentAmount;
            }
        }

        // Deplete rate limit buffer once with accumulated total units
        {
            uint256 totalUnits = 0;
            for (uint256 i = 0; i < units.length; i++) {
                unchecked { totalUnits += units[i]; }
            }
            _depleteBuffer(totalUnits);
        }

        return (tokenIds, units, totalPayment);
    }

    // ----------------------- Mint Batch functions ----------------------- //

    /// @dev Mint Batch of NFTs for free
    function mintBatchForFree(
        address nftContract,
        address recipient,
        ERC1155AutoGraphMinter.MintBatchParams[] calldata inputs
    ) external globalLock(1) whenNotPaused {
        _checkWhitelist(nftContract);
        (uint256[] memory tokenIds, uint256[] memory units, ) = _mintBatch(nftContract, recipient, address(0), inputs);

        ERC1155MaxSupplyMintable(nftContract).mintBatch(recipient, tokenIds, units);
        emit ERC1155BatchMinted(nftContract, recipient, tokenIds, units);
    }

    /// @dev Mint Batch of NFTs with payment token as fee
    function mintBatchWithPaymentTokenAsFee(
        address nftContract,
        address recipient,
        address paymentToken,
        ERC1155AutoGraphMinter.MintBatchParams[] calldata inputs
    ) external globalLock(1) whenNotPaused {
        _checkWhitelist(nftContract);
        (uint256[] memory tokenIds, uint256[] memory units, uint256 totalPayment) = _mintBatch(
            nftContract, recipient, paymentToken, inputs
        );

        _mintChecksForPaymentTokenFee(paymentToken, totalPayment);
        IERC20(paymentToken).safeTransferFrom(msg.sender, autoGraphMinter.paymentRecipient(), totalPayment);

        ERC1155MaxSupplyMintable(nftContract).mintBatch(recipient, tokenIds, units);
        emit ERC1155BatchMinted(nftContract, recipient, tokenIds, units);
    }

    /// @dev Mint Batch of NFTs with ETH as fee
    function mintBatchWithEthAsFee(
        address nftContract,
        address recipient,
        ERC1155AutoGraphMinter.MintBatchParams[] calldata inputs
    ) external payable globalLock(1) whenNotPaused {
        _checkWhitelist(nftContract);
        (uint256[] memory tokenIds, uint256[] memory units, uint256 totalPayment) = _mintBatch(
            nftContract, recipient, address(0), inputs
        );

        _mintChecksForEthFee(totalPayment);
        (bool sent, ) = payable(autoGraphMinter.paymentRecipient()).call{value: totalPayment}("");
        require(sent, "ERC1155AutoGraphMinter: Failed to send Ether");

        ERC1155MaxSupplyMintable(nftContract).mintBatch(recipient, tokenIds, units);
        emit ERC1155BatchMinted(nftContract, recipient, tokenIds, units);
    }

    /// ------ View functions ------ ///

    /// @notice Check which items in a batch can be minted, combining supply and job checks.
    function canMintBatchFree(
        address nftContract,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        uint256[] calldata jobIds
    ) external view returns (bool[] memory mintable, uint256[] memory available) {
        require(
            tokenIds.length == amounts.length && tokenIds.length == jobIds.length,
            "ERC1155AutoGraphMinter: length mismatch"
        );

        mintable = new bool[](tokenIds.length);
        available = new uint256[](tokenIds.length);
        ERC1155MaxSupplyMintable nft = ERC1155MaxSupplyMintable(nftContract);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (completedJobs[jobIds[i]]) {
                continue;
            }

            uint256 maxSupply = nft.maxTokenSupply(tokenIds[i]);
            uint256 currentSupply = nft.totalSupply(tokenIds[i]);

            if (maxSupply == 0) {
                continue;
            }

            uint256 priorDemand = 0;
            for (uint256 j = 0; j < i; j++) {
                if (tokenIds[j] == tokenIds[i] && mintable[j]) {
                    priorDemand += amounts[j];
                }
            }

            uint256 totalAvailable = maxSupply - currentSupply;
            uint256 remaining = totalAvailable > priorDemand ? totalAvailable - priorDemand : 0;

            available[i] = remaining;
            mintable[i] = amounts[i] <= remaining;
        }
    }

    /// ------ Hashing functions ------ ///

    function getHash(ERC1155AutoGraphMinter.HashInputsParams memory input) public pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encode(
                input.recipient,
                input.jobId,
                input.tokenId,
                input.units,
                input.salt,
                input.nftContract,
                input.paymentToken,
                input.paymentAmount,
                input.expiryToken
            )
        );
        return hash.toEthSignedMessageHash();
    }

    function recoverSigner(bytes32 hash, bytes memory signature) public pure returns (address) {
        return hash.recover(signature);
    }
}
