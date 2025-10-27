// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import {console} from "@forge-std/console.sol";
import {zip021 as zip} from "proposals/zips/zip021.sol";
import {Script} from "@forge-std/Script.sol";
import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";
import {TimelockProposal} from "@forge-proposal-simulator/src/proposals/TimelockProposal.sol";
import {EnvMock} from "src/mocks/env.sol";

/*
How to use:
forge script script/deploy/DeployProposal.s.sol:DeployProposal \
    -vvvv \
    --rpc-url $ETH_RPC_URL \
    --broadcast
Remove --broadcast if you want to try locally first, without paying any gas.
*/

contract DeployProposal is Script {
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

        // warp on localnet so that timestamp is not 1 and timelock simulation works
        if (block.chainid == 31337) {
            vm.warp(block.timestamp + 100);
        }

        Addresses addresses = new Addresses();

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
        addresses.getAddress("DEPLOYER_EOA");
    }

    function run() public {
        console.log("Loaded");
    }
}

// pragma solidity ^0.8.18;
//
// import {console} from "@forge-std/console.sol";
// import {zip021 as zip} from "proposals/zips/zip021.sol";
// import {Script} from "@forge-std/Script.sol";
// import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";
// import {TimelockProposal} from "@forge-proposal-simulator/src/proposals/TimelockProposal.sol";
// import {MockVM} from "src/mock/MockVM.sol";
//
// /*
// How to use:
// forge script script/deploy/DeployProposal.s.sol:DeployProposal \
//     -vvvv \
//     --rpc-url $ETH_RPC_URL \
//     --broadcast
// Remove --broadcast if you want to try locally first, without paying any gas.
// */
//
// contract DeployProposal is Script {
//     struct SavedAddresses {
//         /// address to store
//         address addr;
//         /// chain id of network to store for
//         uint256 chainId;
//         /// whether the address is a contract
//         bool isContract;
//         /// name of contract to store
//         string name;
//     }
//
//     function setUp() public {
//         Addresses addresses = new Addresses("");
//
//         string memory environment = vm.envOr("ENVIRONMENT", string("localnet"));
//         string memory addressPath = string(abi.encodePacked("proposals/Addresses/", environment, ".json"));
//
//         string memory addressesData = vm.readFile(addressPath);
//
//         bytes memory parsedJson = vm.parseJson(addressesData);
//         console.log("Parsing JSON");
//
//         SavedAddresses[] memory savedAddresses = abi.decode(parsedJson, (SavedAddresses[]));
//         console.log("Decoding saved addresses");
//
//         for (uint256 i = 0; i < savedAddresses.length; i++) {
//             addresses.addAddress(
//                 savedAddresses[i].name,
//                 savedAddresses[i].addr,
//                 savedAddresses[i].chainId,
//                 savedAddresses[i].isContract
//             );
//         }
//         // string memory addressesData = vm.readFile("proposals/Addresses/creator-testnet.json");
//         // console.log("Reading address data");
//         // string memory addressesData = vm.readFile(addressesPath);
//         // console.log("Got address data");
//
//         // bytes memory parsedJson = vm.parseJson(addressesData);
//         // console.log("Parsing JSON");
//         // console.logBytes(parsedJson);
//     }
//
//     function run() public {
//         console.log("Loaded");
//     }
// }
//
