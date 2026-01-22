pragma solidity 0.8.18;

import {Core} from "@protocol/core/Core.sol";
import {getCore, getRevertMessage} from "test/fixtures/Fixtures.sol";
import {MockCoreRef} from "test/mock/MockCoreRef.sol";
import {TestAddresses as addresses} from "test/fixtures/TestAddresses.sol";
import {Roles} from "@protocol/core/Roles.sol";

import "@forge-std/Test.sol";

contract CoreRefTest is Test {
    Core private core;
    MockCoreRef private coreRef;

    event CoreUpdate(address indexed oldCore, address indexed newCore);

    function setUp() public {
        core = getCore(vm);

        coreRef = new MockCoreRef(address(core));

        vm.label(address(core), "Core");
        vm.label(address(coreRef), "CoreRef");
    }

    function testSetup() public {
        assertEq(address(coreRef.core()), address(core));
    }

    function testMinter(address caller) public {
        vm.assume(caller != address(0));

        vm.startPrank(caller);

        if (!core.hasRole(Roles.MINTER_PROTOCOL_ROLE, caller)) {
            vm.expectRevert("CoreRef: no role on core");
        }
        coreRef.testMinter();
        vm.stopPrank();
    }

    function testAdmin(address caller) public {
        vm.assume(caller != address(0));

        vm.startPrank(caller);

        if (!core.hasRole(Roles.ADMIN, caller)) {
            vm.expectRevert("CoreRef: no role on core");
        }
        coreRef.testAdmin();
        vm.stopPrank();
    }

    function testSetCoreGovSucceeds() public {
        Core core2 = getCore(vm);
        vm.prank(addresses.adminAddress);

        vm.expectEmit(true, true, false, true, address(coreRef));
        emit CoreUpdate(address(core), address(core2));

        coreRef.setCore(address(core2));

        assertEq(address(coreRef.core()), address(core2));
    }

    function testSetCoreAddressZeroGovSucceedsBricksContract() public {
        vm.prank(addresses.adminAddress);
        vm.expectEmit(true, true, false, true, address(coreRef));
        emit CoreUpdate(address(core), address(0));

        coreRef.setCore(address(0));

        assertEq(address(coreRef.core()), address(0));

        /// all calls made to Core fail because it is calling address 0
        vm.expectRevert();
        coreRef.testMinter();

        vm.expectRevert();
        coreRef.testTokenGovernor();

        vm.expectRevert();
        coreRef.testGuardian();
    }

    function testSetCoreToAddress0GovSucceeds() public {
        vm.prank(addresses.adminAddress);

        vm.expectEmit(true, true, false, true, address(coreRef));
        emit CoreUpdate(address(core), address(0));

        coreRef.setCore(address(0));

        assertEq(address(coreRef.core()), address(0));

        vm.prank(addresses.tokenGovernorAddress);
        vm.expectRevert();
        coreRef.setCore(address(core));
    }

    function testSetCoreNonGovFails() public {
        vm.expectRevert("CoreRef: no role on core");
        coreRef.setCore(address(0));

        assertEq(address(coreRef.core()), address(core));
    }

    function testMinterAsMinter() public {
        vm.prank(addresses.minterAddress);
        coreRef.testMinter();
    }

    function testFinancialControllerAsFinancialController() public {
        vm.prank(addresses.financialControllerAddress);
        coreRef.testFinancialController();
    }

    function testFinancialController(address caller) public {
        if (!core.hasRole(Roles.FINANCIAL_CONTROLLER_PROTOCOL_ROLE, caller)) {
            vm.expectRevert("CoreRef: no role on core");
        }
        vm.prank(caller);
        coreRef.testFinancialController();
    }

    function testGuardianAsGuardian() public {
        vm.prank(addresses.guardianAddress);
        coreRef.testGuardian();
    }

    function testLocker() public {
        vm.expectRevert("CoreRef: no role on core");
        coreRef.testLocker();
    }

    function testLockerAsLocker() public {
        vm.prank(addresses.lockerAddress);
        coreRef.testLocker();
    }

    function testTokenGovernor(address caller) public {
        if (!core.hasRole(Roles.GOVERNOR_DAO_PROTOCOL_ROLE, caller)) {
            vm.expectRevert("CoreRef: no role on core");
        }
        vm.prank(caller);
        coreRef.testTokenGovernor();
    }

    function testGuardian(address caller) public {
        if (!core.hasRole(Roles.GUARDIAN, caller)) {
            vm.expectRevert("CoreRef: no role on core");
        }

        vm.prank(caller);
        coreRef.testGuardian();
    }

    /// ---------- ACL ----------

    function testPauseSucceedsGovernor() public {
        assertTrue(!coreRef.paused());
        vm.prank(addresses.tokenGovernorAddress);
        coreRef.pause();
        assertTrue(coreRef.paused());
    }

    function testPauseFailsNonGovernor() public {
        vm.expectRevert("CoreRef: no role on core");
        coreRef.pause();
    }

    function testEmergencyActionSucceedsAdminSendEth(uint128 sendAmount) public {
        uint256 startingEthBalance = address(this).balance;

        MockCoreRef.Call[] memory calls = new MockCoreRef.Call[](1);
        calls[0].target = address(this);
        calls[0].value = sendAmount;
        vm.deal(address(coreRef), sendAmount);

        vm.prank(addresses.adminAddress);
        coreRef.emergencyAction(calls);

        uint256 endingEthBalance = address(this).balance;

        assertEq(endingEthBalance - startingEthBalance, sendAmount);
        assertEq(address(coreRef).balance, 0);
    }

    function testEmergencyActionFailsNonAdmin() public {
        MockCoreRef.Call[] memory calls = new MockCoreRef.Call[](1);
        calls[0].target = address(this);
        calls[0].value = 0;

        vm.expectRevert("CoreRef: no role on core");
        coreRef.emergencyAction(calls);
    }

    function testEmergencyActionFailsZeroAddressTarget() public {
        MockCoreRef.Call[] memory calls = new MockCoreRef.Call[](1);
        calls[0].target = address(0);
        calls[0].value = 0;

        vm.prank(addresses.adminAddress);
        vm.expectRevert("CoreRef: taget cannot be address(0)");
        coreRef.emergencyAction(calls);
    }

    function testUnpauseSucceedsAdmin() public {
        // First pause
        vm.prank(addresses.adminAddress);
        coreRef.pause();
        assertTrue(coreRef.paused());

        // Then unpause
        vm.prank(addresses.adminAddress);
        coreRef.unpause();
        assertFalse(coreRef.paused());
    }

    function testUnpauseSucceedsGuardian() public {
        // First pause
        vm.prank(addresses.adminAddress);
        coreRef.pause();
        assertTrue(coreRef.paused());

        // Then unpause as guardian
        vm.prank(addresses.guardianAddress);
        coreRef.unpause();
        assertFalse(coreRef.paused());
    }

    function testUnpauseFailsNonAuthorized() public {
        // First pause
        vm.prank(addresses.adminAddress);
        coreRef.pause();

        // Try to unpause without role
        vm.expectRevert("CoreRef: no role on core");
        coreRef.unpause();
    }

    /// hasRole modifier tests

    function testHasRoleModifierSucceeds() public {
        vm.prank(addresses.minterAddress);
        coreRef.testHasRoleMinter();
    }

    function testHasRoleModifierFails() public {
        vm.expectRevert("CoreRef: no role on core");
        coreRef.testHasRoleMinter();
    }

    /// hasAnyOfTwoRoles modifier tests

    function testHasAnyOfTwoRolesSucceedsWithFirstRole() public {
        vm.prank(addresses.adminAddress);
        coreRef.testHasAnyOfTwoRoles();
    }

    function testHasAnyOfTwoRolesSucceedsWithSecondRole() public {
        vm.prank(addresses.guardianAddress);
        coreRef.testHasAnyOfTwoRoles();
    }

    function testHasAnyOfTwoRolesFails() public {
        vm.prank(addresses.minterAddress); // minter has neither ADMIN nor GUARDIAN
        vm.expectRevert("CoreRef: no role on core");
        coreRef.testHasAnyOfTwoRoles();
    }

    /// hasAnyOfFourRoles modifier tests

    function testHasAnyOfFourRolesSucceedsWithFirstRole() public {
        vm.prank(addresses.adminAddress);
        coreRef.testHasAnyOfFourRoles();
    }

    function testHasAnyOfFourRolesSucceedsWithSecondRole() public {
        vm.prank(addresses.guardianAddress);
        coreRef.testHasAnyOfFourRoles();
    }

    function testHasAnyOfFourRolesSucceedsWithThirdRole() public {
        vm.prank(addresses.tokenGovernorAddress);
        coreRef.testHasAnyOfFourRoles();
    }

    function testHasAnyOfFourRolesSucceedsWithFourthRole() public {
        vm.prank(addresses.minterAddress);
        coreRef.testHasAnyOfFourRoles();
    }

    function testHasAnyOfFourRolesFails() public {
        vm.prank(addresses.financialControllerAddress); // has none of the 4 roles
        vm.expectRevert("CoreRef: no role on core");
        coreRef.testHasAnyOfFourRoles();
    }

    receive() external payable {}
}
