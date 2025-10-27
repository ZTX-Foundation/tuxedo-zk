// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import {console} from "@forge-std/console.sol";
import {Script} from "@forge-std/Script.sol";
import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";
import {Proposal} from "@forge-proposal-simulator/src/proposals/Proposal.sol";
import {EnvMock} from "src/mocks/env.sol";

import {zip000} from "proposals/zips/zip000.sol";
import {zip001} from "proposals/zips/zip001.sol";

// import {zip002} from "proposals/zips/zip002.sol";
// import {zip003} from "proposals/zips/zip003.sol";
// import {zip004} from "proposals/zips/zip004.sol";
// import {zip005} from "proposals/zips/zip005.sol";
// import {zip006} from "proposals/zips/zip006.sol";
// import {zip007} from "proposals/zips/zip007.sol";
// import {zip008} from "proposals/zips/zip008.sol";
// import {zip009} from "proposals/zips/zip009.sol";
// import {zip010} from "proposals/zips/zip010.sol";
// import {zip011} from "proposals/zips/zip011.sol";
// import {zip012} from "proposals/zips/zip012.sol";
// import {zip013} from "proposals/zips/zip013.sol";
// import {zip014} from "proposals/zips/zip014.sol";
// import {zip016} from "proposals/zips/zip016.sol";
// import {zip017} from "proposals/zips/zip017.sol";
// import {zip018} from "proposals/zips/zip018.sol";
// import {zip019} from "proposals/zips/zip019.sol";
// import {zip020} from "proposals/zips/zip020.sol";
// import {zip021} from "proposals/zips/zip021.sol";

/*
How to use:
forge script script/deploy/BootstrapTestnet.s.sol:BootstrapTestnet \
    -vvvv \
    --rpc-url $ETH_RPC_URL \
    --broadcast \
    --private-key <KEY>
Remove --broadcast and --private-key if you want to try locally first, without paying any gas.
*/

contract BootstrapTestnet is Script {
    uint256 public privateKey;

    Addresses addresses;
    Proposal[] public proposals;

    /// @notice json structure to read addresses into storage from file
    struct SavedAddresses {
        /// address to store
        address addr;
        /// chain id of network to store for
        uint256 chainId;
        /// whether the address is a contract
        bool isContract;
        /// name of contract to store
        string name;
    }

    function setUp() public {
        EnvMock env = new EnvMock();
        env.storeBool("DEBUG", vm.envOr("DEBUG", false));
        env.storeBool("DO_DEPLOY", vm.envOr("DO_DEPLOY", true));
        env.storeBool("DO_AFTER_DEPLOY_MOCK", vm.envOr("DO_AFTER_DEPLOY_MOCK", true));
        env.storeBool("DO_BUILD", vm.envOr("DO_BUILD", true));
        env.storeBool("DO_SIMULATE", vm.envOr("DO_SIMULATE", true));
        env.storeBool("DO_VALIDATE", vm.envOr("DO_VALIDATE", true));
        env.storeBool("DO_PRINT", vm.envOr("DO_PRINT", true));

        env.storeString("ENVIRONMENT", vm.envOr("ENVIRONMENT", string("localnet")));
        env.storeString("DOMAIN", vm.envString("DOMAIN"));

        string memory tokenName = string(abi.encodePacked(vm.envString("TOKEN_NAME")));
        string memory tokenSymbol = string(abi.encodePacked(vm.envString("TOKEN_SYMBOL")));
        env.storeString("TOKEN_NAME", tokenName);
        env.storeString("TOKEN_SYMBOL", tokenSymbol);

        // warp on localnet so that timestamp is not 1 and timelock simulation works
        if (block.chainid == 31337) {
            vm.warp(block.timestamp + 100);
        }

        addresses = new Addresses();

        string memory addressPath = string(
            abi.encodePacked("proposals/Addresses/", vm.envOr("ENVIRONMENT", string("localnet")), ".json")
        );
        console.log(addressPath);

        string memory addressesData = string(abi.encodePacked(vm.readFile(addressPath)));

        bytes memory parsedJson = vm.parseJson(addressesData);

        SavedAddresses[] memory savedAddresses = abi.decode(parsedJson, (SavedAddresses[]));

        for (uint256 i = 0; i < savedAddresses.length; i++) {
            addresses.addAddress(
                savedAddresses[i].name,
                savedAddresses[i].addr,
                savedAddresses[i].chainId,
                savedAddresses[i].isContract
            );
        }

        // Load proposals
        proposals.push(Proposal(address(new zip000(env)))); /// Genesis token proposal
        proposals.push(Proposal(address(new zip001(env)))); /// Wearables, Core, ADMIN_MULTISIG proposal
        // proposals.push(Proposal(address(new zip002(env)))); /// Timelock proposal
        // proposals.push(Proposal(address(new zip003(env)))); /// CGv1 proposal
        // proposals.push(Proposal(address(new zip004(env)))); /// TokenIds, MaxSupply and Capsule settings proposal
        // proposals.push(Proposal(address(new zip005(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip006(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip007(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip008(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip009(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip010(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip011(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip012(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip013(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip014(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip016(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip017(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip018(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip019(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip020(env)))); /// MaxSupply settings proposal
        // proposals.push(Proposal(address(new zip021(env)))); /// MaxSupply settings proposal

        for (uint256 i = 0; i < proposals.length; i++) {
            proposals[i].setAddresses(addresses);
        }
    }

    function run() public {
        address deployer = addresses.getAddress("DEPLOYER_EOA");

        vm.startBroadcast(deployer);

        for (uint256 i = 0; i < proposals.length; i++) {
            string memory name = proposals[i].name();
            console.log("Proposal", name, "deploy()");
            addresses.resetRecordingAddresses();

            // Run the proposal workflow
            proposals[i].run();
        }

        vm.stopBroadcast();
    }
}
