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
        //zip004();
        //zip005();
        //zip006();
        //zip007();
        //zip008();
        //zip009();
        //zip010();
        //zip011();
        //zip012();
        //zip013();
        //zip014();
        //zip016();
        //zip017();
        //zip018();
        //zip019();
        //zip020();
        zip021();
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
    /// @dev ENVIRONMENT
    /// @dev CORE
    /// @dev ADMIN_MULTISIG
    function zip002() internal {
        if (
            vm.envAddress("CORE") == address(0) ||
            vm.envAddress("ADMIN_MULTISIG") == address(0)
        ) {
            console2.log("zip002: missing environment variables");
            return;
        }

        /// @dev Check if the environment is mainnet
        bool isMainnet = keccak256(bytes(vm.envString("ENVIRONMENT"))) == keccak256(bytes("mainnet"));
        if (isMainnet) {
            /// @dev generate call data for ADMIN_MULTISIG
            Core _core = Core(vm.envAddress("CORE"));
            address adminMultisig = vm.envAddress("ADMIN_MULTISIG");
            
            console2.log("=== MAINNET TRANSACTION PAYLOAD FOR ZIP002 ===");
            
            // 1. First, prepare for TimelockController deployment via zkSync ContractDeployer
            address[] memory proposers = new address[](1);
            proposers[0] = adminMultisig;
            
            address[] memory executors = new address[](1);
            executors[0] = adminMultisig;
            
            bytes memory constructorArgs = abi.encode(
                uint256(0), // zero delay
                proposers,
                executors,
                address(0) // No admin required
            );
            
            // zkSync ContractDeployer address
            address zkSyncContractDeployer = address(0x0000000000000000000000000000000000008006);
            
            // Create a random salt for deployment (in production, you'd want a more deterministic approach)
            bytes32 salt = keccak256(abi.encodePacked("TimelockController", block.timestamp));
            
            console2.log("TimelockController Deployment Transaction (zkSync):");
            console2.log("To:", zkSyncContractDeployer);
            console2.log("Value: 0");
            console2.log("Salt:", vm.toString(salt));
            console2.log("Constructor args:", vm.toString(constructorArgs));
            console2.log("Note: The bytecodeHash must be precomputed and factoryDeps must be provided in the zkSync transaction");
            
            // 2. After deployment, assuming the TimelockController address is known
            console2.log("\nAfter deployment, execute this transaction:");
            console2.log("To:", address(_core));
            
            // Generate the calldata to grant ADMIN role to the TimelockController
            bytes memory grantRoleCalldata = abi.encodeWithSelector(
                _core.grantRole.selector,
                Roles.ADMIN,
                address(0) // Replace with actual TimelockController address after deployment
            );
            
            console2.log("Grant ADMIN role calldata:");
            console2.logBytes(grantRoleCalldata);
            
            console2.log("\nReplacement variables:");
            console2.log("<timelock_controller_address> - Replace with the actual deployed TimelockController address");
            console2.log("Note: For zkSync deployment, you'll need to use the 'create' or 'create2' method from the ContractDeployer");
            console2.log("and provide the factory dependencies in your transaction.");
        } else {
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

        /// @dev Check if the environment is mainnet
        bool isMainnet = keccak256(bytes(vm.envString("ENVIRONMENT"))) == keccak256(bytes("mainnet"));
        if (isMainnet) {} else {
            vm.startBroadcast(deployerPrivateKey);
        }

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

            assertEq(
                placeable.maxTokenSupply(placeableTokenId),
                placeableMaxSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
            assertEq(
                placeable.getMintAmountLeft(placeableTokenId),
                placeableMaxSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        /// @dev Verify Wearable
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 wearableTokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 wearableMaxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;

            assertEq(
                wearables.maxTokenSupply(wearableTokenId),
                wearableMaxSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
            assertEq(
                wearables.getMintAmountLeft(wearableTokenId),
                wearableMaxSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        /// @dev Verify Consumable
        for (uint256 i = 0; i < consumableTokenIDMaxSupplySettings.length; i++) {
            uint256 consumableTokenId = consumableTokenIDMaxSupplySettings[i].tokenId;
            uint256 consumableMaxSupply = consumableTokenIDMaxSupplySettings[i].maxSupply;

            assertEq(
                consumables.maxTokenSupply(consumableTokenId),
                consumableMaxSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
            assertEq(
                consumables.getMintAmountLeft(consumableTokenId),
                consumableMaxSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        /// @dev Verify Season One
        assertEq(seasonOne.totalRewardTokens(), 30001521e18, "Invalid totalRewardTokens");
        assertEq(seasonOne.totalRewardTokensUsed(), 0, "Invalid totalRewardTokensUsed");
        assertEq(seasonOne.totalClawedBack(), 0, "Invalid totalClawedBack");

        for (uint256 i = 0; i < tokenIdRewardAmounts.length; i++) {
            uint256 seasonOneTokenId = tokenIdRewardAmounts[i].tokenId;
            uint256 seasonOneRewardAmount = tokenIdRewardAmounts[i].rewardAmount;

            assertEq(
                seasonOne.tokenIdRewardAmount(seasonOneTokenId),
                seasonOneRewardAmount,
                "Invalid tokenIdRewardAmount"
            );
            assertEq(seasonOne.tokenIdUsedAmount(seasonOneTokenId), 0, "Invalid tokenIdUsedAmount");
        }

        vm.stopBroadcast();
    }

    /// @dev zip005
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES
    function zip005() internal {
        if (vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES") == address(0)) {
            console2.log("zip005: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize placeables data
        placeableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(2, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(3, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(5, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(6, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(7, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(9, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(10, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(11, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(13, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(19, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(20, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(22, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(26, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(29, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(30, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(32, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(33, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(34, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(35, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(36, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(37, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(39, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(41, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(42, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(44, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(48, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(49, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(50, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(51, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(52, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(53, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(55, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(56, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(57, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(58, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(59, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(61, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(62, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(63, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(66, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(68, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(71, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(73, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(75, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(77, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(78, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(79, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(80, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(81, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(83, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(89, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(91, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(92, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(93, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(97, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(98, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(99, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(100, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(101, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(102, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(104, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(108, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(109, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(110, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(112, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(113, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(114, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(115, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(118, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(125, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(128, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(131, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(132, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(133, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(134, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(135, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(138, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(139, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(140, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(141, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(142, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(143, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(145, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(146, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(147, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(150, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(151, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(168, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(349, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(350, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(352, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(353, 100000));

        /// @dev Sanity checks
        assertEq(placeableTokenIDMaxSupplySettings.length, 92, "Invalid placeableTokenIDMaxSupplySettings length");

        uint256 tokenIDTotal = 0;
        uint256 maxSupplyTotal = 0;

        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            tokenIDTotal += placeableTokenIDMaxSupplySettings[i].tokenId;
            maxSupplyTotal += placeableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(tokenIDTotal, 8_227, "Invalid tokenIDTotal");
        assertEq(maxSupplyTotal, 6_380_000, "Invalid maxSupplyTotal");

        /// @dev Configure placeables
        ERC1155MaxSupplyMintable placeables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES")
        );

        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            placeables.setSupplyCap(
                placeableTokenIDMaxSupplySettings[i].tokenId,
                placeableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Validation
        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = placeableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = placeableTokenIDMaxSupplySettings[i].maxSupply;

            assertEq(placeables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(placeables.getMintAmountLeft(tokenId), maxSupply, "Invalid getMintAmountLeft for tokenId");
        }

        vm.stopBroadcast();
    }

    /// @dev zip006
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    function zip006() internal {
        if (vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0)) {
            console2.log("zip006: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize wearables data
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(7, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(26, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(27, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(28, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(29, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(30, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(31, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(32, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(33, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(34, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(35, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(36, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(37, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(38, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(39, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(40, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(41, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(42, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(43, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(44, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(45, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(46, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(47, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(48, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(49, 69));

        /// @dev Sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 25, "Invalid wearableTokenIDMaxSupplySettings length");

        uint256 maxSupplyTotal = 0;
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            maxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(maxSupplyTotal, 2_306_069, "Invalid maxSupplyTotal");

        /// @dev Configure wearables
        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearables.setSupplyCap(
                wearableTokenIDMaxSupplySettings[i].tokenId,
                wearableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Validation
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = wearables.totalSupply(tokenId);

            assertEq(wearables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(
                wearables.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        vm.stopBroadcast();
    }

    /// @dev zip007
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    function zip007() internal {
        if (vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0)) {
            console2.log("zip007: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize wearables data
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(50, 75));

        /// @dev Sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 1, "Invalid wearableTokenIDMaxSupplySettings length");

        uint256 maxSupplyTotal = 0;
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            maxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(maxSupplyTotal, 75, "Invalid maxSupplyTotal");

        /// @dev Configure wearables
        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearables.setSupplyCap(
                wearableTokenIDMaxSupplySettings[i].tokenId,
                wearableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Validation
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;

            assertEq(wearables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(wearables.getMintAmountLeft(tokenId), maxSupply, "Invalid getMintAmountLeft for tokenId");
        }

        vm.stopBroadcast();
    }

    /// @dev zip008
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    function zip008() internal {
        if (vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0)) {
            console2.log("zip008: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize wearables data
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(51, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(52, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(53, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(54, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(55, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(56, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(57, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(58, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(59, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(60, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(61, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(62, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(63, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(64, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(65, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(66, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(67, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(68, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(69, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(70, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(71, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(72, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(73, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(74, 100000));

        /// @dev Sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 24, "Invalid wearableTokenIDMaxSupplySettings length");

        uint256 maxSupplyTotal = 0;
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            maxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(maxSupplyTotal, 2_306_000, "Invalid maxSupplyTotal");

        /// @dev Configure wearables
        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearables.setSupplyCap(
                wearableTokenIDMaxSupplySettings[i].tokenId,
                wearableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Validation
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = wearables.totalSupply(tokenId);

            assertEq(wearables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(
                wearables.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        vm.stopBroadcast();
    }

    /// @dev zip009
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    function zip009() internal {
        if (vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0)) {
            console2.log("zip009: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize wearables data
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(75, 420));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(76, 100000));

        /// @dev Sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 2, "Invalid wearableTokenIDMaxSupplySettings length");

        uint256 maxSupplyTotal = 0;
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            maxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(maxSupplyTotal, 100_420, "Invalid maxSupplyTotal");

        /// @dev Configure wearables
        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearables.setSupplyCap(
                wearableTokenIDMaxSupplySettings[i].tokenId,
                wearableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Validation
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = wearables.totalSupply(tokenId);

            assertEq(wearables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(
                wearables.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        vm.stopBroadcast();
    }

    /// @dev zip010
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES
    function zip010() internal {
        if (vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES") == address(0)) {
            console2.log("zip010: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize placeables data
        placeableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(354, 100000));

        uint256 maxSupplyTotal = 0;
        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            maxSupplyTotal += placeableTokenIDMaxSupplySettings[i].maxSupply;
        }

        /// @dev Sanity checks
        assertEq(maxSupplyTotal, 100_000, "Invalid maxSupplyTotal");

        /// @dev Configure placeables
        ERC1155MaxSupplyMintable placeables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES")
        );

        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            placeables.setSupplyCap(
                placeableTokenIDMaxSupplySettings[i].tokenId,
                placeableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Validation
        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = placeableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = placeableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = placeables.totalSupply(tokenId);

            assertEq(placeables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(
                placeables.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        vm.stopBroadcast();
    }

    /// @dev zip011
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    function zip011() internal {
        if (vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0)) {
            console2.log("zip011: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize wearables data
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(77, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(78, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(79, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(80, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(81, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(82, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(83, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(84, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(85, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(86, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(87, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(88, 100000));

        /// @dev Sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 12, "Invalid wearableTokenIDMaxSupplySettings length");

        uint256 maxSupplyTotal = 0;
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            maxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(maxSupplyTotal, 1200_000, "Invalid maxSupplyTotal");

        /// @dev Configure wearables
        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearables.setSupplyCap(
                wearableTokenIDMaxSupplySettings[i].tokenId,
                wearableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Validation
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = wearables.totalSupply(tokenId);

            assertEq(wearables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(
                wearables.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        vm.stopBroadcast();
    }

    /// @dev zip012
    /// @dev CORE
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    function zip012() internal {
        if (
            vm.envAddress("CORE") == address(0) || vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0)
        ) {
            console2.log("zip012: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize wearables data
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(89, 120));

        /// @dev Sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 1, "Invalid wearableTokenIDMaxSupplySettings length");
        assertEq(wearableTokenIDMaxSupplySettings[0].maxSupply, 120, "Invalid maxSupplyTotal");

        /// @dev Configure wearables
        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        wearables.setSupplyCap(
            wearableTokenIDMaxSupplySettings[0].tokenId,
            wearableTokenIDMaxSupplySettings[0].maxSupply
        );

        /// @dev Validation
        uint256 tokenId = wearableTokenIDMaxSupplySettings[0].tokenId;
        uint256 maxSupply = wearableTokenIDMaxSupplySettings[0].maxSupply;
        uint256 currentSupply = wearables.totalSupply(tokenId);

        assertEq(wearables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
        assertEq(
            wearables.getMintAmountLeft(tokenId),
            maxSupply - currentSupply,
            "Invalid getMintAmountLeft for tokenId"
        );

        vm.stopBroadcast();
    }

    /// @dev zip013
    /// @dev CORE
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    function zip013() internal {
        if (
            vm.envAddress("CORE") == address(0) || vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0)
        ) {
            console2.log("zip013: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize wearables data
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(90, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(91, 100000));

        /// @dev Sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 2, "Invalid wearableTokenIDMaxSupplySettings length");

        uint256 maxSupplyTotal = 0;
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            maxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(maxSupplyTotal, 200_000, "Invalid maxSupplyTotal");

        /// @dev Configure wearables
        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearables.setSupplyCap(
                wearableTokenIDMaxSupplySettings[i].tokenId,
                wearableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Validation
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = wearables.totalSupply(tokenId);

            assertEq(wearables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(
                wearables.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        vm.stopBroadcast();
    }

    /// @dev zip014
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    function zip014() internal {
        if (vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0)) {
            console2.log("zip014: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize wearables data
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(92, 420));

        /// @dev Sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 1, "Invalid wearableTokenIDMaxSupplySettings length");
        assertEq(wearableTokenIDMaxSupplySettings[0].maxSupply, 420, "Invalid maxSupplyTotal");

        /// @dev Configure wearables
        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        wearables.setSupplyCap(
            wearableTokenIDMaxSupplySettings[0].tokenId,
            wearableTokenIDMaxSupplySettings[0].maxSupply
        );

        /// @dev Validation
        uint256 tokenId = wearableTokenIDMaxSupplySettings[0].tokenId;
        uint256 maxSupply = wearableTokenIDMaxSupplySettings[0].maxSupply;
        uint256 currentSupply = wearables.totalSupply(tokenId);

        assertEq(wearables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
        assertEq(
            wearables.getMintAmountLeft(tokenId),
            maxSupply - currentSupply,
            "Invalid getMintAmountLeft for tokenId"
        );

        vm.stopBroadcast();
    }

    /// @dev zip016
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    function zip016() internal {
        if (vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0)) {
            console2.log("zip016: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize wearables data
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(93, 42));

        /// @dev Sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 1, "Invalid wearableTokenIDMaxSupplySettings length");
        assertEq(wearableTokenIDMaxSupplySettings[0].maxSupply, 42, "Invalid maxSupplyTotal");

        /// @dev Configure wearables
        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        wearables.setSupplyCap(
            wearableTokenIDMaxSupplySettings[0].tokenId,
            wearableTokenIDMaxSupplySettings[0].maxSupply
        );

        /// @dev Validation
        uint256 tokenId = wearableTokenIDMaxSupplySettings[0].tokenId;
        uint256 maxSupply = wearableTokenIDMaxSupplySettings[0].maxSupply;
        uint256 currentSupply = wearables.totalSupply(tokenId);

        assertEq(wearables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
        assertEq(
            wearables.getMintAmountLeft(tokenId),
            maxSupply - currentSupply,
            "Invalid getMintAmountLeft for tokenId"
        );

        vm.stopBroadcast();
    }

    /// @dev zip017
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    function zip017() internal {
        if (vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0)) {
            console2.log("zip017: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize wearables data
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(94, 69));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(95, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(96, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(97, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(98, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(99, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(100, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(101, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(102, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(103, 1000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(104, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(105, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(106, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(107, 100000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(108, 100000));

        /// @dev Sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 15, "Invalid wearableTokenIDMaxSupplySettings length");

        uint256 maxSupplyTotal = 0;
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            maxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(maxSupplyTotal, 925069, "Invalid maxSupplyTotal");

        /// @dev Configure wearables
        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearables.setSupplyCap(
                wearableTokenIDMaxSupplySettings[i].tokenId,
                wearableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Validation
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = wearables.totalSupply(tokenId);

            assertEq(wearables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(
                wearables.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        vm.stopBroadcast();
    }

    /// @dev zip018
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES
    function zip018() internal {
        if (
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0) ||
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES") == address(0)
        ) {
            console2.log("zip018: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize collections with empty arrays
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        placeableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);

        /// @dev Setup placeables data
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(8, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(15, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(16, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(18, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(23, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(24, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(25, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(38, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(40, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(46, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(47, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(54, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(95, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(103, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(105, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(116, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(117, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(126, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(127, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(130, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(136, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(137, 100000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(144, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(351, 100000));

        /// @dev Setup wearables data
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(109, 100));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(110, 100));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(111, 66));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(112, 1));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(113, 1));

        /// @dev Sanity checks for placeables
        assertEq(placeableTokenIDMaxSupplySettings.length, 24, "Invalid placeableTokenIDMaxSupplySettings length");

        uint256 placeableMaxSupplyTotal = 0;
        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            placeableMaxSupplyTotal += placeableTokenIDMaxSupplySettings[i].maxSupply;
        }
        assertEq(placeableMaxSupplyTotal, 1366000, "Invalid maxSupplyTotal for placeables");

        /// @dev Sanity checks for wearables
        assertEq(wearableTokenIDMaxSupplySettings.length, 5, "Invalid wearableTokenIDMaxSupplySettings length");

        uint256 wearableMaxSupplyTotal = 0;
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearableMaxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }
        assertEq(wearableMaxSupplyTotal, 268, "Invalid maxSupplyTotal for wearables");

        /// @dev Configure placeables
        ERC1155MaxSupplyMintable placeables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES")
        );

        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            placeables.setSupplyCap(
                placeableTokenIDMaxSupplySettings[i].tokenId,
                placeableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Configure wearables
        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearables.setSupplyCap(
                wearableTokenIDMaxSupplySettings[i].tokenId,
                wearableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Validation for placeables
        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = placeableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = placeableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = placeables.totalSupply(tokenId);

            assertEq(placeables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for placeable tokenId");
            assertEq(
                placeables.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for placeable tokenId"
            );
        }

        /// @dev Validation for wearables
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = wearables.totalSupply(tokenId);

            assertEq(wearables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for wearable tokenId");
            assertEq(
                wearables.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for wearable tokenId"
            );
        }

        vm.stopBroadcast();
    }

    /// @dev zip019
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    function zip019() internal {
        if (vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0)) {
            console2.log("zip019: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev Initialize wearables data
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(114, 4000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(115, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(116, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(117, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(118, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(119, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(120, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(121, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(122, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(123, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(124, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(125, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(126, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(127, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(128, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(129, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(130, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(131, 4000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(132, 4000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(133, 4000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(134, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(135, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(136, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(137, 2500));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(138, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(139, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(140, 200));

        /// @dev Sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 27, "Invalid wearableTokenIDMaxSupplySettings length");

        uint256 maxSupplyTotal = 0;
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            maxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(maxSupplyTotal, 4780700, "Invalid maxSupplyTotal");

        /// @dev Configure wearables
        ERC1155MaxSupplyMintable wearables = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearables.setSupplyCap(
                wearableTokenIDMaxSupplySettings[i].tokenId,
                wearableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Validation
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = wearables.totalSupply(tokenId);

            assertEq(wearables.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(
                wearables.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        vm.stopBroadcast();
    }

    /// @dev zip020
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES
    function zip020() internal {
        if (
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0) ||
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES") == address(0)
        ) {
            console2.log("zip020: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev initialize collections with empty arrays
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);
        placeableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);

        /// @dev placeables
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(355, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(356, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(357, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(358, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(359, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(360, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(361, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(362, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(363, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(364, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(365, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(366, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(367, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(368, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(369, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(370, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(371, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(372, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(373, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(374, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(375, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(376, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(377, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(378, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(379, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(380, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(381, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(382, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(383, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(384, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(385, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(386, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(387, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(388, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(389, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(390, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(391, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(392, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(393, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(394, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(395, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(396, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(397, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(398, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(399, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(400, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(401, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(402, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(403, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(404, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(405, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(406, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(407, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(408, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(409, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(410, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(411, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(412, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(413, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(414, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(415, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(416, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(417, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(418, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(419, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(420, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(421, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(422, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(423, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(424, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(425, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(426, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(427, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(428, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(429, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(430, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(431, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(432, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(433, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(434, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(435, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(436, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(437, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(438, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(439, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(440, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(441, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(442, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(443, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(444, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(445, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(446, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(447, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(448, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(449, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(450, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(451, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(452, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(453, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(454, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(455, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(456, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(457, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(458, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(459, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(460, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(461, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(462, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(463, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(464, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(465, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(466, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(467, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(468, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(469, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(470, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(471, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(472, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(473, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(474, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(475, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(476, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(477, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(478, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(479, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(480, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(481, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(482, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(483, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(484, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(485, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(486, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(487, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(488, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(489, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(490, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(491, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(492, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(493, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(494, 4000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(495, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(496, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(497, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(498, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(499, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(500, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(501, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(502, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(503, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(504, 250000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(505, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(506, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(507, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(508, 6000));
        placeableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(509, 6000));

        /// @dev wearables
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(155, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(156, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(157, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(158, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(159, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(160, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(161, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(162, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(163, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(164, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(165, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(166, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(167, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(168, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(169, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(170, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(171, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(172, 4000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(173, 4000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(174, 4000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(175, 100));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(176, 100));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(177, 250000));

        /// @notice sanity checks for placeables
        assertEq(placeableTokenIDMaxSupplySettings.length, 155, "Invalid placeableTokenIDMaxSupplySettings length");

        uint placeableMaxSupplyTotal = 0;

        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            placeableMaxSupplyTotal += placeableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(placeableMaxSupplyTotal, 15520000, "Invalid maxSupplyTotal for placeables");

        /// @notice sanity checks for wearables
        assertEq(wearableTokenIDMaxSupplySettings.length, 23, "Invalid wearableTokenIDMaxSupplySettings length");

        uint wearableMaxSupplyTotal = 0;

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearableMaxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(wearableMaxSupplyTotal, 4512200, "Invalid maxSupplyTotal for wearables");

        /// @dev Add configuration for setting the supply caps
        ERC1155MaxSupplyMintable placeable = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_PLACEABLES")
        );

        ERC1155MaxSupplyMintable wearable = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        /// @dev placeable config
        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            placeable.setSupplyCap(
                placeableTokenIDMaxSupplySettings[i].tokenId,
                placeableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev wearable config
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearable.setSupplyCap(
                wearableTokenIDMaxSupplySettings[i].tokenId,
                wearableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev verify placeables
        for (uint256 i = 0; i < placeableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = placeableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = placeableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = placeable.totalSupply(tokenId);

            assertEq(placeable.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(
                placeable.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        /// @dev verify wearables
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = wearable.totalSupply(tokenId);

            assertEq(wearable.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(
                wearable.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        vm.stopBroadcast();
    }

    /// @dev zip021
    /// @dev ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES
    function zip021() public {
        if (vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES") == address(0)) {
            console2.log("zip020: missing environment variables");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        /// @dev initialize collections with empty arrays
        wearableTokenIDMaxSupplySettings = new TokenIDMaxSupplySettings[](0);

        /// @dev wearables
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(178, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(179, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(224, 20000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(225, 20000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(226, 20000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(227, 20000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(228, 20000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(229, 20000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(230, 20000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(231, 20000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(232, 20000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(233, 20000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(180, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(181, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(182, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(183, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(184, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(185, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(186, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(187, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(188, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(189, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(190, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(191, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(202, 250000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(153, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(154, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(143, 6000));
        wearableTokenIDMaxSupplySettings.push(TokenIDMaxSupplySettings(144, 6000));

        /// @dev sanity checks
        assertEq(wearableTokenIDMaxSupplySettings.length, 29, "Invalid wearableTokenIDMaxSupplySettings length");

        uint maxSupplyTotal = 0;

        /// @dev sum numbers from requrements sheet
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            maxSupplyTotal += wearableTokenIDMaxSupplySettings[i].maxSupply;
        }

        assertEq(maxSupplyTotal, 3730000, "Invalid maxSupplyTotal");

        /// @dev Add configuration for setting the supply caps
        ERC1155MaxSupplyMintable wearable = ERC1155MaxSupplyMintable(
            vm.envAddress("ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES")
        );

        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            wearable.setSupplyCap(
                wearableTokenIDMaxSupplySettings[i].tokenId,
                wearableTokenIDMaxSupplySettings[i].maxSupply
            );
        }

        /// @dev Verify Wearable
        for (uint256 i = 0; i < wearableTokenIDMaxSupplySettings.length; i++) {
            uint256 tokenId = wearableTokenIDMaxSupplySettings[i].tokenId;
            uint256 maxSupply = wearableTokenIDMaxSupplySettings[i].maxSupply;
            uint256 currentSupply = wearable.totalSupply(tokenId);

            assertEq(wearable.maxTokenSupply(tokenId), maxSupply, "Invalid maxTokenSupply for tokenId");
            assertEq(
                wearable.getMintAmountLeft(tokenId),
                maxSupply - currentSupply,
                "Invalid getMintAmountLeft for tokenId"
            );
        }

        vm.stopBroadcast();
    }
}
