//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import {TimelockProposal} from "@forge-proposal-simulator/src/proposals/TimelockProposal.sol";

import {ERC1155MaxSupplyMintable} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";

contract zip004 is TimelockProposal {

    struct TokenIDMaxSupplySettings {
        uint256 maxSupply;
        uint256 tokenId;
    }

    struct Collections {
        TokenIDMaxSupplySettings[] wearables;
    }

    TokenIDMaxSupplySettings[] private wearableTokenIDMaxSupplySettings;

    /// @notice ERC1155 collections
    ERC1155MaxSupplyMintable wearable;

    // Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "ZIP005";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "ZTX Wearables tokenIds and MaxSupply config proposal - consolidates all historical wearable supplies - part 2";
    }

    function _setAndConfirmData() private {
        // Wearable and placeable data
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
                    decodedData.wearables[i].maxSupply,
                    decodedData.wearables[i].tokenId
                )
            );
        }

        /// @notice sanity checks for wearables
        assertEq(wearableTokenIDMaxSupplySettings.length, 30, "Invalid wearableTokenIDMaxSupplySettings length");

        uint wearableMaxSupplyTotal = 0;

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearableMaxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(wearableMaxSupplyTotal, 2612144, "Invalid maxSupplyTotal for wearables");
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER"))
    {
        /// @notice wearable config
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearable.setSupplyCap(wearableTokenIDMaxSupplySettings[i].tokenId, wearableTokenIDMaxSupplySettings[i].maxSupply);
        }
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
            uint256 currentSupply = wearable.totalSupply(tokenId);

            assertEq(wearable.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(wearable.getMintAmountLeft(tokenId), maxSupply - currentSupply, "Invalid getMintAmountLeft for tokenId");
        }
    }
}
