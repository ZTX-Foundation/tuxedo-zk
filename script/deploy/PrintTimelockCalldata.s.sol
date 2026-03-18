// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import {console} from "@forge-std/console.sol";
import {Script} from "@forge-std/Script.sol";
import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";
import {Proposal} from "@forge-proposal-simulator/src/proposals/Proposal.sol";

import {zip003} from "proposals/zips/zip003.sol";
import {zip004} from "proposals/zips/zip004.sol";

/*
Generates the scheduleBatch + executeBatch calldata for zip003 and zip004.
Submit these to ADMIN_TIMELOCK_CONTROLLER from ADMIN_MULTISIG (Safe).

Usage:
    ADDRESS_FILE=creator-testnet ENVIRONMENT=qa DOMAIN=ztx.io \
    DO_DEPLOY=false DO_SIMULATE=false DO_VALIDATE=false DO_PRINT=true \
      forge script script/deploy/PrintTimelockCalldata.s.sol:PrintTimelockCalldata \
        -vvvv --rpc-url https://rpc.testnet.oncreator.com

For each proposal, submit two Safe txs to ADMIN_TIMELOCK_CONTROLLER:
  1. scheduleBatch calldata (schedule the actions)
  2. executeBatch calldata (execute after timelock delay — 0 in our case)
*/

contract PrintTimelockCalldata is Script {
    Addresses addresses;
    Proposal[] public proposals;

    function setUp() public {
        string memory addressFile = vm.envOr("ADDRESS_FILE", string("localnet"));
        string memory addressPath = string(abi.encodePacked("proposals/Addresses/", addressFile, ".json"));
        addresses = new Addresses(addressPath);

        proposals.push(Proposal(address(new zip003())));
        proposals.push(Proposal(address(new zip004())));

        for (uint256 i = 0; i < proposals.length; i++) {
            proposals[i].registerEnvVars();
            proposals[i].setAddresses(addresses);
        }
    }

    function run() public {
        for (uint256 i = 0; i < proposals.length; i++) {
            string memory proposalName = proposals[i].name();
            console.log("\n========================================");
            console.log("Proposal:", proposalName);
            console.log("========================================");
            addresses.resetRecordingAddresses();
            proposals[i].run();
        }
    }
}
