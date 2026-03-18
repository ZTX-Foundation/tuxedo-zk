// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import {console} from "@forge-std/console.sol";
import {Script} from "@forge-std/Script.sol";
import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";
import {Proposal} from "@forge-proposal-simulator/src/proposals/Proposal.sol";

import {zip001} from "proposals/zips/zip001.sol";
import {zip002} from "proposals/zips/zip002.sol";
import {zip003} from "proposals/zips/zip003.sol";
import {zip004} from "proposals/zips/zip004.sol";

/*
Creator Testnet (chain ID 278701) — mirrors mainnet deployment path exactly.

Env vars:
    ADDRESS_FILE  — address JSON filename without extension (default: localnet)
    ENVIRONMENT   — used for metadata URI subdomain (e.g. "qa")
    DOMAIN        — used for metadata URI domain (e.g. "ztx.io")

Phase 1: Deploy Core + Timelock
    ADDRESS_FILE=creator-testnet ENVIRONMENT=qa DOMAIN=ztx.io \
      forge script script/deploy/BootstrapTestnet.s.sol:BootstrapTestnetPhase1 \
        -vvvv --rpc-url $ETH_RPC_URL --broadcast --private-key <KEY>

Then: ADMIN_MULTISIG must call core.grantRole(Roles.ADMIN, ADMIN_TIMELOCK_CONTROLLER)
      Add deployed addresses (CORE, GLOBAL_REENTRANCY_LOCK, ERC1155_MAX_SUPPLY_MINTABLE_WEARABLES,
      ERC1155_MAX_SUPPLY_ADMIN_MINTER, ERC1155_BATCH_OPERATOR, ADMIN_TIMELOCK_CONTROLLER)
      to creator-testnet.json

Phase 2: Deploy NFT collections + AutoGraph minters
    ADDRESS_FILE=creator-testnet ENVIRONMENT=qa DOMAIN=ztx.io \
      forge script script/deploy/BootstrapTestnet.s.sol:BootstrapTestnetPhase2 \
        -vvvv --rpc-url $ETH_RPC_URL --broadcast --private-key <KEY>

Phase 3 (future, after bridge): Deploy ERC20Splitter + GameConsumer via zip005
*/

contract BootstrapTestnetPhase1 is Script {
    Addresses addresses;
    Proposal[] public proposals;

    function setUp() public {
        string memory addressFile = vm.envOr("ADDRESS_FILE", string("localnet"));
        if (block.chainid == 31337) {
            vm.warp(block.timestamp + 100);
        }
        string memory addressPath = string(abi.encodePacked("proposals/Addresses/", addressFile, ".json"));
        addresses = new Addresses(addressPath);

        proposals.push(Proposal(address(new zip001()))); /// Core, Wearables, AdminMinter, BatchOperator
        proposals.push(Proposal(address(new zip002()))); /// Timelock

        for (uint256 i = 0; i < proposals.length; i++) {
            proposals[i].registerEnvVars();
            proposals[i].setAddresses(addresses);
        }
    }

    function run() public {
        for (uint256 i = 0; i < proposals.length; i++) {
            string memory proposalName = proposals[i].name();
            console.log("Proposal", proposalName, "deploy()");
            addresses.resetRecordingAddresses();
            proposals[i].run();
        }

        console.log("");
        console.log("=== PHASE 1 COMPLETE ===");
        console.log("Next steps:");
        console.log("  1. Add deployed addresses to qa.json (CORE, GLOBAL_REENTRANCY_LOCK, etc.)");
        console.log("  2. From ADMIN_MULTISIG, call core.grantRole(Roles.ADMIN, ADMIN_TIMELOCK_CONTROLLER)");
        console.log("  3. Run BootstrapTestnetPhase2");
    }
}

contract BootstrapTestnetPhase2 is Script {
    Addresses addresses;
    Proposal[] public proposals;

    function setUp() public {
        string memory addressFile = vm.envOr("ADDRESS_FILE", string("localnet"));
        if (block.chainid == 31337) {
            vm.warp(block.timestamp + 100);
        }
        string memory addressPath = string(abi.encodePacked("proposals/Addresses/", addressFile, ".json"));
        addresses = new Addresses(addressPath);

        proposals.push(Proposal(address(new zip003()))); /// NFT collections + AutoGraph minters
        proposals.push(Proposal(address(new zip004()))); /// Wearables and enhanceables config

        for (uint256 i = 0; i < proposals.length; i++) {
            proposals[i].registerEnvVars();
            proposals[i].setAddresses(addresses);
        }
    }

    function run() public {
        for (uint256 i = 0; i < proposals.length; i++) {
            string memory proposalName = proposals[i].name();
            console.log("Proposal", proposalName, "deploy()");
            addresses.resetRecordingAddresses();
            proposals[i].run();
        }

        console.log("");
        console.log("=== PHASE 2 COMPLETE ===");
        console.log("NFT minting infrastructure is live.");
        console.log("Phase 3 (zip005): Deploy ERC20Splitter + GameConsumer after bridged token is available.");
    }
}
