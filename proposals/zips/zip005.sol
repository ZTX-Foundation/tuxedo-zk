//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import {TimelockProposal} from "@forge-proposal-simulator/src/proposals/TimelockProposal.sol";

import {ERC1155MaxSupplyMintable} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";

contract zip005 is TimelockProposal {

    struct TokenIDMaxSupplySettings {
        bool isNonTransferable;
        uint256 maxSupply;
        uint256 tokenId;
    }

    struct Collections {
        TokenIDMaxSupplySettings[] wearables;
    }

    TokenIDMaxSupplySettings[] private wearableTokenIDMaxSupplySettings;

    /// @notice ERC1155 collections
    ERC1155MaxSupplyMintable wearable;

    /// @notice batch size for chunked calls
    uint256 private constant PROPOSAL_MAX_BATCH = 60;

    // Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "ZIP005";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "ZTX Mobile Wearables maxSupply and transferability config - previous common items with maxSupply updates";
    }

    function _setAndConfirmData() private {
        // Wearable data
        string memory data = string(
            abi.encodePacked(vm.readFile("./proposals/zips/zip005.json"))
        );

        bytes memory parsedJson = vm.parseJson(data);

        Collections memory decodedData = abi.decode(
            parsedJson,
            (Collections)
        );

        for (uint256 i = 0; i < decodedData.wearables.length; i++) {
            wearableTokenIDMaxSupplySettings.push(
                TokenIDMaxSupplySettings(
                    decodedData.wearables[i].isNonTransferable,
                    decodedData.wearables[i].maxSupply,
                    decodedData.wearables[i].tokenId
                )
            );
        }

        /// @notice sanity checks for wearables
        assertEq(wearableTokenIDMaxSupplySettings.length, 146, "Invalid wearableTokenIDMaxSupplySettings length");

        uint wearableMaxSupplyTotal = 0;

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearableMaxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(wearableMaxSupplyTotal, 146000000000, "Invalid maxSupplyTotal for wearables");
    }

    /// @notice helper to call setSupplyCapAndNonTransferableBatch with chunking
    function _callSetSupplyCapAndNonTransferableBatch(
        ERC1155MaxSupplyMintable tokenContract,
        TokenIDMaxSupplySettings[] storage settings
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
        /// @notice wearable config using batch API
        _callSetSupplyCapAndNonTransferableBatch(wearable, wearableTokenIDMaxSupplySettings);
    }

    function run() public override {
        setTimelock(addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER"));

        wearable = ERC1155MaxSupplyMintable(
            addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
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
        /// @notice verify wearables
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;
            bool isNonTransferable = wearableTokenIDMaxSupplySettings[i].isNonTransferable;
            uint256 currentSupply = wearable.totalSupply(tokenId);

            assertEq(wearable.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(wearable.getMintAmountLeft(tokenId), maxSupply - currentSupply, "Invalid getMintAmountLeft for tokenId");
            assertEq(wearable.nonTransferableTokens(tokenId), isNonTransferable, "Invalid nonTransferableTokens for tokenId");
        }
    }
}
