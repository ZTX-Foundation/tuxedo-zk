// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";
import {Script} from "@forge-std/Script.sol";
import {console2} from "@forge-std/console2.sol";

import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";

import {Core} from "@protocol/core/Core.sol";
import {Roles} from "@protocol/core/Roles.sol";
import {Token} from "@protocol/token/Token.sol";
import {CoreRef} from "@protocol/refs/CoreRef.sol";
import {GameConsumer} from "@protocol/game/GameConsumer.sol";
import {ERC20Splitter} from "@protocol/finance/ERC20Splitter.sol";
import {ERC1155AdminMinter} from "@protocol/nfts/ERC1155AdminMinter.sol";
import {TokenIdRewardAmount} from "@protocol/nfts/seasons/SeasonsBase.sol";
import {ERC1155SeasonOne} from "@protocol/nfts/seasons/ERC1155SeasonOne.sol";
import {GlobalReentrancyLock} from "@protocol/core/GlobalReentrancyLock.sol";
import {ERC1155AutoGraphMinter} from "@protocol/nfts/ERC1155AutoGraphMinter.sol";
import {ERC1155MaxSupplyMintable} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";
import {SeasonsTokenIdRegistry} from "@protocol/nfts/seasons/SeasonsTokenIdRegistry.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployToZkSync is Script, Test {
    uint256 deployerPrivateKey;

    /// @dev TokenIDMaxSupplySettings
    struct TokenIDMaxSupplySettings {
        uint256 tokenId;
        uint256 maxSupply;
    }

    /// @dev run
    function run() external {
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        //zip000();
        //zip001();
        //zip002();
        //zip003();
        zip004();
    }

    /// @dev Check if a string is empty
    function isEmpty(string memory str) internal pure returns (bool) {
        return bytes(str).length == 0;
    }

    /// @dev zip000
    /// @dev TOKEN_NAME
    /// @dev TOKEN_SYMBOL
    /// @dev TREASURY_WALLET_MULTISIG
    /// @dev MAX_SUPPLY
    function zip000() internal {
        if (
            isEmpty(vm.envString("TOKEN_NAME")) ||
            isEmpty(vm.envString("TOKEN_SYMBOL")) ||
            vm.envAddress("TREASURY_WALLET_MULTISIG") == address(0) ||
            vm.envUint("MAX_SUPPLY") == 0
        ) {
            console2.log("zip000: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Token deployment
        Token token = new Token(
            string(abi.encodePacked(vm.envString("TOKEN_NAME"))),
            string(abi.encodePacked(vm.envString("TOKEN_SYMBOL")))
        );

        /// @dev Token transfer
        IERC20(address(token)).transfer(vm.envAddress("TREASURY_WALLET_MULTISIG"), vm.envUint("MAX_SUPPLY"));

        console2.log("Token deployed at:", address(token));
        vm.stopBroadcast();

        assertEq(
            IERC20(address(token)).balanceOf(vm.envAddress("TREASURY_WALLET_MULTISIG")),
            10_000_000_000e18 // hardcoded to Verify all code is working
        );
    }

    /// @dev zip001
    /// @dev ENVIRONMENT
    /// @dev DOMAIN
    /// @dev ADMIN_MULTISIG
    function zip001() internal {
        if (
            isEmpty(vm.envString("ENVIRONMENT")) ||
            isEmpty(vm.envString("DOMAIN")) ||
            vm.envAddress("ADMIN_MULTISIG") == address(0)
        ) {
            console2.log("zip001: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        Core _core = new Core();
        console2.log("Core deployed at:", address(_core));

        /// @dev GlobalReentrancyLock
        GlobalReentrancyLock globalReentrancyLock = new GlobalReentrancyLock(address(_core));
        console2.log("GlobalReentrancyLock deployed at:", address(globalReentrancyLock));

        /// @dev NTF contracts
        /// @dev Setup metadata base uri
        string memory _metadataBaseUri = string(
            abi.encodePacked("https://meta.", vm.envString("ENVIRONMENT"), ".", vm.envString("DOMAIN"), "/")
        );

        /// @dev Wearables NFT contract
        ERC1155MaxSupplyMintable erc1155Wearables = new ERC1155MaxSupplyMintable(
            address(_core),
            string(abi.encodePacked(_metadataBaseUri, "wearables/metadata/")),
            "ZTX Wearables",
            "ZTXW"
        );

        console2.log("ERC1155MaxSupplyMintable deployed at:", address(erc1155Wearables));

        ERC1155AdminMinter minter = new ERC1155AdminMinter(address(_core));
        console2.log("ERC1155AdminMinter deployed at:", address(minter));

        /// @dev Setup ADMIN_MULTISIG
        _core.grantRole(Roles.ADMIN, vm.envAddress("ADMIN_MULTISIG"));

        /// @dev Set global lock
        _core.setGlobalLock(address(globalReentrancyLock));

        /// @dev Set LOCKER role for all NFT minting contracts
        _core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, address(erc1155Wearables));
        _core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, address(minter));

        /// @dev Set MINTER role for all NFT minting contracts
        _core.grantRole(Roles.MINTER_PROTOCOL_ROLE, address(erc1155Wearables));
        _core.grantRole(Roles.MINTER_PROTOCOL_ROLE, address(minter));

        vm.stopBroadcast();

        assertEq(_core.hasRole(Roles.ADMIN, vm.envAddress("ADMIN_MULTISIG")), true, "incorrect admin role");

        /// @dev Verify all contracts are pointing to the correct core address
        assertEq(
            address(GlobalReentrancyLock(address(globalReentrancyLock)).core()),
            address(_core),
            "incorrect core address global reentrancy lock"
        );
        assertEq(
            address(ERC1155AdminMinter(address(minter)).core()),
            address(_core),
            "incorrect core address admin minter"
        );

        assertEq(
            address(ERC1155MaxSupplyMintable(address(erc1155Wearables)).core()),
            address(_core),
            "incorrect core address erc1155 max supply mintable wearables"
        );

        /// @dev Verifiy CoreRef
        assertEq(
            address(CoreRef(address(globalReentrancyLock)).core()),
            address(_core),
            "incorrect core address global reentrancy lock"
        );

        assertEq(
            address(CoreRef(address(erc1155Wearables)).core()),
            address(_core),
            "incorrect core address erc1155 max supply mintable wearables"
        );

        /// @dev Verify globlal lock has been set correctly
        assertEq(address(_core.lock()), address(globalReentrancyLock), "incorrect global lock");

        /// @dev Verify metadata URI
        assertEq(
            ERC1155MaxSupplyMintable(address(erc1155Wearables)).uri(0),
            string(
                abi.encodePacked(
                    "https://meta.",
                    vm.envString("ENVIRONMENT"),
                    ".",
                    vm.envString("DOMAIN"),
                    "/wearables/metadata/0"
                )
            ),
            "incorrect metadata URI"
        );

        /// @dev Verify all roles have been assigned correcly
        /// @dev Verify LOCKER role
        assertTrue(_core.hasRole(Roles.LOCKER_PROTOCOL_ROLE, address(erc1155Wearables)), "incorrect locker wearables");
        assertTrue(_core.hasRole(Roles.LOCKER_PROTOCOL_ROLE, address(minter)), "incorrect locker admin minter");

        /// @dev Verify MINTER role
        assertTrue(_core.hasRole(Roles.MINTER_PROTOCOL_ROLE, address(erc1155Wearables)), "incorrect minter wearables");
        assertTrue(_core.hasRole(Roles.MINTER_PROTOCOL_ROLE, address(minter)), "incorrect minter admin minter");

        /// @dev Sum of Role counts to date
        assertEq(_core.getRoleMemberCount(Roles.LOCKER_PROTOCOL_ROLE), 2, "incorrect locker count");
        assertEq(_core.getRoleMemberCount(Roles.MINTER_PROTOCOL_ROLE), 2, "incorrect minter count");

        /// @dev Verify ADMIN count
        assertEq(_core.getRoleMemberCount(Roles.ADMIN), 2, "incorrect admin count");
    }

    /// @dev zip002
    /// @dev CORE
    /// @dev ADMIN_MULTISIG
    function zip002() internal {
        if (vm.envAddress("CORE") == address(0) || vm.envAddress("ADMIN_MULTISIG") == address(0)) {
            console2.log("zip002: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        Core _core = Core(vm.envAddress("CORE"));

        address[] memory adminTimelockProposersExecutors = new address[](1);

        adminTimelockProposersExecutors[0] = address(vm.envAddress("ADMIN_MULTISIG"));
        TimelockController _adminTimelock = new TimelockController(
            0, // zero delay
            adminTimelockProposersExecutors,
            adminTimelockProposersExecutors,
            address(0) // No admin requried
        );
        console2.log("TimelockController deployed at:", address(_adminTimelock));

        _core.grantRole(Roles.ADMIN, address(_adminTimelock));
        console2.log("Please give Roles.Admin to the ADMIN_TIMELOCK_CONTROLLER from the ADMIN_MULTISIG");

        vm.stopBroadcast();

        /// @dev Check that the ADMIN_MULTISIG has the PROPOSER role
        assertEq(
            _adminTimelock.hasRole(_adminTimelock.PROPOSER_ROLE(), vm.envAddress("ADMIN_MULTISIG")),
            true,
            "ADMIN_MULTISIG does not have PROPOSER_ROLE"
        );

        /// @dev Check that the ADMIN_MULTISIG has the EXECUTOR role
        assertEq(
            _adminTimelock.hasRole(_adminTimelock.EXECUTOR_ROLE(), vm.envAddress("ADMIN_MULTISIG")),
            true,
            "ADMIN_MULTISIG does not have EXECUTOR_ROLE"
        );

        /// @dev Check that the ADMIN_MULTISIG has the CANCELLER rol`e
        assertEq(
            _adminTimelock.hasRole(_adminTimelock.CANCELLER_ROLE(), vm.envAddress("ADMIN_MULTISIG")),
            true,
            "ADMIN_MULTISIG does not have CANCELLER_ROLE"
        );
    }

    /// @dev zip003
    /// @dev CORE
    /// @dev ENVIRONMENT
    /// @dev DOMAIN
    /// @dev REVENUE_WALLET_MULTISIG01
    /// @dev REVENUE_WALLET_MULTISIG02
    /// @dev TOKEN
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    /// @dev AUTOGRAPH_MINTER_PAYMENT_RECIPIENT
    /// @dev WETH
    /// @dev GUARDIAN_MULTISIG
    /// @dev AUTOGRAPH_SERVICE_KMS_WALLET
    function zip003() internal {
        if (
            vm.envAddress("CORE") == address(0) ||
            isEmpty(vm.envString("ENVIRONMENT")) ||
            isEmpty(vm.envString("DOMAIN")) ||
            vm.envAddress("REVENUE_WALLET_MULTISIG01") == address(0) ||
            vm.envAddress("REVENUE_WALLET_MULTISIG02") == address(0) ||
            vm.envAddress("TOKEN") == address(0) ||
            vm.envAddress("AUTOGRAPH_MINTER_PAYMENT_RECIPIENT") == address(0) ||
            vm.envAddress("WETH") == address(0) ||
            vm.envAddress("GUARDIAN_MULTISIG") == address(0) ||
            vm.envAddress("AUTOGRAPH_SERVICE_KMS_WALLET") == address(0)
        ) {
            console2.log("zip003: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        Core _core = Core(vm.envAddress("CORE"));

        /// @dev NTF contracts
        /// @dev Setup metadata base uri
        string memory _metadataBaseUri = string(
            abi.encodePacked("https://meta.", vm.envString("ENVIRONMENT"), ".", vm.envString("DOMAIN"), "/")
        );

        /// @dev Consumables NFT contract
        ERC1155MaxSupplyMintable erc1155Consumables = new ERC1155MaxSupplyMintable(
            address(_core),
            string(abi.encodePacked(_metadataBaseUri, "consumables/metadata/")),
            "ZTX Consumables",
            "ZTXC"
        );
        console2.log("ERC1155MaxSupplyMintable deployed at:", address(erc1155Consumables));

        /// @dev Placeables NFT contract
        ERC1155MaxSupplyMintable erc1155Placeables = new ERC1155MaxSupplyMintable(
            address(_core),
            string(abi.encodePacked(_metadataBaseUri, "placeables/metadata/")),
            "ZTX Placeables",
            "ZTXP"
        );
        console2.log("ERC1155MaxSupplyMintable deployed at:", address(erc1155Placeables));

        /// ERC20Splitter allocation settings
        ERC20Splitter.Allocation[] memory allocations = new ERC20Splitter.Allocation[](2);
        allocations[0].deposit = address(vm.envAddress("REVENUE_WALLET_MULTISIG01"));
        allocations[0].ratio = 5_000;
        allocations[1].deposit = address(vm.envAddress("REVENUE_WALLET_MULTISIG02"));
        allocations[1].ratio = 5_000;

        /// @dev ERC20Splitter consumable splitter contract
        ERC20Splitter consumableSplitter = new ERC20Splitter(
            address(_core),
            address(vm.envAddress("TOKEN")),
            allocations
        );
        console2.log("ERC20Splitter deployed at:", address(consumableSplitter));

        /// @dev AutoGraphMinter contract
        address[] memory nftContractAddresses = new address[](3);
        nftContractAddresses[0] = address(erc1155Consumables);
        nftContractAddresses[1] = address(erc1155Placeables);
        nftContractAddresses[2] = address(vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES"));

        ERC1155AutoGraphMinter erc1155AutoGraphMinter = new ERC1155AutoGraphMinter(
            address(_core),
            nftContractAddresses,
            3, // 10_800 per hour = 3 per second
            250_000, // 250_000 tokens per day
            address(vm.envAddress("AUTOGRAPH_MINTER_PAYMENT_RECIPIENT")),
            1 // 1 hour expiry token timeout
        );
        console2.log("ERC1155AutoGraphMinter deployed at:", address(erc1155AutoGraphMinter));

        /// @dev Game consumer
        GameConsumer gameConsumer = new GameConsumer(
            address(vm.envAddress("CORE")),
            address(vm.envAddress("TOKEN")),
            address(consumableSplitter),
            address(vm.envAddress("WETH"))
        );
        console2.log("GameConsumer deployed at:", address(gameConsumer));

        /// @dev SeasonsTokenIdRegistry contract
        SeasonsTokenIdRegistry seasonsTokenIdRegistry = new SeasonsTokenIdRegistry(address(_core));
        console2.log("SeasonsTokenIdRegistry deployed at:", address(seasonsTokenIdRegistry));

        /// @dev Season contracts (Season 1)
        ERC1155SeasonOne erc1155SeasonOne = new ERC1155SeasonOne(
            address(_core),
            address(erc1155Consumables),
            address(vm.envAddress("TOKEN")),
            address(seasonsTokenIdRegistry)
        );
        console2.log("ERC1155SeasonOne deployed at:", address(erc1155SeasonOne));

        /// @dev Grant the GUARDIAN role to the GUARDIAN_MULTISIG
        _core.grantRole(Roles.GUARDIAN, address(vm.envAddress("GUARDIAN_MULTISIG")));

        /// @dev grant protocol Locker role
        _core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, address(erc1155Consumables));
        _core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, address(erc1155Placeables));
        _core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, address(erc1155AutoGraphMinter));

        /// @dev grant protocol minter role
        _core.grantRole(Roles.MINTER_PROTOCOL_ROLE, address(erc1155AutoGraphMinter));

        /// @dev grant registry operator role
        _core.grantRole(Roles.REGISTRY_OPERATOR_PROTOCOL_ROLE, address(erc1155SeasonOne));

        /// @dev grant minter notary role
        _core.grantRole(Roles.MINTER_NOTARY_PROTOCOL_ROLE, address(vm.envAddress("AUTOGRAPH_SERVICE_KMS_WALLET")));

        /// @dev grant game consumer notary protocol role
        _core.grantRole(
            Roles.GAME_CONSUMER_NOTARY_PROTOCOL_ROLE,
            address(vm.envAddress("AUTOGRAPH_SERVICE_KMS_WALLET"))
        );

        vm.stopBroadcast();

        {
            assertEq(
                address(ERC1155MaxSupplyMintable(address(erc1155Consumables)).core()),
                address(_core),
                "Verify ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES is pointing to the correct core address"
            );
            assertEq(
                address(ERC1155MaxSupplyMintable(address(erc1155Placeables)).core()),
                address(_core),
                "Verify ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES is pointing to the correct core address"
            );
            assertEq(
                address(ERC1155AutoGraphMinter(address(erc1155AutoGraphMinter)).core()),
                address(_core),
                "Verify ERC1155_AUTO_GRAPH_MINTER is pointing to the correct core address"
            );
            assertEq(
                address(CoreRef(address(gameConsumer)).core()),
                address(_core),
                "Verify GAME_CONSUMABLE is pointing to the correct core address"
            );
        }

        /// @dev Verify all roles have been assigned correcly
        {
            /// @dev Verify LOCKER role
            assertEq(
                _core.hasRole(Roles.LOCKER_PROTOCOL_ROLE, address(erc1155Consumables)),
                true,
                "Verifying ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES has LOCKER role"
            );
            assertEq(
                _core.hasRole(Roles.LOCKER_PROTOCOL_ROLE, address(erc1155Placeables)),
                true,
                "Verifying ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES has LOCKER role"
            );
            assertEq(
                _core.hasRole(Roles.LOCKER_PROTOCOL_ROLE, address(erc1155AutoGraphMinter)),
                true,
                "Verifying ERC1155_AUTO_GRAPH_MINTER has LOCKER role"
            );

            /// @dev Verify MINTER role
            assertEq(
                _core.hasRole(Roles.MINTER_PROTOCOL_ROLE, address(erc1155AutoGraphMinter)),
                true,
                "Verifying ERC1155_AUTO_GRAPH_MINTER has MINTER role"
            );
        }

        /// @dev Verify REGISTRY_OPERATOR role
        {
            assertEq(
                _core.hasRole(Roles.REGISTRY_OPERATOR_PROTOCOL_ROLE, address(erc1155SeasonOne)),
                true,
                "Verifying ERC1155_SEASON_ONE has REGISTRY_OPERATOR role"
            );
        }

        /// @dev Sum of Role counts to date
        {
            /// @dev TODO: fix this
            //assertEq(_core.getRoleMemberCount(Roles.LOCKER_PROTOCOL_ROLE), 5, "Locker role count is not 5");
            //assertEq(_core.getRoleMemberCount(Roles.MINTER_PROTOCOL_ROLE), 3, "Minter role count is not 3");
        }

        /// @dev Verify MULTISIGS have the correct roles
        {
            assertEq(
                _core.hasRole(Roles.GUARDIAN, vm.envAddress("GUARDIAN_MULTISIG")),
                true,
                "Verify GUARDIAN Role is set on GUARDIAN_MULTISIG"
            );
            assertEq(
                _core.hasRole(Roles.ADMIN, vm.envAddress("ADMIN_MULTISIG")),
                true,
                "Verify ADMIN Role is set on ADMIN_MULTISIG"
            );
        }

        /// @dev verify ERC20Splitter has the correct settings
        {
            ERC20Splitter splitter = ERC20Splitter(address(consumableSplitter));
            assertEq(address(splitter.token()), vm.envAddress("TOKEN"), "Verify splitter token address");

            (address address0, uint ratio0) = splitter.allocations(0);
            (address address1, uint ratio1) = splitter.allocations(1);

            assertEq(address0, vm.envAddress("REVENUE_WALLET_MULTISIG01"));
            assertEq(ratio0, 5_000);
            assertEq(address1, vm.envAddress("REVENUE_WALLET_MULTISIG02"));
            assertEq(ratio1, 5_000);
        }

        /// @dev verify ERC1155AutoGraphMinter has the correct settings
        {
            ERC1155AutoGraphMinter minter = ERC1155AutoGraphMinter(address(erc1155AutoGraphMinter));
            assertEq(address(minter.core()), address(_core), "Verify minter core address");
            assertEq(
                address(minter.paymentRecipient()),
                vm.envAddress("AUTOGRAPH_MINTER_PAYMENT_RECIPIENT"),
                "Verify minter payment recipient address"
            );
            assertEq(minter.replenishRatePerSecond(), 3, "Verify minter replenish rate per second");
            assertEq(minter.bufferCap(), 250_000, "Verify minter max tokens per day");
            assertEq(minter.buffer(), minter.bufferCap(), "Verify minter buffer == bufferCap");
            assertEq(minter.expiryTokenHoursValid(), 1, "Verify minter expiry timeout");

            assertEq(
                minter.isWhitelistedAddress(vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")),
                true,
                "Verify ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES is whitelisted"
            );
            assertEq(
                minter.isWhitelistedAddress(address(erc1155Consumables)),
                true,
                "Verify ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES is whitelisted"
            );
            assertEq(
                minter.isWhitelistedAddress(address(erc1155Placeables)),
                true,
                "Verify ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES is whitelisted"
            );

            /// Verify Game consumable
            ERC20Splitter.Allocation[] memory consumableAllocations = ERC20Splitter(address(consumableSplitter))
                .getAllocations();

            assertEq(consumableAllocations.length, 2, "Consumable allocations length is not equal to 2");
            assertEq(
                consumableAllocations[0].deposit,
                vm.envAddress("REVENUE_WALLET_MULTISIG01"),
                "Consumable allocation deposit is not equal to REVENUE_WALLET_MULTISIG01"
            );
            assertEq(consumableAllocations[0].ratio, 5_000, "Consumable allocation ratio is not equal to 5_000");
            assertEq(
                consumableAllocations[1].deposit,
                vm.envAddress("REVENUE_WALLET_MULTISIG02"),
                "Consumable allocation deposit is not equal to REVENUE_WALLET_MULTISIG02"
            );
            assertEq(consumableAllocations[1].ratio, 5_000, "Consumable allocation ratio is not equal to 5_000");

            assertEq(
                address(ERC20Splitter(address(consumableSplitter)).core()),
                address(_core),
                "CONSUMABLE_SPLITTER is pointing to wrong core"
            );
        }

        /// Verify notary roles
        {
            assertEq(
                _core.hasRole(Roles.MINTER_NOTARY_PROTOCOL_ROLE, vm.envAddress("AUTOGRAPH_SERVICE_KMS_WALLET")),
                true,
                "Verifying AUTOGRAPH_SERVICE_KMS_WALLET has MINTER_NOTARY role"
            );

            assertEq(
                _core.hasRole(Roles.GAME_CONSUMER_NOTARY_PROTOCOL_ROLE, vm.envAddress("AUTOGRAPH_SERVICE_KMS_WALLET")),
                true,
                "Verifying AUTOGRAPH_SERVICE_KMS_WALLET has GAME_CONSUMER_NOTARY role"
            );
        }
    }

    TokenIDMaxSupplySettings[] public placeableTokenIDMaxSupplySettings;
    TokenIDMaxSupplySettings[] public wearableTokenIDMaxSupplySettings;
    TokenIDMaxSupplySettings[] public consumableTokenIDMaxSupplySettings;
    TokenIdRewardAmount[] public tokenIdRewardAmounts;

    /// @dev zip004
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES
    /// @dev ERC1155_SEASON_ONE
    function zip004() internal {
        if (
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES") == address(0) ||
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0) ||
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES") == address(0) ||
            vm.envAddress("ERC1155_SEASON_ONE") == address(0)
        ) {
            console2.log("Missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev placeable max supply settings
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(1, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(4, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(12, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(14, 2500));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(17, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(21, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(27, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(28, 50));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(31, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(43, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(45, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(60, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(64, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(65, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(67, 2500));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(69, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(70, 50));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(72, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(74, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(76, 1000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(82, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(90, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(94, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(96, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(106, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(107, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(111, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(124, 500));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(129, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(149, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(152, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(153, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(154, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(156, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(161, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(163, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(167, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(170, 1000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(175, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(179, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(182, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(184, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(187, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(190, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(193, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(201, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(206, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(214, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(235, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(239, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(240, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(244, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(247, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(249, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(252, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(258, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(262, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(267, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(279, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(284, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(288, 500));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(292, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(294, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(300, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(302, 100_000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(303, 2500));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(314, 2500));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(325, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(329, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(331, 50));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(334, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(335, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(336, 2500));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(337, 1000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(338, 50));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(339, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(340, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(341, 2500));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(342, 1000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(343, 500));

        uint tokenIDTotal = 0;
        uint maxSupplyTotal = 0;

        /// @dev sum numbers from requrements sheet
        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            tokenIDTotal += placeableTokenIDMaxSupplySettings[i].tokenId;
            maxSupplyTotal += placeableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(tokenIDTotal, 14_654, "Invalid tokenIDTotal");
        assertEq(maxSupplyTotal, 3_852_700, "Invalid maxSupplyTotal");

        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(1, 100_000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(2, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(3, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(4, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(5, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(6, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(8, 500));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(9, 500));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(10, 500));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(11, 100_000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(12, 100_000));

        /// @dev sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 11, "Invalid wearableTokenIDMaxSupplySettings length");

        tokenIDTotal = 0;
        maxSupplyTotal = 0;

        /// @dev sum numbers from requrements sheet
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            tokenIDTotal += wearableTokenIDMaxSupplySettings[i].tokenId;
            maxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(tokenIDTotal, 71, "Invalid tokenIDTotal");
        assertEq(maxSupplyTotal, 331500, "Invalid maxSupplyTotal");

        consumableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(1, 15_000));
        consumableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(2, 5538));
        consumableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(3, 2025));

        /// @dev sanity checks
        assertEq(consumableTokenIDMaxSupplySettings.length, 3, "Invalid consumableTokenIDMaxSupplySettings length");

        tokenIDTotal = 0;
        maxSupplyTotal = 0;

        /// @dev sum numbers from requrements sheet
        for (uint256 i = 0; i < consumableTokenIDMaxSupplySettings.length; i++) {
            tokenIDTotal += consumableTokenIDMaxSupplySettings[i].tokenId;
            maxSupplyTotal += consumableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(tokenIDTotal, 6, "Invalid tokenIDTotal");
        assertEq(maxSupplyTotal, 22_563, "Invalid maxSupplyTotal");

        /// @dev config the season distribution
        tokenIdRewardAmounts.push(TokenIdRewardAmount({tokenId: 1, rewardAmount: 300e18}));
        tokenIdRewardAmounts.push(TokenIdRewardAmount({tokenId: 2, rewardAmount: 2167e18}));
        tokenIdRewardAmounts.push(TokenIdRewardAmount({tokenId: 3, rewardAmount: 6667e18}));

        /// @dev sanity checks
        assertEq(tokenIdRewardAmounts.length, 3, "Invalid tokenIdRewardAmounts length");

        tokenIDTotal = 0;
        uint rewardAmountTotal = 0;

        /// @dev sum numbers from requrements sheet
        for (uint256 i = 0; i < tokenIdRewardAmounts.length; i++) {
            tokenIDTotal += tokenIdRewardAmounts[i].tokenId;
            rewardAmountTotal += tokenIdRewardAmounts[i].rewardAmount;
        }

        assertEq(tokenIDTotal, 6, "Invalid tokenIDTotal");
        assertEq(rewardAmountTotal, 9134e18, "Invalid rewardAmountTotal"); // numbers from santiy check sheet

        ERC1155MaxSupplyMintable placeable = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES")
        );

        /// @dev Placeables config
        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            placeable.setSupplyCap(
                placeableTokenIDMaxSupplySettings[i].tokenId,
                placeableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        /// @dev Wearables config
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearables.setSupplyCap(
                wearableTokenIDMaxSupplySettings[i].tokenId,
                wearableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        ERC1155MaxSupplyMintable consumables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_CONSUMABLES")
        );

        /// @dev Consumables config
        for (uint256 i = 0; i < consumableTokenIDMaxSupplySettings.length; i++) {
            consumables.setSupplyCap(
                consumableTokenIDMaxSupplySettings[i].tokenId,
                consumableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Season One config
        ERC1155SeasonOne seasonOne = ERC1155SeasonOne(vm.envAddress("ERC1155_SEASON_ONE"));
        seasonOne.initalizeSeasonDistribution(tokenIdRewardAmounts);

        /// @dev Verify Placeable
        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            uint256 placeableTokenId = placeableTokenIDMaxSupplySettings[i].tokenId;
            uint256 placeableMaxSupply = placeableTokenIDMaxSupplySettings[i].maxSupply;

            assertEq(placeable.maxTokenSupply(placeableTokenId), placeableMaxSupply, "Invalid getMintAmountLeft for tokenId");
            assertEq(placeable.getMintAmountLeft(placeableTokenId), placeableMaxSupply, "Invalid getMintAmountLeft for tokenId");
        }

        /// @dev Verify Wearable
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 wearableTokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 wearableMaxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;

            assertEq(wearables.maxTokenSupply(wearableTokenId), wearableMaxSupply, "Invalid getMintAmountLeft for tokenId");
            assertEq(wearables.getMintAmountLeft(wearableTokenId), wearableMaxSupply, "Invalid getMintAmountLeft for tokenId");
        }

        /// @dev Verify Consumable
        for (uint256 i = 0; i < consumableTokenIDMaxSupplySettings.length; i++) {
            uint256 consumableTokenId = consumableTokenIDMaxSupplySettings[i].tokenId;
            uint256 consumableMaxSupply = consumableTokenIDMaxSupplySettings[i].maxSupply;

            assertEq(consumables.maxTokenSupply(consumableTokenId), consumableMaxSupply, "Invalid getMintAmountLeft for tokenId");
            assertEq(consumables.getMintAmountLeft(consumableTokenId), consumableMaxSupply, "Invalid getMintAmountLeft for tokenId");
        }

        /// @dev Verify Season One
        assertEq(seasonOne.totalRewardTokens(), 30001521e18, "Invalid totalRewardTokens");
        assertEq(seasonOne.totalRewardTokensUsed(), 0, "Invalid totalRewardTokensUsed");
        assertEq(seasonOne.totalClawedBack(), 0, "Invalid totalClawedBack");

        for (uint256 i = 0; i < tokenIdRewardAmounts.length; i++) {
            uint256 seasonOneTokenId = tokenIdRewardAmounts[i].tokenId;
            uint256 seasonOneRewardAmount = tokenIdRewardAmounts[i].rewardAmount;

            assertEq(seasonOne.tokenIdRewardAmount(seasonOneTokenId), seasonOneRewardAmount, "Invalid tokenIdRewardAmount");
            assertEq(seasonOne.tokenIdUsedAmount(seasonOneTokenId), 0, "Invalid tokenIdUsedAmount");
        }

        vm.stopBroadcast();
    }

    /// @dev zip005

    /// @dev zip006

    /// @dev zip007

    /// @dev zip008

    /// @dev zip009

    /// @dev zip010

    /// @dev zip011

    /// @dev zip012

    /// @dev zip013

    /// @dev zip014

    /// @dev zip016

    /// @dev zip017

    /// @dev zip018

    /// @dev zip019
}
