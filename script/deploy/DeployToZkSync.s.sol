// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "@forge-std/Script.sol";
import {console2} from "@forge-std/console2.sol";
import {Token} from "@protocol/token/Token.sol";
import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";

import {Core} from "@protocol/core/Core.sol";
import {GlobalReentrancyLock} from "@protocol/core/GlobalReentrancyLock.sol";
import {ERC1155MaxSupplyMintable} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";
import {ERC1155AdminMinter} from "@protocol/nfts/ERC1155AdminMinter.sol";
import {Roles} from "@protocol/core/Roles.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ERC20Splitter} from "@protocol/finance/ERC20Splitter.sol";
import {ERC1155AutoGraphMinter} from "@protocol/nfts/ERC1155AutoGraphMinter.sol";
import {GameConsumer} from "@protocol/game/GameConsumer.sol";
import {SeasonsTokenIdRegistry} from "@protocol/nfts/seasons/SeasonsTokenIdRegistry.sol";
import {ERC1155SeasonOne} from "@protocol/nfts/seasons/ERC1155SeasonOne.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployToZkSync is Script {
    uint256 deployerPrivateKey;

    function run() external {
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        //zip000();
        //zip001();
        //zip002();
        zip003();
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
    }

    /// @dev zip004

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
