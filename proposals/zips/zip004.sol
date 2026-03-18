//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import {TimelockProposal} from "@forge-proposal-simulator/src/proposals/TimelockProposal.sol";

import {ERC1155BatchOperator} from "@protocol/nfts/ERC1155BatchOperator.sol";
import {ERC1155MaxSupplyMintable} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";

contract zip004 is TimelockProposal {

    struct TokenIDMaxSupplySettings {
        uint256 maxSupply;
        uint256 tokenId;
    }

    struct TokenIDMaxSupplyAndTransferSettings {
        bool isNonTransferable;
        uint256 maxSupply;
        uint256 tokenId;
    }

    struct Collections {
        // NOTE: Fields must be in alphabetical order for vm.parseJson to work correctly
        TokenIDMaxSupplyAndTransferSettings[] nonTransferableEnhanceables;
        TokenIDMaxSupplyAndTransferSettings[] nonTransferableWearables;
        TokenIDMaxSupplySettings[] transferableEnhanceables;
        TokenIDMaxSupplySettings[] transferableWearables;
    }

    // Storage arrays for wearables
    TokenIDMaxSupplySettings[] private transferableWearableSettings;
    TokenIDMaxSupplyAndTransferSettings[] private nonTransferableWearableSettings;

    // Storage arrays for enhanceables
    TokenIDMaxSupplySettings[] private transferableEnhanceableSettings;
    TokenIDMaxSupplyAndTransferSettings[] private nonTransferableEnhanceableSettings;

    /// @notice ERC1155 collections
    ERC1155MaxSupplyMintable wearable;
    ERC1155MaxSupplyMintable enhanceable;

    /// @notice batch operator for configuring supply caps and transferability
    ERC1155BatchOperator batchOperator;

    /// @notice batch size for chunked calls
    uint256 private constant PROPOSAL_MAX_BATCH = 60;

    // Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "ZIP004";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Consolidated ZTX Mobile config - wearables and enhanceables maxSupply and transferability";
    }

    function _setAndConfirmData() private {
        // Load JSON data
        string memory data = string(
            abi.encodePacked(vm.readFile("./proposals/zips/zip004.json"))
        );

        bytes memory parsedJson = vm.parseJson(data);

        Collections memory decodedData = abi.decode(
            parsedJson,
            (Collections)
        );

        // Load transferable wearables
        for (uint256 i = 0; i < decodedData.transferableWearables.length; i++) {
            transferableWearableSettings.push(
                TokenIDMaxSupplySettings(
                    decodedData.transferableWearables[i].maxSupply,
                    decodedData.transferableWearables[i].tokenId
                )
            );
        }

        // Load non-transferable wearables
        for (uint256 i = 0; i < decodedData.nonTransferableWearables.length; i++) {
            nonTransferableWearableSettings.push(
                TokenIDMaxSupplyAndTransferSettings(
                    decodedData.nonTransferableWearables[i].isNonTransferable,
                    decodedData.nonTransferableWearables[i].maxSupply,
                    decodedData.nonTransferableWearables[i].tokenId
                )
            );
        }

        // Load transferable enhanceables
        for (uint256 i = 0; i < decodedData.transferableEnhanceables.length; i++) {
            transferableEnhanceableSettings.push(
                TokenIDMaxSupplySettings(
                    decodedData.transferableEnhanceables[i].maxSupply,
                    decodedData.transferableEnhanceables[i].tokenId
                )
            );
        }

        // Load non-transferable enhanceables
        for (uint256 i = 0; i < decodedData.nonTransferableEnhanceables.length; i++) {
            nonTransferableEnhanceableSettings.push(
                TokenIDMaxSupplyAndTransferSettings(
                    decodedData.nonTransferableEnhanceables[i].isNonTransferable,
                    decodedData.nonTransferableEnhanceables[i].maxSupply,
                    decodedData.nonTransferableEnhanceables[i].tokenId
                )
            );
        }

        /// @notice sanity checks
        assertEq(transferableWearableSettings.length, 189, "Invalid transferableWearableSettings length");
        assertEq(nonTransferableWearableSettings.length, 169, "Invalid nonTransferableWearableSettings length");
        assertEq(transferableEnhanceableSettings.length, 34, "Invalid transferableEnhanceableSettings length");
        assertEq(nonTransferableEnhanceableSettings.length, 25, "Invalid nonTransferableEnhanceableSettings length");

        // Verify max supply totals
        uint256 twTotal = 0;
        for (uint256 i = 0; i < transferableWearableSettings.length; i++) {
            twTotal += transferableWearableSettings[i].maxSupply;
        }
        assertEq(twTotal, 2475927, "Invalid maxSupplyTotal for transferable wearables");

        uint256 ntwTotal = 0;
        for (uint256 i = 0; i < nonTransferableWearableSettings.length; i++) {
            ntwTotal += nonTransferableWearableSettings[i].maxSupply;
        }
        assertEq(ntwTotal, 160000028043, "Invalid maxSupplyTotal for non-transferable wearables");

        uint256 teTotal = 0;
        for (uint256 i = 0; i < transferableEnhanceableSettings.length; i++) {
            teTotal += transferableEnhanceableSettings[i].maxSupply;
        }
        assertEq(teTotal, 530000, "Invalid maxSupplyTotal for transferable enhanceables");

        uint256 nteTotal = 0;
        for (uint256 i = 0; i < nonTransferableEnhanceableSettings.length; i++) {
            nteTotal += nonTransferableEnhanceableSettings[i].maxSupply;
        }
        assertEq(nteTotal, 25000000000, "Invalid maxSupplyTotal for non-transferable enhanceables");
    }

    /// @notice helper to call setSupplyCapBatch via the batch operator with chunking
    function _callSetSupplyCapBatch(
        ERC1155MaxSupplyMintable tokenContract,
        TokenIDMaxSupplySettings[] storage settings
    ) internal {
        uint256 total = settings.length;
        for (uint256 start = 0; start < total; start += PROPOSAL_MAX_BATCH) {
            uint256 len = total - start;
            if (len > PROPOSAL_MAX_BATCH) len = PROPOSAL_MAX_BATCH;
            uint256[] memory ids = new uint256[](len);
            uint256[] memory caps = new uint256[](len);
            for (uint256 i = 0; i < len; ++i) {
                ids[i] = settings[start + i].tokenId;
                caps[i] = settings[start + i].maxSupply;
            }
            batchOperator.setSupplyCapBatch(tokenContract, ids, caps);
        }
    }

    /// @notice helper to call setSupplyCapAndNonTransferableBatch via the batch operator with chunking
    function _callSetSupplyCapAndNonTransferableBatch(
        ERC1155MaxSupplyMintable tokenContract,
        TokenIDMaxSupplyAndTransferSettings[] storage settings
    ) internal {
        uint256 total = settings.length;
        for (uint256 start = 0; start < total; start += PROPOSAL_MAX_BATCH) {
            uint256 len = total - start;
            if (len > PROPOSAL_MAX_BATCH) len = PROPOSAL_MAX_BATCH;
            uint256[] memory ids = new uint256[](len);
            uint256[] memory caps = new uint256[](len);
            bool[] memory flags = new bool[](len);
            for (uint256 i = 0; i < len; ++i) {
                ids[i] = settings[start + i].tokenId;
                caps[i] = settings[start + i].maxSupply;
                flags[i] = settings[start + i].isNonTransferable;
            }
            batchOperator.setSupplyCapAndNonTransferableBatch(tokenContract, ids, caps, flags);
        }
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER"))
    {
        /// @notice Wearables configuration
        // Transferable wearables - only set maxSupply (default is transferable)
        _callSetSupplyCapBatch(wearable, transferableWearableSettings);
        // Non-transferable wearables - set maxSupply and isNonTransferable
        _callSetSupplyCapAndNonTransferableBatch(wearable, nonTransferableWearableSettings);

        /// @notice Enhanceables configuration
        // Transferable enhanceables - only set maxSupply (default is transferable)
        _callSetSupplyCapBatch(enhanceable, transferableEnhanceableSettings);
        // Non-transferable enhanceables - set maxSupply and isNonTransferable
        _callSetSupplyCapAndNonTransferableBatch(enhanceable, nonTransferableEnhanceableSettings);
    }

    function run() public override {
        setTimelock(addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER"));

        wearable = ERC1155MaxSupplyMintable(
            addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        enhanceable = ERC1155MaxSupplyMintable(
            addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_ENHANCEABLES")
        );

        batchOperator = ERC1155BatchOperator(
            addresses.getAddress("ERC1155_BATCH_OPERATOR")
        );

        _setAndConfirmData();

        super.run();
    }

    function simulate() public override {
        address multisig = addresses.getAddress("ADMIN_MULTISIG");

        /// Multisig is proposer and executor
        _simulateActions(multisig, multisig);
    }

    function validate() public override {
        /// @notice verify transferable wearables
        for (uint256 i = 0; i < transferableWearableSettings.length; i++) {
            uint256 tokenId = transferableWearableSettings[i].tokenId;
            uint256 maxSupply = transferableWearableSettings[i].maxSupply;
            uint256 currentSupply = wearable.totalSupply(tokenId);

            assertEq(wearable.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for wearable tokenId");
            assertEq(wearable.getMintAmountLeft(tokenId), maxSupply - currentSupply, "Invalid getMintAmountLeft for wearable tokenId");
        }

        /// @notice verify non-transferable wearables
        for (uint256 i = 0; i < nonTransferableWearableSettings.length; i++) {
            uint256 tokenId = nonTransferableWearableSettings[i].tokenId;
            uint256 maxSupply = nonTransferableWearableSettings[i].maxSupply;
            bool isNonTransferable = nonTransferableWearableSettings[i].isNonTransferable;
            uint256 currentSupply = wearable.totalSupply(tokenId);

            assertEq(wearable.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for wearable tokenId");
            assertEq(wearable.getMintAmountLeft(tokenId), maxSupply - currentSupply, "Invalid getMintAmountLeft for wearable tokenId");
            assertEq(wearable.nonTransferableTokens(tokenId), isNonTransferable, "Invalid nonTransferableTokens for wearable tokenId");
        }

        /// @notice verify transferable enhanceables
        for (uint256 i = 0; i < transferableEnhanceableSettings.length; i++) {
            uint256 tokenId = transferableEnhanceableSettings[i].tokenId;
            uint256 maxSupply = transferableEnhanceableSettings[i].maxSupply;
            uint256 currentSupply = enhanceable.totalSupply(tokenId);

            assertEq(enhanceable.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for enhanceable tokenId");
            assertEq(enhanceable.getMintAmountLeft(tokenId), maxSupply - currentSupply, "Invalid getMintAmountLeft for enhanceable tokenId");
            assertEq(enhanceable.nonTransferableTokens(tokenId), false, "Enhanceable token should be transferable");
        }

        /// @notice verify non-transferable enhanceables
        for (uint256 i = 0; i < nonTransferableEnhanceableSettings.length; i++) {
            uint256 tokenId = nonTransferableEnhanceableSettings[i].tokenId;
            uint256 maxSupply = nonTransferableEnhanceableSettings[i].maxSupply;
            bool isNonTransferable = nonTransferableEnhanceableSettings[i].isNonTransferable;
            uint256 currentSupply = enhanceable.totalSupply(tokenId);

            assertEq(enhanceable.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for enhanceable tokenId");
            assertEq(enhanceable.getMintAmountLeft(tokenId), maxSupply - currentSupply, "Invalid getMintAmountLeft for enhanceable tokenId");
            assertEq(enhanceable.nonTransferableTokens(tokenId), isNonTransferable, "Invalid nonTransferableTokens for enhanceable tokenId");
        }
    }
}
