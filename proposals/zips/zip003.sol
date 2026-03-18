//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import {TimelockProposal} from "@forge-proposal-simulator/src/proposals/TimelockProposal.sol";

import {Core} from "@protocol/core/Core.sol";
import {Roles} from "@protocol/core/Roles.sol";
import {ERC1155MaxSupplyMintable} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";
import {ERC1155AutoGraphMinter} from "@protocol/nfts/ERC1155AutoGraphMinter.sol";
import {ERC1155AutoGraphBatchMinter} from "@protocol/nfts/ERC1155AutoGraphBatchMinter.sol";
import {CoreRef} from "@protocol/refs/CoreRef.sol";

contract zip003 is TimelockProposal {
    Core private _core;

    // Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "ZIP003";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "NFT collections and AutoGraph minter contracts";
    }

    function deploy() public override {
        /// Confirm Timelock has been giving the ADMIN role correctly before we start the deployment
        assertEq(_core.hasRole(Roles.ADMIN, addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")), true);

        /// NTF contracts
        /// Setup metadata base uri
        string memory _metadataBaseUri = string(
            abi.encodePacked("https://meta.", vm.envString("ENVIRONMENT"), ".", vm.envString("DOMAIN"), "/")
        );

        /// Consumables NFT contract
        ERC1155MaxSupplyMintable erc1155Consumables = new ERC1155MaxSupplyMintable(
            address(_core),
            string(abi.encodePacked(_metadataBaseUri, "consumables/metadata/")),
            "ZTX Consumables",
            "ZTXC"
        );
        addresses.addAddress("ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES", address(erc1155Consumables), true);

        /// Placeables NFT contract
        ERC1155MaxSupplyMintable erc1155Placeables = new ERC1155MaxSupplyMintable(
            address(_core),
            string(abi.encodePacked(_metadataBaseUri, "placeables/metadata/")),
            "ZTX Placeables",
            "ZTXP"
        );
        addresses.addAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES", address(erc1155Placeables), true);

        /// Enhanceables NFT contract
        ERC1155MaxSupplyMintable erc1155Enhanceables = new ERC1155MaxSupplyMintable(
            address(_core),
            string(abi.encodePacked(_metadataBaseUri, "enhanceables/metadata/")),
            "ZTX Enhanceables",
            "ZTXE"
        );
        addresses.addAddress("ERC1155_MAX_SUPPLY_MINTABLE_ENHANCEABLES", address(erc1155Enhanceables), true);

        /// AutoGraphMinter contract
        address[] memory nftContractAddresses = new address[](4);
        nftContractAddresses[0] = address(erc1155Consumables);
        nftContractAddresses[1] = address(erc1155Placeables);
        nftContractAddresses[2] = address(erc1155Enhanceables);
        nftContractAddresses[3] = addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES");

        ERC1155AutoGraphMinter erc1155AutoGraphMinter = new ERC1155AutoGraphMinter(
            address(_core),
            nftContractAddresses,
            3, // 10_800 per hour = 3 per second
            250_000, // 250_000 tokens per day
            addresses.getAddress("AUTOGRAPH_MINTER_PAYMENT_RECIPIENT"),
            1 // 1 hour expiry token timeout
        );
        addresses.addAddress("ERC1155_AUTO_GRAPH_MINTER", address(erc1155AutoGraphMinter), true);

        /// AutoGraphBatchMinter contract (batch minting extension)
        ERC1155AutoGraphBatchMinter erc1155AutoGraphBatchMinter = new ERC1155AutoGraphBatchMinter(
            address(_core),
            erc1155AutoGraphMinter,
            3, // same rate limit as single minter
            250_000 // same buffer cap
        );
        addresses.addAddress("ERC1155_AUTO_GRAPH_BATCH_MINTER", address(erc1155AutoGraphBatchMinter), true);
    }

    function build() public override buildModifier(addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")) {
        /// Grant the GUARDIAN role to the GUARDIAN_MULTISIG
        _core.grantRole(Roles.GUARDIAN, addresses.getAddress("GUARDIAN_MULTISIG"));

        /// grant protocol Locker role
        _core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES"));
        _core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES"));
        _core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_ENHANCEABLES"));
        _core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_AUTO_GRAPH_MINTER"));
        _core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_AUTO_GRAPH_BATCH_MINTER"));

        /// grant protocol minter role
        _core.grantRole(Roles.MINTER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_AUTO_GRAPH_MINTER"));
        _core.grantRole(Roles.MINTER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_AUTO_GRAPH_BATCH_MINTER"));

        /// grant minter notary role
        _core.grantRole(Roles.MINTER_NOTARY_PROTOCOL_ROLE, addresses.getAddress("AUTOGRAPH_SERVICE_KMS_WALLET"));
    }

    function run() public override {
        setTimelock(addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER"));

        /// Get Core Address
        _core = Core(addresses.getAddress("CORE"));

        super.run();
    }

    function simulate() public override {
        address multisig = addresses.getAddress("ADMIN_MULTISIG");

        /// Multisig is proposer and executor
        _simulateActions(multisig, multisig);
    }

    function validate() public override {
        /// Verify all contracts are pointing to the correct core address
        {
            assertEq(
                address(
                    ERC1155MaxSupplyMintable(addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES")).core()
                ),
                address(_core),
                "Verify ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES is pointing to the correct core address"
            );
            assertEq(
                address(
                    ERC1155MaxSupplyMintable(addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES")).core()
                ),
                address(_core),
                "Verify ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES is pointing to the correct core address"
            );
            assertEq(
                address(
                    ERC1155MaxSupplyMintable(addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_ENHANCEABLES")).core()
                ),
                address(_core),
                "Verify ERC1155_MAX_SUPPLY_MINTABLE_ENHANCEABLES is pointing to the correct core address"
            );
            assertEq(
                address(ERC1155AutoGraphMinter(addresses.getAddress("ERC1155_AUTO_GRAPH_MINTER")).core()),
                address(_core),
                "Verify ERC1155_AUTO_GRAPH_MINTER is pointing to the correct core address"
            );
            assertEq(
                address(ERC1155AutoGraphBatchMinter(addresses.getAddress("ERC1155_AUTO_GRAPH_BATCH_MINTER")).core()),
                address(_core),
                "Verify ERC1155_AUTO_GRAPH_BATCH_MINTER is pointing to the correct core address"
            );
        }

        /// Verify all roles have been assigned correcly
        {
            /// Verify LOCKER role
            assertEq(
                _core.hasRole(
                    Roles.LOCKER_PROTOCOL_ROLE,
                    addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES")
                ),
                true,
                "Verifying ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES has LOCKER role"
            );
            assertEq(
                _core.hasRole(
                    Roles.LOCKER_PROTOCOL_ROLE,
                    addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES")
                ),
                true,
                "Verifying ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES has LOCKER role"
            );
            assertEq(
                _core.hasRole(
                    Roles.LOCKER_PROTOCOL_ROLE,
                    addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_ENHANCEABLES")
                ),
                true,
                "Verifying ERC1155_MAX_SUPPLY_MINTABLE_ENHANCEABLES has LOCKER role"
            );
            assertEq(
                _core.hasRole(Roles.LOCKER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_AUTO_GRAPH_MINTER")),
                true,
                "Verifying ERC1155_AUTO_GRAPH_MINTER has LOCKER role"
            );
            assertEq(
                _core.hasRole(Roles.LOCKER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_AUTO_GRAPH_BATCH_MINTER")),
                true,
                "Verifying ERC1155_AUTO_GRAPH_BATCH_MINTER has LOCKER role"
            );

            /// Verify MINTER role
            assertEq(
                _core.hasRole(Roles.MINTER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_AUTO_GRAPH_MINTER")),
                true,
                "Verifying ERC1155_AUTO_GRAPH_MINTER has MINTER role"
            );
            assertEq(
                _core.hasRole(Roles.MINTER_PROTOCOL_ROLE, addresses.getAddress("ERC1155_AUTO_GRAPH_BATCH_MINTER")),
                true,
                "Verifying ERC1155_AUTO_GRAPH_BATCH_MINTER has MINTER role"
            );
        }

        /// Sum of Role counts to date (added 1 to each for batch minter)
        {
            assertEq(_core.getRoleMemberCount(Roles.LOCKER_PROTOCOL_ROLE), 7, "Locker role count is not 7");
            assertEq(_core.getRoleMemberCount(Roles.MINTER_PROTOCOL_ROLE), 4, "Minter role count is not 4");
        }

        /// Verify MULTISIGS have the correct roles
        {
            assertEq(
                _core.hasRole(Roles.GUARDIAN, addresses.getAddress("GUARDIAN_MULTISIG")),
                true,
                "Verify GUARDIAN Role is set on GUARDIAN_MULTISIG"
            );
            assertEq(
                _core.hasRole(Roles.ADMIN, addresses.getAddress("ADMIN_MULTISIG")),
                true,
                "Verify ADMIN Role is set on ADMIN_MULTISIG"
            );
        }

        /// Verify ERC1155AutoGraphMinter has the correct settings
        {
            ERC1155AutoGraphMinter minter = ERC1155AutoGraphMinter(addresses.getAddress("ERC1155_AUTO_GRAPH_MINTER"));
            assertEq(address(minter.core()), address(_core), "Verify minter core address");
            assertEq(
                address(minter.paymentRecipient()),
                addresses.getAddress("AUTOGRAPH_MINTER_PAYMENT_RECIPIENT"),
                "Verify minter payment recipient address"
            );
            assertEq(minter.replenishRatePerSecond(), 3, "Verify minter replenish rate per second");
            assertEq(minter.bufferCap(), 250_000, "Verify minter max tokens per day");
            assertEq(minter.buffer(), minter.bufferCap(), "Verify minter buffer == bufferCap");
            assertEq(minter.expiryTokenHoursValid(), 1, "Verify minter expiry timeout");

            /// Verify batch minter references the primary minter
            ERC1155AutoGraphBatchMinter batchMinter = ERC1155AutoGraphBatchMinter(addresses.getAddress("ERC1155_AUTO_GRAPH_BATCH_MINTER"));
            assertEq(address(batchMinter.autoGraphMinter()), address(minter), "Verify batch minter references primary minter");
            assertEq(batchMinter.replenishRatePerSecond(), 3, "Verify batch minter replenish rate per second");
            assertEq(batchMinter.bufferCap(), 250_000, "Verify batch minter max tokens per day");

            assertEq(
                minter.isWhitelistedAddress(addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")),
                true,
                "Verify ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES is whitelisted"
            );
            assertEq(
                minter.isWhitelistedAddress(addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES")),
                true,
                "Verify ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES is whitelisted"
            );
            assertEq(
                minter.isWhitelistedAddress(addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES")),
                true,
                "Verify ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES is whitelisted"
            );
            assertEq(
                minter.isWhitelistedAddress(addresses.getAddress("ERC1155_MAX_SUPPLY_MINTABLE_ENHANCEABLES")),
                true,
                "Verify ERC1155_MAX_SUPPLY_MINTABLE_ENHANCEABLES is whitelisted"
            );
        }

        /// Verify notary role
        {
            assertEq(
                _core.hasRole(Roles.MINTER_NOTARY_PROTOCOL_ROLE, addresses.getAddress("AUTOGRAPH_SERVICE_KMS_WALLET")),
                true,
                "Verifying AUTOGRAPH_SERVICE_KMS_WALLET has MINTER_NOTARY role"
            );
        }
    }
}
