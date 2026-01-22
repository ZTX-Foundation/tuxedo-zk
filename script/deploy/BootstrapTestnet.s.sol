// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import {console} from "@forge-std/console.sol";
import {Script} from "@forge-std/Script.sol";
import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";
import {Proposal} from "@forge-proposal-simulator/src/proposals/Proposal.sol";

import {zip000} from "proposals/zips/zip000.sol";
import {zip001} from "proposals/zips/zip001.sol";
import {zip002} from "proposals/zips/zip002.sol";
import {zip003} from "proposals/zips/zip003.sol";
import {zip004} from "proposals/zips/zip004.sol";

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

    function setUp() public {
        string memory environment = vm.envOr("ENVIRONMENT", string("localnet"));
        // warp on localnet so that timestamp is not 1 and timelock simulation works
        if (block.chainid == 31337) {
            vm.warp(block.timestamp + 100);
        }
        string memory addressPath = string(abi.encodePacked("proposals/Addresses/", environment, ".json"));

        addresses = new Addresses(addressPath);

        // Load proposals
        proposals.push(Proposal(address(new zip000()))); /// Genesis token proposal
        proposals.push(Proposal(address(new zip001()))); /// Wearables, Core, ADMIN_MULTISIG proposal
        proposals.push(Proposal(address(new zip002()))); /// Timelock proposal
        proposals.push(Proposal(address(new zip003()))); /// ZTX Mobile contracts proposal
        proposals.push(Proposal(address(new zip004()))); /// Consolidated wearables and enhanceables config

        for (uint256 i = 0; i < proposals.length; i++) {
            proposals[i].registerEnvVars();
            proposals[i].setAddresses(addresses);
        }
    }

    function run() public {
        for (uint256 i = 0; i < proposals.length; i++) {
            string memory name = proposals[i].name();
            console.log("Proposal", name, "deploy()");
            addresses.resetRecordingAddresses();

            // Run the proposal workflow
            proposals[i].run();
        }
    }
}
