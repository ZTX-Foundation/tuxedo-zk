//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Splitter} from "@protocol/finance/ERC20Splitter.sol";

import {TimelockProposal} from "@forge-proposal-simulator/src/proposals/TimelockProposal.sol";

import {Core} from "@protocol/core/Core.sol";
import {Roles} from "@protocol/core/Roles.sol";
import {GameConsumer} from "@protocol/game/GameConsumer.sol";
import {CoreRef} from "@protocol/refs/CoreRef.sol";

/// @notice Phase 2 deployment: ERC20Splitter + GameConsumer
/// @dev Requires TOKEN address in the address registry (bridged canonical ZTX from Arb One)
contract zip005 is TimelockProposal {
    Core private _core;

    function name() public pure override returns (string memory) {
        return "ZIP005";
    }

    function description() public pure override returns (string memory) {
        return "ERC20Splitter and GameConsumer deployment (requires bridged TOKEN)";
    }

    function deploy() public override {
        /// ERC20Splitter allocation settings
        ERC20Splitter.Allocation[] memory allocations = new ERC20Splitter.Allocation[](2);
        allocations[0].deposit = addresses.getAddress("REVENUE_WALLET_MULTISIG01");
        allocations[0].ratio = 5_000;
        allocations[1].deposit = addresses.getAddress("REVENUE_WALLET_MULTISIG02");
        allocations[1].ratio = 5_000;

        /// ERC20Splitter consumable splitter contract
        ERC20Splitter consumableSplitter = new ERC20Splitter(
            address(_core),
            addresses.getAddress("TOKEN"),
            allocations
        );
        addresses.addAddress("CONSUMABLE_SPLITTER", address(consumableSplitter), true);

        /// Game consumer
        GameConsumer gameConsumer = new GameConsumer(
            address(_core),
            addresses.getAddress("TOKEN"),
            addresses.getAddress("CONSUMABLE_SPLITTER"),
            addresses.getAddress("WETH")
        );
        addresses.addAddress("GAME_CONSUMER", address(gameConsumer), true);
    }

    function build() public override buildModifier(addresses.getAddress("ADMIN_TIMELOCK_CONTROLLER")) {
        /// grant game consumer notary protocol role
        _core.grantRole(Roles.GAME_CONSUMER_NOTARY_PROTOCOL_ROLE, addresses.getAddress("AUTOGRAPH_SERVICE_KMS_WALLET"));
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
        /// Verify ERC20Splitter has the correct settings
        {
            ERC20Splitter splitter = ERC20Splitter(addresses.getAddress("CONSUMABLE_SPLITTER"));
            assertEq(address(splitter.token()), addresses.getAddress("TOKEN"), "Verify splitter token address");

            (address address0, uint ratio0) = splitter.allocations(0);
            (address address1, uint ratio1) = splitter.allocations(1);

            assertEq(address0, addresses.getAddress("REVENUE_WALLET_MULTISIG01"));
            assertEq(ratio0, 5_000);
            assertEq(address1, addresses.getAddress("REVENUE_WALLET_MULTISIG02"));
            assertEq(ratio1, 5_000);

            assertEq(
                address(splitter.core()),
                address(_core),
                "CONSUMABLE_SPLITTER is pointing to wrong core"
            );
        }

        /// Verify GameConsumer
        {
            assertEq(
                address(CoreRef(addresses.getAddress("GAME_CONSUMER")).core()),
                address(_core),
                "Verify GAME_CONSUMER is pointing to the correct core address"
            );
        }

        /// Verify notary role
        {
            assertEq(
                _core.hasRole(
                    Roles.GAME_CONSUMER_NOTARY_PROTOCOL_ROLE,
                    addresses.getAddress("AUTOGRAPH_SERVICE_KMS_WALLET")
                ),
                true,
                "Verifying AUTOGRAPH_SERVICE_KMS_WALLET has GAME_CONSUMER_NOTARY role"
            );
        }
    }
}
