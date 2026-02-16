pragma solidity 0.8.28;

import "@forge-std/Test.sol";

import {Core} from "@protocol/core/Core.sol";
import {Roles} from "@protocol/core/Roles.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {Constants} from "@protocol/Constants.sol";
import {ERC20Splitter} from "@protocol/finance/ERC20Splitter.sol";
import {MockERC20, IERC20} from "test/mock/MockERC20.sol";
import {GlobalReentrancyLock} from "@protocol/core/GlobalReentrancyLock.sol";
import {ERC1155MaxSupplyMintable} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";
import {ERC1155AutoGraphMinter} from "@protocol/nfts/ERC1155AutoGraphMinter.sol";
import {ERC1155AutoGraphBatchMinter} from "@protocol/nfts/ERC1155AutoGraphBatchMinter.sol";
import {TestAddresses as addresses} from "test/fixtures/TestAddresses.sol";
import {ERC1155AutoGraphMinterHelperLib as Helper} from "test/helpers/ERC1155AutoGraphMinterHelper.sol";
import {BaseTest} from "test/BaseTest.sol";

contract UnitTestERC1155AutoGraphMinter is BaseTest {
    ERC1155AutoGraphMinter private _autoGraphMinter;
    ERC1155AutoGraphBatchMinter private _autoGraphBatchMinter;

    uint256 private _privateKey;
    address private _notary;

    /// ------ Whitelist setting ---------- ///

    address[] public defaultWhitelistedAddresses = [address(0x987), address(0x654), address(0x321)];
    address[] public addressesToAdd = [address(0x123), address(0x456), address(0x789)];

    /// ------ Rate limiting setting ------ ///

    /// @notice rate limit per second in RateLimitedV2
    uint128 private constant _REPLENISH_RATE_PER_SECOND = 100;

    /// @notice buffer cap in RateLimited
    uint128 private constant _BUFFER_CAP = 1_000;

    address private _defaultPaymentRecipient = address(0x123);

    function setUp() public override {
        super.setUp();

        string memory mnemonic = "test test test test test test test test test test test junk";
        _privateKey = vm.deriveKey(mnemonic, "m/44'/60'/0'/1/", 0);
        _notary = vm.addr(_privateKey);

        _autoGraphMinter = new ERC1155AutoGraphMinter(
            address(core),
            defaultWhitelistedAddresses,
            _REPLENISH_RATE_PER_SECOND,
            _BUFFER_CAP,
            _defaultPaymentRecipient,
            1
        );

        _autoGraphBatchMinter = new ERC1155AutoGraphBatchMinter(
            address(core),
            _autoGraphMinter,
            _REPLENISH_RATE_PER_SECOND,
            _BUFFER_CAP
        );

        vm.startPrank(addresses.adminAddress);
        _autoGraphMinter.addWhitelistedContract(address(nft));
        nft.setSupplyCap(0, supplyCap);
        core.grantRole(Roles.MINTER_PROTOCOL_ROLE, address(_autoGraphMinter));
        core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, address(_autoGraphMinter));
        core.grantRole(Roles.MINTER_PROTOCOL_ROLE, address(_autoGraphBatchMinter));
        core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, address(_autoGraphBatchMinter));
        core.grantRole(Roles.MINTER_NOTARY_PROTOCOL_ROLE, _notary);
        vm.stopPrank();
    }

    /// --------------------- Testing Hash functions --------------------- ///

    function testHashEncoding() public {
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));

        // setup hash manually
        bytes32 hashFirstPass = keccak256(
            abi.encode(
                parts.recipient,
                parts.jobId,
                parts.tokenId,
                parts.units,
                parts.salt,
                address(nft),
                address(0),
                0,
                block.timestamp
            )
        );
        bytes32 expectedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hashFirstPass));

        assertEq(parts.hash, expectedHash);
    }

    function testRecoverSigner() public {
        // hash'ed messages parameters
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));

        // recover signer
        address signer = _autoGraphMinter.recoverSigner(parts.hash, parts.signature);

        // assert signer is the same as the signer of the hash
        assertEq(signer, vm.addr(_privateKey));
    }

    /// --------------------- Testing Mint for free functions --------------------- ///

    function testMintForFreeWithExpiredHash() public {
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));

        // mint
        _autoGraphMinter.mintForFree(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            block.timestamp
        );

        // assert balance
        assertEq(nft.balanceOf(parts.recipient, parts.tokenId), parts.units);

        vm.expectRevert("ERC1155AutoGraphMinter: Job already completed");
        _autoGraphMinter.mintForFree(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            block.timestamp
        );
    }

    function testMintForFreeWithExpiredJob() public {
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));

        // mint
        _autoGraphMinter.mintForFree(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            parts.expiryToken
        );

        // assert balance
        assertEq(nft.balanceOf(parts.recipient, parts.tokenId), parts.units);

        // expired job with valid hash
        parts = Helper.setupTx(
            Helper.SetupTxParams(vm, _privateKey, address(nft), 99, 1, 1, address(0), 0, block.timestamp)
        );
        vm.expectRevert("ERC1155AutoGraphMinter: Job already completed");
        _autoGraphMinter.mintForFree(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            parts.expiryToken
        );
    }

    function testMintForFreeMissingSigningRole() public {
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));

        vm.prank(addresses.adminAddress);
        core.revokeRole(Roles.MINTER_NOTARY_PROTOCOL_ROLE, _notary);

        vm.expectRevert("ERC1155AutoGraphMinter: Missing MINTER_NOTARY Role");
        _autoGraphMinter.mintForFree(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            block.timestamp
        );
    }

    function testMintForFreeInvalidTokenIdHashMismatch() public {
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));

        uint256 _tokenId = 999;

        vm.expectRevert("ERC1155AutoGraphMinter: Hash mismatch");
        _autoGraphMinter.mintForFree(
            parts.recipient,
            parts.jobId,
            _tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            block.timestamp
        );
    }

    function testMintForFreeInvalidUnitstHashMismatch() public {
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));

        uint256 units = 999;

        vm.expectRevert("ERC1155AutoGraphMinter: Hash mismatch");
        _autoGraphMinter.mintForFree(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            block.timestamp
        );
    }

    function testMintForFreeInvalidNftContractAddress() public {
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));

        vm.expectRevert("WhitelistedAddress: Provided address is not whitelisted");
        _autoGraphMinter.mintForFree(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(0x123),
            block.timestamp
        );
    }

    function testMintForFreeInvalidSalt() public {
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));

        vm.expectRevert("ERC1155AutoGraphMinter: Hash mismatch");
        _autoGraphMinter.mintForFree(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            block.timestamp + 1,
            parts.signature,
            address(nft),
            block.timestamp
        );
    }

    function testMintForFreeInvalidRecipient() public {
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));

        vm.expectRevert("ERC1155AutoGraphMinter: Hash mismatch");
        _autoGraphMinter.mintForFree(
            address(0x123),
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            block.timestamp
        );
    }

    /// --------------------- Testing Mint With paymentToken Fee functions --------------------- ///

    function testMintWithPaymentTokenSuccessAndExpiredHash() public {
        uint paymentAmount = 111;
        Helper.TxParts memory parts = Helper.setupTx(
            vm,
            _privateKey,
            address(nft),
            address(token),
            paymentAmount,
            block.timestamp
        );

        token.mint(address(this), paymentAmount);
        token.approve(address(_autoGraphMinter), paymentAmount);

        ERC1155AutoGraphMinter.MintWithPaymentTokenAsFeeParams memory inputs = ERC1155AutoGraphMinter
            .MintWithPaymentTokenAsFeeParams(
                parts.recipient,
                parts.jobId,
                parts.tokenId,
                parts.units,
                parts.hash,
                parts.salt,
                parts.signature,
                address(nft),
                address(token),
                111,
                block.timestamp
            );

        _autoGraphMinter.mintWithPaymentTokenAsFee(inputs);

        assertEq(nft.balanceOf(parts.recipient, parts.tokenId), parts.units);
        assertEq(token.balanceOf(address(_defaultPaymentRecipient)), paymentAmount);

        vm.expectRevert("ERC1155AutoGraphMinter: Job already completed");
        _autoGraphMinter.mintWithPaymentTokenAsFee(inputs);
    }

    function testMintWithPaymentTokenInvalidPaymentToken() public {
        Helper.TxParts memory parts = Helper.setupTx(
            vm,
            _privateKey,
            address(nft),
            address(token),
            111,
            block.timestamp
        );

        ERC1155AutoGraphMinter.MintWithPaymentTokenAsFeeParams memory inputs = ERC1155AutoGraphMinter
            .MintWithPaymentTokenAsFeeParams(
                parts.recipient,
                parts.jobId,
                parts.tokenId,
                parts.units,
                parts.hash,
                parts.salt,
                parts.signature,
                address(nft),
                address(0),
                111,
                block.timestamp
            );

        vm.expectRevert("ERC1155AutoGraphMinter: paymentToken must not be address(0)");
        _autoGraphMinter.mintWithPaymentTokenAsFee(inputs);
    }

    function testMintWithPaymentTokenInvalidPaymentAmount() public {
        Helper.TxParts memory parts = Helper.setupTx(
            vm,
            _privateKey,
            address(nft),
            address(token),
            111,
            block.timestamp
        );

        ERC1155AutoGraphMinter.MintWithPaymentTokenAsFeeParams memory inputs = ERC1155AutoGraphMinter
            .MintWithPaymentTokenAsFeeParams(
                parts.recipient,
                parts.jobId,
                parts.tokenId,
                parts.units,
                parts.hash,
                parts.salt,
                parts.signature,
                address(nft),
                address(token),
                0,
                block.timestamp
            );

        vm.expectRevert("ERC1155AutoGraphMinter: paymentAmount must be greater than 0");
        _autoGraphMinter.mintWithPaymentTokenAsFee(inputs);
    }

    function testMintWithWithPaymentTokenIncorrectFeeAmount() public {
        Helper.TxParts memory parts = Helper.setupTx(
            vm,
            _privateKey,
            address(nft),
            address(token),
            10_000,
            block.timestamp
        );

        ERC1155AutoGraphMinter.MintWithPaymentTokenAsFeeParams memory inputs = ERC1155AutoGraphMinter
            .MintWithPaymentTokenAsFeeParams(
                parts.recipient,
                parts.jobId,
                parts.tokenId,
                parts.units,
                parts.hash,
                parts.salt,
                parts.signature,
                address(nft),
                address(token),
                1000,
                block.timestamp
            );

        // mint
        vm.expectRevert("ERC1155AutoGraphMinter: Hash mismatch");
        _autoGraphMinter.mintWithPaymentTokenAsFee(inputs);
    }

    /// --------------------- Testing Mint for ETH Fee functions --------------------- ///

    function testMintWithEthAsFeeWithExpiredHash() public {
        emit log_named_decimal_uint("balance", address(this).balance, 18);
        uint256 paymentAmount = 10_000;

        Helper.TxParts memory parts = Helper.setupTx(
            vm,
            _privateKey,
            address(nft),
            address(0),
            paymentAmount,
            block.timestamp
        );

        ERC1155AutoGraphMinter.MintWithEthAsFeeParams memory inputs = ERC1155AutoGraphMinter.MintWithEthAsFeeParams(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            paymentAmount,
            block.timestamp
        );

        _autoGraphMinter.mintWithEthAsFee{value: paymentAmount}(inputs);

        // assert nft balance
        assertEq(nft.balanceOf(parts.recipient, parts.tokenId), parts.units);

        // assert payment Fee balance
        assertEq(address(_defaultPaymentRecipient).balance, paymentAmount);

        vm.expectRevert("ERC1155AutoGraphMinter: Job already completed");
        _autoGraphMinter.mintWithEthAsFee{value: paymentAmount}(inputs);
    }

    function testMintWithEthAsFeeWithExpiredJob() public {
        emit log_named_decimal_uint("balance", address(this).balance, 18);
        uint256 paymentAmount = 10_000;

        Helper.TxParts memory parts = Helper.setupTx(
            vm,
            _privateKey,
            address(nft),
            address(0),
            paymentAmount,
            block.timestamp
        );

        ERC1155AutoGraphMinter.MintWithEthAsFeeParams memory inputs = ERC1155AutoGraphMinter.MintWithEthAsFeeParams(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            paymentAmount,
            block.timestamp
        );

        _autoGraphMinter.mintWithEthAsFee{value: paymentAmount}(inputs);

        // assert nft balance
        assertEq(nft.balanceOf(parts.recipient, parts.tokenId), parts.units);

        // assert payment Fee balance
        assertEq(address(_defaultPaymentRecipient).balance, paymentAmount);

        // expired job with valid hash
        parts = Helper.setupTx(
            Helper.SetupTxParams(vm, _privateKey, address(nft), 99, 1, 1, address(0), paymentAmount, block.timestamp)
        );
        inputs = ERC1155AutoGraphMinter.MintWithEthAsFeeParams(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            paymentAmount,
            block.timestamp
        );

        vm.expectRevert("ERC1155AutoGraphMinter: Job already completed");
        _autoGraphMinter.mintWithEthAsFee{value: paymentAmount}(inputs);
    }

    function testMintWithEthAsFeeIncorrectEthAmount() public {
        uint256 paymentAmount = 10_000;

        Helper.TxParts memory parts = Helper.setupTx(
            vm,
            _privateKey,
            address(nft),
            address(0),
            paymentAmount,
            block.timestamp
        );

        ERC1155AutoGraphMinter.MintWithEthAsFeeParams memory inputs = ERC1155AutoGraphMinter.MintWithEthAsFeeParams(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            paymentAmount,
            block.timestamp
        );

        vm.expectRevert("ERC1155AutoGraphMinter: Payment amount does not match msg.value");
        _autoGraphMinter.mintWithEthAsFee{value: paymentAmount / 2}(inputs);
    }

    function testMintWithEthAsFeeIncorrectEthAmount0() public {
        uint256 paymentAmount = 10_000;

        Helper.TxParts memory parts = Helper.setupTx(
            vm,
            _privateKey,
            address(nft),
            address(0),
            paymentAmount,
            block.timestamp
        );

        ERC1155AutoGraphMinter.MintWithEthAsFeeParams memory inputs = ERC1155AutoGraphMinter.MintWithEthAsFeeParams(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            0,
            block.timestamp
        );

        vm.expectRevert("ERC1155AutoGraphMinter: paymentAmount must be greater than 0");
        _autoGraphMinter.mintWithEthAsFee{value: paymentAmount / 2}(inputs);
    }

    /// --------------------- Testing Mint Batch for free functions --------------------- ///

    function testMintBatchForFreeSucessAndExpireHash() public {
        ERC1155AutoGraphMinter.MintBatchParams[] memory params = Helper.setupTxs(
            vm,
            _privateKey,
            nft,
            addresses.adminAddress
        );

        // mint
        _autoGraphBatchMinter.mintBatchForFree(address(nft), address(this), params);

        // assert balance
        for (uint256 i = 0; i < params.length; i++) {
            assertEq(nft.balanceOf(address(this), i), 10);
        }

        vm.expectRevert("ERC1155AutoGraphMinter: Job already completed");
        _autoGraphBatchMinter.mintBatchForFree(address(nft), address(this), params);
    }

    function testMintBatchForFreeIncorrectSigningRole() public {
        ERC1155AutoGraphMinter.MintBatchParams[] memory params = Helper.setupTxs(
            vm,
            _privateKey,
            nft,
            addresses.adminAddress
        );

        vm.prank(addresses.adminAddress);
        core.revokeRole(Roles.MINTER_NOTARY_PROTOCOL_ROLE, _notary);

        vm.expectRevert("ERC1155AutoGraphMinter: Missing MINTER_NOTARY Role");
        _autoGraphBatchMinter.mintBatchForFree(address(nft), address(this), params);
    }

    function testMintBatchForFreeInvalidUnits() public {
        ERC1155AutoGraphMinter.MintBatchParams[] memory params = Helper.setupTxs(
            vm,
            _privateKey,
            nft,
            addresses.adminAddress
        );

        params[params.length - 1].units = 999;

        vm.expectRevert("ERC1155AutoGraphMinter: Hash mismatch");
        _autoGraphBatchMinter.mintBatchForFree(address(nft), address(this), params);
    }

    /// --------------------- Testing Mint Batch With PaymentToken as fee functions --------------------- ///

    function testMintBatchWithPaymentTokenAsFeeSucceedsAndExpiresHash() public {
        uint256 testItems = 10;
        uint256 paymentAmountPerMint = 10_000;
        uint256 totalCost = testItems * paymentAmountPerMint;
        ERC1155AutoGraphMinter.MintBatchParams[] memory params = Helper.setupTxs(
            vm,
            _privateKey,
            nft,
            0,
            addresses.adminAddress,
            testItems,
            address(token),
            paymentAmountPerMint,
            block.timestamp
        );

        token.mint(address(this), totalCost);
        token.approve(address(_autoGraphBatchMinter), totalCost);

        // mint
        _autoGraphBatchMinter.mintBatchWithPaymentTokenAsFee(address(nft), address(this), address(token), params);

        // assert balance
        for (uint256 i = 0; i < params.length; i++) {
            assertEq(nft.balanceOf(address(this), i), testItems);
        }

        // assert token balance payment
        assertEq(token.balanceOf(address(_defaultPaymentRecipient)), totalCost, "Payment token balance incorrect");

        vm.expectRevert("ERC1155AutoGraphMinter: Job already completed");
        _autoGraphBatchMinter.mintBatchWithPaymentTokenAsFee(address(nft), address(this), address(token), params);
    }

    /// --------------------- Testing Mint Batch With Eth as Fee functions --------------------- ///

    function testMintBatchWithEthAsFeeShouldSucceedsAndExpiresHash() public {
        uint256 testItems = 10;
        uint256 paymentAmountPerMint = 10_000;
        uint256 totalCost = testItems * paymentAmountPerMint;
        ERC1155AutoGraphMinter.MintBatchParams[] memory params = Helper.setupTxs(
            vm,
            _privateKey,
            nft,
            0,
            addresses.adminAddress,
            testItems,
            address(0),
            paymentAmountPerMint,
            block.timestamp
        );

        // mint
        _autoGraphBatchMinter.mintBatchWithEthAsFee{value: totalCost}(address(nft), address(this), params);

        // assert balance
        for (uint256 i = 0; i < params.length; i++) {
            assertEq(nft.balanceOf(address(this), i), testItems);
        }

        // assert token balance payment
        assertEq(address(_defaultPaymentRecipient).balance, totalCost);
    }

    function testMintBatchWithEthAsFeeIncorrectAmount() public {
        uint256 testItems = 10;
        uint256 paymentAmountPerMint = 10_000;
        uint256 totalCost = testItems * paymentAmountPerMint;
        ERC1155AutoGraphMinter.MintBatchParams[] memory params = Helper.setupTxs(
            vm,
            _privateKey,
            nft,
            0,
            addresses.adminAddress,
            testItems,
            address(0),
            paymentAmountPerMint,
            block.timestamp
        );

        vm.expectRevert("ERC1155AutoGraphMinter: Payment amount does not match msg.value");
        _autoGraphBatchMinter.mintBatchWithEthAsFee{value: totalCost / 2}(address(nft), address(this), params);
    }

    /// --------------------- Testing Update Payment Recipient functions  --------------------- ///

    function testUpdatePaymentRecipient() public {
        vm.prank(addresses.adminAddress);
        _autoGraphMinter.updatePaymentRecipient(address(0x123));
        assertEq(_autoGraphMinter.paymentRecipient(), address(0x123));
    }

    function testUpdatePaymentRecipientInvalidAddress() public {
        vm.prank(addresses.adminAddress);
        vm.expectRevert("ERC1155AutoGraphMinter: paymentRecipient must not be address(0)");
        _autoGraphMinter.updatePaymentRecipient(address(0));
    }

    function testUpdatePaymentRecipientFail() public {
        vm.expectRevert("CoreRef: no role on core");
        _autoGraphMinter.updatePaymentRecipient(address(0x123));
    }

    /// --------------------- Testing Whitelisting functions  --------------------- ///

    function testAddWhitelistedContractAdmin() public {
        assertFalse(_autoGraphMinter.isWhitelistedAddress(address(0x123)));
        vm.prank(addresses.adminAddress);
        _autoGraphMinter.addWhitelistedContract(address(0x123));
        assertTrue(_autoGraphMinter.isWhitelistedAddress(address(0x123)));
    }

    function testAddWhitelistedContractGoveror() public {
        assertFalse(_autoGraphMinter.isWhitelistedAddress(address(0x123)));
        vm.prank(addresses.tokenGovernorAddress);
        _autoGraphMinter.addWhitelistedContract(address(0x123));
        assertTrue(_autoGraphMinter.isWhitelistedAddress(address(0x123)));
    }

    function testAddWhitelistedContractFail() public {
        assertFalse(_autoGraphMinter.isWhitelistedAddress(address(0x123)));
        vm.expectRevert("CoreRef: no role on core");
        _autoGraphMinter.addWhitelistedContract(address(0x123));
    }

    function testAddWhitelistedContractsFail() public {
        vm.expectRevert("CoreRef: no role on core");
        _autoGraphMinter.addWhitelistedContracts(addressesToAdd);
    }

    function testAddWhitelistedContracts() public {
        vm.prank(addresses.adminAddress);
        _autoGraphMinter.addWhitelistedContracts(addressesToAdd);
        assertTrue(_autoGraphMinter.isWhitelistedAddress(address(0x123)));
        assertTrue(_autoGraphMinter.isWhitelistedAddress(address(0x456)));
        assertTrue(_autoGraphMinter.isWhitelistedAddress(address(0x789)));
    }

    function testRemoveWhitelistedContract() public {
        vm.prank(addresses.adminAddress);
        _autoGraphMinter.removeWhitelistedContract(address(0x321));
        assertFalse(_autoGraphMinter.isWhitelistedAddress(address(0x321)));
    }

    function testRemoveWhitelistedContractFail() public {
        vm.expectRevert("CoreRef: no role on core");
        _autoGraphMinter.removeWhitelistedContract(address(0x321));
    }

    function testRemoveWhitelistedContracts() public {
        vm.prank(addresses.adminAddress);
        _autoGraphMinter.removeWhitelistedContracts(defaultWhitelistedAddresses);
        assertFalse(_autoGraphMinter.isWhitelistedAddress(address(0x987)));
        assertFalse(_autoGraphMinter.isWhitelistedAddress(address(0x654)));
        assertFalse(_autoGraphMinter.isWhitelistedAddress(address(0x321)));
    }

    function testRemoveWhitelistedContractsFail() public {
        vm.expectRevert("CoreRef: no role on core");
        _autoGraphMinter.removeWhitelistedContracts(defaultWhitelistedAddresses);
    }

    /// --------------------- Testing Update ExpiryTokenHoursValid  --------------------- ///

    function testUpdateExpiryTokenHoursValid(uint8 _hour) public {
        uint256 h = _bound(_hour, 1, 24);
        vm.prank(addresses.adminAddress);
        _autoGraphMinter.updateExpiryTokenHoursValid(uint8(h));
        assertEq(_autoGraphMinter.expiryTokenHoursValid(), uint8(h));
    }

    function testUpdateExpiryTokenHoursInValid0() public {
        uint8 invalidHour = 0;
        vm.prank(addresses.adminAddress);
        vm.expectRevert("ERC1155AutoGraphMinter: Hours must be between 1 and 24");
        _autoGraphMinter.updateExpiryTokenHoursValid(invalidHour);
    }

    function testUpdateExpiryTokenHoursInValid25() public {
        uint8 invalidHour = 25;
        vm.prank(addresses.adminAddress);
        vm.expectRevert("ERC1155AutoGraphMinter: Hours must be between 1 and 24");
        _autoGraphMinter.updateExpiryTokenHoursValid(invalidHour);
    }

    /// --------------------- Testing ExpiryToken  --------------------- ///

    function testMintForFreeExpiryTokenExpired() public {
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));

        /// warp 1 hour and 1.
        vm.warp(block.timestamp + 1 hours + 1);

        vm.expectRevert("ERC1155AutoGraphMinter: Expiry token is expired");
        _autoGraphMinter.mintForFree(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            parts.expiryToken
        );
    }

    function testMintForFreeExpiryTokenInTheFuture() public {
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));

        vm.expectRevert("ERC1155AutoGraphMinter: Expiry token must be in the past");
        _autoGraphMinter.mintForFree(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            parts.expiryToken + 1 seconds
        );
    }

    function testMintWithEthAsFeeExpireTokenExpired() public {
        uint256 expiryToken = block.timestamp;
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft), address(0), 111, expiryToken);

        /// warp 1 hour and 1.
        vm.warp(block.timestamp + 1 hours + 1);

        ERC1155AutoGraphMinter.MintWithEthAsFeeParams memory inputs = ERC1155AutoGraphMinter.MintWithEthAsFeeParams(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            111,
            expiryToken
        );

        vm.expectRevert("ERC1155AutoGraphMinter: Expiry token is expired");
        _autoGraphMinter.mintWithEthAsFee{value: 111}(inputs);
    }

    function testMintWithEthAsFeeExpiryTokenInTheFuture() public {
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft), address(0), 111, block.timestamp);

        ERC1155AutoGraphMinter.MintWithEthAsFeeParams memory inputs = ERC1155AutoGraphMinter.MintWithEthAsFeeParams(
            parts.recipient,
            parts.jobId,
            parts.tokenId,
            parts.units,
            parts.hash,
            parts.salt,
            parts.signature,
            address(nft),
            111,
            parts.expiryToken + 1 seconds
        );

        vm.expectRevert("ERC1155AutoGraphMinter: Expiry token must be in the past");
        _autoGraphMinter.mintWithEthAsFee{value: 111}(inputs);
    }

    function testMintWithPaymentTokenAsFeeExpiryTokenExpired() public {
        uint256 expiryToken = block.timestamp;
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft), address(token), 111, expiryToken);

        token.mint(address(this), 111);
        token.approve(address(_autoGraphMinter), 111);

        ERC1155AutoGraphMinter.MintWithPaymentTokenAsFeeParams memory inputs = ERC1155AutoGraphMinter
            .MintWithPaymentTokenAsFeeParams(
                parts.recipient,
                parts.jobId,
                parts.tokenId,
                parts.units,
                parts.hash,
                parts.salt,
                parts.signature,
                address(nft),
                address(token),
                111,
                expiryToken
            );

        /// warp 1 hour and 1.
        vm.warp(block.timestamp + 1 hours + 1);

        vm.expectRevert("ERC1155AutoGraphMinter: Expiry token is expired");
        _autoGraphMinter.mintWithPaymentTokenAsFee(inputs);
    }

    function testMintWithPaymentTokenAsFeeExpiryTokenInTheFuture() public {
        Helper.TxParts memory parts = Helper.setupTx(
            vm,
            _privateKey,
            address(nft),
            address(token),
            111,
            block.timestamp
        );

        token.mint(address(this), 111);
        token.approve(address(_autoGraphMinter), 111);

        ERC1155AutoGraphMinter.MintWithPaymentTokenAsFeeParams memory inputs = ERC1155AutoGraphMinter
            .MintWithPaymentTokenAsFeeParams(
                parts.recipient,
                parts.jobId,
                parts.tokenId,
                parts.units,
                parts.hash,
                parts.salt,
                parts.signature,
                address(nft),
                address(token),
                111,
                parts.expiryToken + 1 seconds
            );

        vm.expectRevert("ERC1155AutoGraphMinter: Expiry token must be in the past");
        _autoGraphMinter.mintWithPaymentTokenAsFee(inputs);
    }

    /// --------------------- Testing ExpiryToken Batch Methods --------------------- ///

    function testMintBatchForFreeExpiryTokenExpired() public {
        ERC1155AutoGraphMinter.MintBatchParams[] memory params = Helper.setupTxs(
            vm,
            _privateKey,
            nft,
            addresses.adminAddress
        );

        /// warp 1 hour and 1.
        vm.warp(block.timestamp + 1 hours + 1);

        // mint
        vm.expectRevert("ERC1155AutoGraphMinter: Expiry token is expired");
        _autoGraphBatchMinter.mintBatchForFree(address(nft), address(this), params);
    }

    function testMintBatchWithPaymentTokenAsFeeExpiryTokenExpired() public {
        uint256 testItems = 10;
        uint256 paymentAmountPerMint = 10_000;
        uint256 totalCost = testItems * paymentAmountPerMint;
        ERC1155AutoGraphMinter.MintBatchParams[] memory params = Helper.setupTxs(
            vm,
            _privateKey,
            nft,
            0,
            addresses.adminAddress,
            testItems,
            address(token),
            paymentAmountPerMint,
            block.timestamp
        );

        token.mint(address(this), totalCost);
        token.approve(address(_autoGraphBatchMinter), totalCost);

        /// warp 1 hour and 1.
        vm.warp(block.timestamp + 1 hours + 1);

        // mint
        vm.expectRevert("ERC1155AutoGraphMinter: Expiry token is expired");
        _autoGraphBatchMinter.mintBatchWithPaymentTokenAsFee(address(nft), address(this), address(token), params);
    }

    function testMintBatchWithEthAsFeeExpiryTokenExpired() public {
        uint256 testItems = 10;
        uint256 paymentAmountPerMint = 10_000;
        uint256 totalCost = testItems * paymentAmountPerMint;
        ERC1155AutoGraphMinter.MintBatchParams[] memory params = Helper.setupTxs(
            vm,
            _privateKey,
            nft,
            0,
            addresses.adminAddress,
            testItems,
            address(0),
            paymentAmountPerMint,
            block.timestamp
        );

        /// warp 1 hour and 1.
        vm.warp(block.timestamp + 1 hours + 1);

        // mint
        vm.expectRevert("ERC1155AutoGraphMinter: Expiry token is expired");
        _autoGraphBatchMinter.mintBatchWithEthAsFee{value: totalCost}(address(nft), address(this), params);
    }

    /// @notice Proves that completedJobs[jobId] blocks replay even with a different salt/hash.
    /// This is the key behavioral guarantee after removing expiredHashes:
    /// same jobId + different salt → different hash, but still rejected.
    function testSameJobIdDifferentHashRejected() public {
        // First mint succeeds (jobId=99, salt=block.timestamp)
        Helper.TxParts memory parts1 = Helper.setupTx(vm, _privateKey, address(nft));

        _autoGraphMinter.mintForFree(
            parts1.recipient,
            parts1.jobId,
            parts1.tokenId,
            parts1.units,
            parts1.hash,
            parts1.salt,
            parts1.signature,
            address(nft),
            parts1.expiryToken
        );

        // Warp time → changes salt (block.timestamp) → produces a different hash
        vm.warp(block.timestamp + 1);

        // Setup new tx: same jobId (99) but different salt → different hash
        Helper.TxParts memory parts2 = Helper.setupTx(vm, _privateKey, address(nft));

        // Confirm the hashes are actually different
        assertTrue(parts1.hash != parts2.hash, "hashes should differ when salt differs");

        // Second mint fails: same jobId already completed
        vm.expectRevert("ERC1155AutoGraphMinter: Job already completed");
        _autoGraphMinter.mintForFree(
            parts2.recipient,
            parts2.jobId,
            parts2.tokenId,
            parts2.units,
            parts2.hash,
            parts2.salt,
            parts2.signature,
            address(nft),
            parts2.expiryToken
        );
    }

    /// @notice Proves batch buffer depletion accumulates total units correctly.
    /// Each item is individually below the buffer cap (1000), but the aggregate
    /// exceeds it → proves buffer is depleted once with the sum, not per-item.
    function testBatchMintExceedsBufferCapFails() public {
        // Buffer cap = 1000. Two items with 600 units each = 1200 total > 1000.
        // Each item individually (600) is below the cap, so per-item depletion would pass.
        vm.prank(addresses.adminAddress);
        nft.setSupplyCap(1, supplyCap);

        Helper.SetupTxParams memory txx1 = Helper.SetupTxParams(
            vm, _privateKey, address(nft), 0, 0, 600, address(0), 0, block.timestamp
        );
        Helper.TxParts memory parts1 = Helper.setupTx(txx1);

        Helper.SetupTxParams memory txx2 = Helper.SetupTxParams(
            vm, _privateKey, address(nft), 1, 1, 600, address(0), 0, block.timestamp
        );
        Helper.TxParts memory parts2 = Helper.setupTx(txx2);

        ERC1155AutoGraphMinter.MintBatchParams[] memory params = new ERC1155AutoGraphMinter.MintBatchParams[](2);
        params[0] = ERC1155AutoGraphMinter.MintBatchParams(
            parts1.jobId, parts1.tokenId, parts1.units, parts1.hash, parts1.salt,
            parts1.signature, 0, block.timestamp
        );
        params[1] = ERC1155AutoGraphMinter.MintBatchParams(
            parts2.jobId, parts2.tokenId, parts2.units, parts2.hash, parts2.salt,
            parts2.signature, 0, block.timestamp
        );

        vm.expectRevert("RateLimited: rate limit hit");
        _autoGraphBatchMinter.mintBatchForFree(address(nft), address(this), params);
    }

    /// getHash() direct test for coverage
    function testGetHashReturnsConsistentHash() public view {
        ERC1155AutoGraphMinter.HashInputsParams memory params = ERC1155AutoGraphMinter.HashInputsParams({
            recipient: address(this),
            jobId: 123,
            tokenId: 1,
            units: 10,
            salt: 456,
            nftContract: address(nft),
            paymentToken: address(0),
            paymentAmount: 0,
            expiryToken: block.timestamp
        });

        bytes32 hash1 = _autoGraphMinter.getHash(params);
        bytes32 hash2 = _autoGraphMinter.getHash(params);

        // Same inputs should produce same hash
        assertEq(hash1, hash2);
        // Hash should not be zero
        assertTrue(hash1 != bytes32(0));
    }

    function testGetHashDifferentInputsProduceDifferentHashes() public view {
        ERC1155AutoGraphMinter.HashInputsParams memory params1 = ERC1155AutoGraphMinter.HashInputsParams({
            recipient: address(this),
            jobId: 123,
            tokenId: 1,
            units: 10,
            salt: 456,
            nftContract: address(nft),
            paymentToken: address(0),
            paymentAmount: 0,
            expiryToken: block.timestamp
        });

        ERC1155AutoGraphMinter.HashInputsParams memory params2 = ERC1155AutoGraphMinter.HashInputsParams({
            recipient: address(this),
            jobId: 124, // Different jobId
            tokenId: 1,
            units: 10,
            salt: 456,
            nftContract: address(nft),
            paymentToken: address(0),
            paymentAmount: 0,
            expiryToken: block.timestamp
        });

        bytes32 hash1 = _autoGraphMinter.getHash(params1);
        bytes32 hash2 = _autoGraphMinter.getHash(params2);

        // Different inputs should produce different hashes
        assertTrue(hash1 != hash2);
    }

    /// --------------------- Testing canMintBatchFree --------------------- ///

    function testCanMintBatchFreeAllMintable() public {
        vm.startPrank(addresses.adminAddress);
        nft.setSupplyCap(1, supplyCap);
        nft.setSupplyCap(2, supplyCap);
        vm.stopPrank();

        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        uint256[] memory jobIds = new uint256[](3);
        tokenIds[0] = 0; amounts[0] = 100; jobIds[0] = 10;
        tokenIds[1] = 1; amounts[1] = 200; jobIds[1] = 11;
        tokenIds[2] = 2; amounts[2] = 300; jobIds[2] = 12;

        (bool[] memory mintable, uint256[] memory available) =
            _autoGraphBatchMinter.canMintBatchFree(address(nft), tokenIds, amounts, jobIds);

        assertTrue(mintable[0]);
        assertTrue(mintable[1]);
        assertTrue(mintable[2]);
        assertEq(available[0], supplyCap);
        assertEq(available[1], supplyCap);
        assertEq(available[2], supplyCap);
    }

    function testCanMintBatchFreeWithCompletedJob() public {
        // Mint once via batch minter to mark jobId=99 as completed on batch minter
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));
        ERC1155AutoGraphMinter.MintBatchParams[] memory batchParams = new ERC1155AutoGraphMinter.MintBatchParams[](1);
        batchParams[0] = ERC1155AutoGraphMinter.MintBatchParams(
            parts.jobId, parts.tokenId, parts.units, parts.hash, parts.salt,
            parts.signature, 0, parts.expiryToken
        );
        _autoGraphBatchMinter.mintBatchForFree(address(nft), parts.recipient, batchParams);

        vm.prank(addresses.adminAddress);
        nft.setSupplyCap(1, supplyCap);

        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory jobIds = new uint256[](2);
        tokenIds[0] = 0;  amounts[0] = 10;  jobIds[0] = 99;  // completed
        tokenIds[1] = 1;  amounts[1] = 10;  jobIds[1] = 200; // not completed

        (bool[] memory mintable, uint256[] memory available) =
            _autoGraphBatchMinter.canMintBatchFree(address(nft), tokenIds, amounts, jobIds);

        assertFalse(mintable[0]);
        assertEq(available[0], 0);
        assertTrue(mintable[1]);
        assertEq(available[1], supplyCap);
    }

    function testCanMintBatchFreeWithInsufficientSupply() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory jobIds = new uint256[](1);
        tokenIds[0] = 0;
        amounts[0] = supplyCap + 1;
        jobIds[0] = 10;

        (bool[] memory mintable, uint256[] memory available) =
            _autoGraphBatchMinter.canMintBatchFree(address(nft), tokenIds, amounts, jobIds);

        assertFalse(mintable[0]);
        assertEq(available[0], supplyCap);
    }

    function testCanMintBatchFreeWithUninitializedToken() public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory jobIds = new uint256[](1);
        tokenIds[0] = 999; // never had setSupplyCap called
        amounts[0] = 1;
        jobIds[0] = 10;

        (bool[] memory mintable, uint256[] memory available) =
            _autoGraphBatchMinter.canMintBatchFree(address(nft), tokenIds, amounts, jobIds);

        assertFalse(mintable[0]);
        assertEq(available[0], 0);
    }

    function testCanMintBatchFreeDuplicateTokenIdsWithCompletedJob() public {
        // Setup: tokenId=0 has supplyCap=8
        vm.prank(addresses.adminAddress);
        nft.setSupplyCap(0, 8);

        // Mint once via batch minter to mark jobId=99 as completed
        Helper.TxParts memory parts = Helper.setupTx(vm, _privateKey, address(nft));
        ERC1155AutoGraphMinter.MintBatchParams[] memory batchParams = new ERC1155AutoGraphMinter.MintBatchParams[](1);
        batchParams[0] = ERC1155AutoGraphMinter.MintBatchParams(
            parts.jobId, parts.tokenId, parts.units, parts.hash, parts.salt,
            parts.signature, 0, parts.expiryToken
        );
        _autoGraphBatchMinter.mintBatchForFree(address(nft), parts.recipient, batchParams);
        // tokenId=0 now has totalSupply=1, available=7

        // Batch: 3 items all for tokenId=0
        // Item 0: jobId=99 (completed) — should be skipped, freeing supply for others
        // Item 1: jobId=200, amount=5 — should be mintable (7 available)
        // Item 2: jobId=201, amount=3 — should be mintable (7-5=2? no, 3>2 → false)
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        uint256[] memory jobIds = new uint256[](3);
        tokenIds[0] = 0; amounts[0] = 5; jobIds[0] = 99;  // completed
        tokenIds[1] = 0; amounts[1] = 5; jobIds[1] = 200;
        tokenIds[2] = 0; amounts[2] = 2; jobIds[2] = 201;

        (bool[] memory mintable, uint256[] memory available) =
            _autoGraphBatchMinter.canMintBatchFree(address(nft), tokenIds, amounts, jobIds);

        // Item 0: completed job → not mintable
        assertFalse(mintable[0]);
        assertEq(available[0], 0);

        // Item 1: no prior mintable demand for tokenId=0 (item 0 skipped) → 7 available
        assertTrue(mintable[1]);
        assertEq(available[1], 7);

        // Item 2: prior mintable demand = 5 (from item 1) → 7-5=2, amount=2 ≤ 2 → mintable
        assertTrue(mintable[2]);
        assertEq(available[2], 2);
    }

    function testCanMintBatchFreeDuplicateTokenIdsExceedSupply() public {
        // tokenId=0 has supplyCap (10_000 from BaseTest)
        // 3 items all for tokenId=0, each wanting 4000
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        uint256[] memory jobIds = new uint256[](3);
        tokenIds[0] = 0; amounts[0] = 4000; jobIds[0] = 10;
        tokenIds[1] = 0; amounts[1] = 4000; jobIds[1] = 11;
        tokenIds[2] = 0; amounts[2] = 4000; jobIds[2] = 12;

        (bool[] memory mintable, uint256[] memory available) =
            _autoGraphBatchMinter.canMintBatchFree(address(nft), tokenIds, amounts, jobIds);

        // Item 0: 10000 available, 4000 ≤ 10000 → true
        assertTrue(mintable[0]);
        assertEq(available[0], supplyCap);

        // Item 1: 10000 - 4000 = 6000 available, 4000 ≤ 6000 → true
        assertTrue(mintable[1]);
        assertEq(available[1], 6000);

        // Item 2: 10000 - 8000 = 2000 available, 4000 > 2000 → false
        assertFalse(mintable[2]);
        assertEq(available[2], 2000);
    }

    function testCanMintBatchFreeEmptyArrays() public view {
        uint256[] memory tokenIds = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        uint256[] memory jobIds = new uint256[](0);

        (bool[] memory mintable, uint256[] memory available) =
            _autoGraphBatchMinter.canMintBatchFree(address(nft), tokenIds, amounts, jobIds);

        assertEq(mintable.length, 0);
        assertEq(available.length, 0);
    }

    function testCanMintBatchFreeLengthMismatchReverts() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory jobIds = new uint256[](2);

        vm.expectRevert("ERC1155AutoGraphMinter: length mismatch");
        _autoGraphBatchMinter.canMintBatchFree(address(nft), tokenIds, amounts, jobIds);
    }
}
