//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import {TimelockProposal} from "@forge-proposal-simulator/src/proposals/TimelockProposal.sol";

import {ERC1155MaxSupplyMintable} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";

contract zip009 is TimelockProposal {

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
        TokenIDMaxSupplyAndTransferSettings[] nonTransferableEnhanceables;
        TokenIDMaxSupplySettings[] transferableEnhanceables;
    }

    TokenIDMaxSupplySettings[] private transferableEnhanceableSettings;
    TokenIDMaxSupplyAndTransferSettings[] private nonTransferableEnhanceableSettings;

    /// @notice ERC1155 collections
    ERC1155MaxSupplyMintable enhanceable;

    /// @notice batch size for chunked calls
    uint256 private constant PROPOSAL_MAX_BATCH = 60;

    // Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "ZIP009";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "ZTX Mobile Enhanceables - maxSupply and transferability config";
    }

    function _setAndConfirmData() private {
        // Enhanceable data
        string memory data = string(
            abi.encodePacked(vm.readFile("./proposals/zips/zip009.json"))
        );

        bytes memory parsedJson = vm.parseJson(data);

        Collections memory decodedData = abi.decode(
            parsedJson,
            (Collections)
        );

        for (uint256 i = 0; i < decodedData.transferableEnhanceables.length; i++) {
            transferableEnhanceableSettings.push(
                TokenIDMaxSupplySettings(
                    decodedData.transferableEnhanceables[i].maxSupply,
                    decodedData.transferableEnhanceables[i].tokenId
                )
            );
        }

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
        assertEq(transferableEnhanceableSettings.length, 35, "Invalid transferableEnhanceableSettings length");
        assertEq(nonTransferableEnhanceableSettings.length, 25, "Invalid nonTransferableEnhanceableSettings length");

        uint transferableMaxSupplyTotal = 0;
        for (uint256 i = 0; i < transferableEnhanceableSettings.length; i++) {
            transferableMaxSupplyTotal += transferableEnhanceableSettings[i].maxSupply;
        }
        assertEq(transferableMaxSupplyTotal, 550000, "Invalid maxSupplyTotal for transferable enhanceables");

        uint nonTransferableMaxSupplyTotal = 0;
        for (uint256 i = 0; i < nonTransferableEnhanceableSettings.length; i++) {
            nonTransferableMaxSupplyTotal += nonTransferableEnhanceableSettings[i].maxSupply;
        }
        assertEq(nonTransferableMaxSupplyTotal, 25000000000, "Invalid maxSupplyTotal for non-transferable enhanceables");
    }

    /// @notice helper to call setSupplyCapBatch with chunking
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
            tokenContract.setSupplyCapBatch(ids, caps);
        }
    }

    /// @notice helper to call setSupplyCapAndNonTransferableBatch with chunking
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
            tokenContract.setSupplyCapAndNonTransferableBatch(ids, caps, flags);
        }
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER"))
    {
        /// @notice transferable enhanceables - only set maxSupply (default is transferable)
        _callSetSupplyCapBatch(enhanceable, transferableEnhanceableSettings);

        /// @notice non-transferable enhanceables - set maxSupply and isNonTransferable
        _callSetSupplyCapAndNonTransferableBatch(enhanceable, nonTransferableEnhanceableSettings);
    }

    function run() public override {
        setTimelock(addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER"));

        enhanceable = ERC1155MaxSupplyMintable(
            addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_ENHANCEABLES")
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
        /// @notice verify transferable enhanceables
        for (uint256 i = 0; i < transferableEnhanceableSettings.length; i++) {
            uint256 tokenId = transferableEnhanceableSettings[i].tokenId;
            uint256 maxSupply = transferableEnhanceableSettings[i].maxSupply;
            uint256 currentSupply = enhanceable.totalSupply(tokenId);

            assertEq(enhanceable.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(enhanceable.getMintAmountLeft(tokenId), maxSupply - currentSupply, "Invalid getMintAmountLeft for tokenId");
            assertEq(enhanceable.nonTransferableTokens(tokenId), false, "Token should be transferable");
        }

        /// @notice verify non-transferable enhanceables
        for (uint256 i = 0; i < nonTransferableEnhanceableSettings.length; i++) {
            uint256 tokenId = nonTransferableEnhanceableSettings[i].tokenId;
            uint256 maxSupply = nonTransferableEnhanceableSettings[i].maxSupply;
            bool isNonTransferable = nonTransferableEnhanceableSettings[i].isNonTransferable;
            uint256 currentSupply = enhanceable.totalSupply(tokenId);

            assertEq(enhanceable.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(enhanceable.getMintAmountLeft(tokenId), maxSupply - currentSupply, "Invalid getMintAmountLeft for tokenId");
            assertEq(enhanceable.nonTransferableTokens(tokenId), isNonTransferable, "Invalid nonTransferableTokens for tokenId");
        }
    }
}
