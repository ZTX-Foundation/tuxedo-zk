// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import {console} from "@forge-std/console.sol";
import {zip021 as zip} from "proposals/zips/zip021.sol";
import {Script} from "@forge-std/Script.sol";
import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";
import {TimelockProposal} from "@forge-proposal-simulator/src/proposals/TimelockProposal.sol";

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
        // Step 1: Read data using REAL vm (works in setUp context)
        string memory environment = vm.envOr("ENVIRONMENT", string("localnet"));
        string memory addressPath = string(abi.encodePacked("proposals/Addresses/", environment, ".json"));
        string memory addressesData = vm.readFile(addressPath);
        bytes memory parsedJson = vm.parseJson(addressesData);

        // Step 3: Read MockVM bytecode from zkout artifact instead
        string memory artifact = vm.readFile("zkout/MockVM.sol/MockVM.json");
        bytes memory mockVmBytecode = vm.parseJsonBytes(artifact, ".bytecode.object");
        console.log("Read MockVM bytecode from artifact, length:", mockVmBytecode.length);

        // Step 4: Etch MockVM bytecode at VM_ADDRESS
        vm.etch(VM_ADDRESS, mockVmBytecode);
        // console.log("Etched MockVM at VM_ADDRESS:", VM_ADDRESS);

        // MockVM(VM_ADDRESS).storeParsedJson(addressesData, parsedJson);
        // MockVM(VM_ADDRESS).storeEnvString("ENVIRONMENT", environment);
        // console.log("Stored data in MockVM");
        //
        // // Step 6: Now try creating Addresses - it should use mocked vm
        // Addresses addresses = new Addresses(addressPath);
        // console.log("Created Addresses contract successfully!");
        //
        // SavedAddresses[] memory savedAddresses = abi.decode(parsedJson, (SavedAddresses[]));
        // console.log("Decoded", savedAddresses.length, "addresses");
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
