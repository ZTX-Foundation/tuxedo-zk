pragma solidity 0.8.18;

import {IERC5633, IERC5192} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";

import "test/BaseTest.sol";

contract UnitTestERC1155MaxSupplyMintable is BaseTest {
    // Events for testing
    event Soulbound(uint256 indexed id, bool bounded);
    event Locked(uint256 tokenId);
    event Unlocked(uint256 tokenId);

    function setUp() public override {
        super.setUp();
    }

    function testSetup() public {
        assertEq(address(nft.core()), address(core));
        assertEq("https://exampleUri.com/0", nft.uri(0));
        assertEq(nft.name(), "NFT");
        assertEq(nft.symbol(), "NFT");
        assertEq(nft.getMintAmountLeft(tokenId), supplyCap);
        assertEq(nft.totalSupply(tokenId), 0);
    }

    /// ACL Tests

    function testMintWithoutRoleFails() public {
        vm.expectRevert("CoreRef: no role on core");
        nft.mint(address(this), tokenId, 100);
    }

    function testMintBatchWithoutRoleFails() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.expectRevert("CoreRef: no role on core");
        nft.mintBatch(address(this), tokenIds, amounts);
    }

    function testSetURIWithoutRoleFails() public {
        vm.expectRevert("CoreRef: no role on core");
        nft.setURI("https://exampleUri1.com/");
    }

    function testSetURIWithRoleSucceeds() public {
        vm.prank(addresses.adminAddress);
        nft.setURI("https://exampleUri1.com/");
        assertEq("https://exampleUri1.com/0", nft.uri(0));
    }

    function testSetTokenSupplyCapWithoutRoleFails() public {
        vm.expectRevert("CoreRef: no role on core");
        nft.setSupplyCap(tokenId, supplyCap);
    }

    function testSetTokenSupplyCapWithRoleSucceeds() public {
        vm.prank(addresses.adminAddress);
        nft.setSupplyCap(tokenId + 1, supplyCap);

        assertEq(nft.getMintAmountLeft(tokenId + 1), supplyCap);
        assertEq(nft.maxTokenSupply(tokenId + 1), supplyCap);
    }

    function testSetTokenSupplyCapUnderSupplyFails() public {
        testMintSucceedsMinter(10_000);

        vm.expectRevert("BaseERC1155NFT: maxSupply cannot be less than current supply");
        vm.prank(addresses.adminAddress);
        nft.setSupplyCap(tokenId, supplyCap - 1);
    }

    function testSetSupplyCapAndNonTransferableWithoutRoleFails() public {
        vm.expectRevert("CoreRef: no role on core");
        nft.setSupplyCapAndNonTransferable(tokenId, supplyCap, true);
    }

    function testSetSupplyCapAndNonTransferableWithRoleSucceeds() public {
        uint256 newTokenId = tokenId + 1;
        uint256 newSupplyCap = 5000;
        bool isNonTransferable = true;

        vm.expectEmit(true, false, false, true);
        emit Soulbound(newTokenId, true);
        vm.expectEmit(true, false, false, false);
        emit Locked(newTokenId);

        vm.prank(addresses.adminAddress);
        nft.setSupplyCapAndNonTransferable(newTokenId, newSupplyCap, isNonTransferable);

        assertEq(nft.maxTokenSupply(newTokenId), newSupplyCap);
        assertEq(nft.getMintAmountLeft(newTokenId), newSupplyCap);
        assertEq(nft.nonTransferableTokens(newTokenId), isNonTransferable);
        assertTrue(nft.isSoulbound(newTokenId));
        assertTrue(nft.locked(newTokenId));
    }

    function testSetSupplyCapAndNonTransferableWithZeroMaxSupplyFails() public {
        uint256 newTokenId = tokenId + 1;

        vm.expectRevert("BaseERC1155NFT: token must have a max supply greater than 0 to set the transferability");
        vm.prank(addresses.adminAddress);
        nft.setSupplyCapAndNonTransferable(newTokenId, 0, true);
    }

    function testSetNonTransferableWithoutRoleFails() public {
        vm.expectRevert("CoreRef: no role on core");
        nft.setNonTransferable(tokenId, true);
    }

    function testSetNonTransferableForUninitializedTokenFails() public {
        uint256 uninitializedTokenId = tokenId + 100;

        vm.expectRevert("BaseERC1155NFT: token must have a max supply greater than 0 to set the transferability");
        vm.prank(addresses.adminAddress);
        nft.setNonTransferable(uninitializedTokenId, true);
    }

    function testSetNonTransferableWithRoleSucceeds() public {
        uint256 newTokenId = tokenId + 1;
        uint256 newSupplyCap = 5000;

        // First set the supply cap to initialize the token
        vm.prank(addresses.adminAddress);
        nft.setSupplyCap(newTokenId, newSupplyCap);

        // Now set non-transferability and expect events
        vm.expectEmit(true, false, false, true);
        emit Soulbound(newTokenId, true);
        vm.expectEmit(true, false, false, false);
        emit Locked(newTokenId);

        vm.prank(addresses.adminAddress);
        nft.setNonTransferable(newTokenId, true);

        assertEq(nft.nonTransferableTokens(newTokenId), true);
        assertTrue(nft.isSoulbound(newTokenId));
        assertTrue(nft.locked(newTokenId));

        // Test setting it back to false and expect Unlocked event
        vm.expectEmit(true, false, false, true);
        emit Soulbound(newTokenId, false);
        vm.expectEmit(true, false, false, false);
        emit Unlocked(newTokenId);

        vm.prank(addresses.adminAddress);
        nft.setNonTransferable(newTokenId, false);

        assertEq(nft.nonTransferableTokens(newTokenId), false);
        assertFalse(nft.isSoulbound(newTokenId));
        assertFalse(nft.locked(newTokenId));
    }

    function testTransferNonTransferableTokenFails() public {
        uint256 newTokenId = tokenId + 1;
        uint256 newSupplyCap = 5000;
        uint256 mintAmount = 100;
        address recipient = address(0x123);

        // Set up a non-transferable token
        vm.prank(addresses.adminAddress);
        nft.setSupplyCapAndNonTransferable(newTokenId, newSupplyCap, true);

        // Mint some tokens
        vm.prank(address(sale));
        lock.lock(1);

        vm.prank(addresses.minterAddress);
        nft.mint(address(this), newTokenId, mintAmount);

        // Try to transfer and expect revert
        vm.expectRevert("BaseERC1155NFT: token is non-transferable");
        nft.safeTransferFrom(address(this), recipient, newTokenId, 1, "");
    }

    function testTransferableTokenCanBeTransferredUntilDisabled() public {
        uint256 newTokenId = tokenId + 1;
        uint256 newSupplyCap = 5000;
        uint256 mintAmount = 100;
        address recipient = address(0x123);

        // Set up a transferable token (isNonTransferable = false)
        vm.prank(addresses.adminAddress);
        nft.setSupplyCapAndNonTransferable(newTokenId, newSupplyCap, false);

        // Mint some tokens
        vm.prank(address(sale));
        lock.lock(1);

        vm.prank(addresses.minterAddress);
        nft.mint(address(this), newTokenId, mintAmount);

        // Transfer should succeed
        nft.safeTransferFrom(address(this), recipient, newTokenId, 1, "");
        assertEq(nft.balanceOf(recipient, newTokenId), 1);
        assertEq(nft.balanceOf(address(this), newTokenId), mintAmount - 1);

        // Now disable transferability
        vm.prank(addresses.adminAddress);
        nft.setNonTransferable(newTokenId, true);

        // Transfer should now fail
        vm.expectRevert("BaseERC1155NFT: token is non-transferable");
        nft.safeTransferFrom(address(this), recipient, newTokenId, 1, "");
    }

    function testBatchTransferMixedTransferabilityFails() public {
        uint256 transferableTokenId = tokenId + 1;
        uint256 soulboundTokenId = tokenId + 2;
        uint256 newSupplyCap = 5000;
        uint256 mintAmount = 100;
        address recipient = address(0x123);

        // Set up one transferable and one soulbound token
        vm.prank(addresses.adminAddress);
        nft.setSupplyCapAndNonTransferable(transferableTokenId, newSupplyCap, false);
        vm.prank(addresses.adminAddress);
        nft.setSupplyCapAndNonTransferable(soulboundTokenId, newSupplyCap, true);

        // Mint both tokens
        vm.prank(address(sale));
        lock.lock(1);

        vm.prank(addresses.minterAddress);
        nft.mint(address(this), transferableTokenId, mintAmount);
        vm.prank(addresses.minterAddress);
        nft.mint(address(this), soulboundTokenId, mintAmount);

        // Attempt batch transfer and expect revert
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = transferableTokenId;
        tokenIds[1] = soulboundTokenId;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        vm.expectRevert("BaseERC1155NFT: token is non-transferable");
        nft.safeBatchTransferFrom(address(this), recipient, tokenIds, amounts, "");
    }

    function testNonTransferableTokenCanBeBurned() public {
        uint256 newTokenId = tokenId + 1;
        uint256 newSupplyCap = 5000;
        uint256 mintAmount = 100;
        uint256 burnAmount = 50;

        // Set up a non-transferable token
        vm.prank(addresses.adminAddress);
        nft.setSupplyCapAndNonTransferable(newTokenId, newSupplyCap, true);

        // Mint some tokens
        vm.prank(address(sale));
        lock.lock(1);

        vm.prank(addresses.minterAddress);
        nft.mint(address(this), newTokenId, mintAmount);

        assertEq(nft.balanceOf(address(this), newTokenId), mintAmount);

        // Burn should succeed even though token is non-transferable
        nft.burn(address(this), newTokenId, burnAmount);

        assertEq(nft.balanceOf(address(this), newTokenId), mintAmount - burnAmount);
        // Total supply should remain unchanged (burns don't decrease total supply)
        assertEq(nft.totalSupply(newTokenId), mintAmount);
    }

    function testPauseWithoutRoleFails() public {
        vm.expectRevert("CoreRef: no role on core");
        nft.pause();
    }

    /// pause tests
    function testMintFailsWhenPaused() public {
        vm.prank(addresses.adminAddress);
        nft.pause();

        vm.prank(addresses.minterAddress);
        vm.expectRevert("Pausable: paused");
        nft.mint(address(this), tokenId, 100);
    }

    function testMintBatchFailsWhenPaused() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.prank(addresses.adminAddress);
        nft.pause();

        vm.prank(addresses.minterAddress);
        vm.expectRevert("Pausable: paused");
        nft.mintBatch(address(this), tokenIds, amounts);
    }

    function testMintSucceedsMinter(uint16 amount) public {
        vm.assume(amount <= supplyCap);

        /// lock up to level 1 as sale contract
        vm.prank(address(sale));
        lock.lock(1);

        vm.prank(addresses.minterAddress);
        nft.mint(address(this), tokenId, amount);

        assertEq(nft.balanceOf(address(this), tokenId), amount);
        assertEq(nft.totalSupply(tokenId), amount);
        assertEq(nft.getMintAmountLeft(tokenId), supplyCap - amount);
    }

    function testMintBatchSucceedsMinter() public {
        testSetTokenSupplyCapWithRoleSucceeds();
        uint256 amount = 100;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId;
        tokenIds[1] = tokenId + 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        /// lock up to level 1
        vm.prank(address(sale));
        lock.lock(1);

        vm.prank(addresses.minterAddress);
        nft.mintBatch(address(this), tokenIds, amounts);

        assertEq(nft.balanceOf(address(this), tokenId), amount);
        assertEq(nft.balanceOf(address(this), tokenId + 1), amount);
        assertEq(nft.totalSupply(tokenId), amount);
        assertEq(nft.totalSupply(tokenId + 1), amount);
        assertEq(nft.getMintAmountLeft(tokenId), supplyCap - amount);
        assertEq(nft.getMintAmountLeft(tokenId + 1), supplyCap - amount);
    }

    function testMintBatchAboveSupplyCapFails() public {
        uint256 amount = 4_000;

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = tokenId;
        tokenIds[1] = tokenId;
        tokenIds[2] = tokenId;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = amount;
        amounts[1] = amount;
        amounts[2] = amount;

        /// lock up to level 1
        vm.prank(address(sale));
        lock.lock(1);

        vm.expectRevert("BaseERC1155NFT: supply exceeded");
        vm.prank(addresses.minterAddress);
        nft.mintBatch(address(this), tokenIds, amounts);
    }

    function testMintAboveSupplyCapFails() public {
        uint256 amount = 10_001;

        /// lock up to level 1
        vm.prank(address(sale));
        lock.lock(1);

        vm.expectRevert("BaseERC1155NFT: supply exceeded");
        vm.prank(addresses.minterAddress);
        nft.mint(address(this), tokenId, amount);
    }

    function testBurnUnchangedSupply() public {
        testMintBatchSucceedsMinter();
        uint256 amount = 100;

        nft.burn(address(this), tokenId, nft.balanceOf(address(this), tokenId));
        nft.burn(address(this), tokenId + 1, nft.balanceOf(address(this), tokenId + 1));

        assertEq(nft.balanceOf(address(this), tokenId), 0);
        assertEq(nft.balanceOf(address(this), tokenId + 1), 0);
        assertEq(nft.totalSupply(tokenId), amount);
        assertEq(nft.totalSupply(tokenId + 1), amount);
        assertEq(nft.getMintAmountLeft(tokenId), supplyCap - amount);
        assertEq(nft.getMintAmountLeft(tokenId + 1), supplyCap - amount);
    }

    function testBurnBatchUnchangedSupply() public {
        testMintBatchSucceedsMinter();
        uint256 amount = 100;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId;
        tokenIds[1] = tokenId + 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        nft.burnBatch(address(this), tokenIds, amounts);

        assertEq(nft.balanceOf(address(this), tokenId), 0);
        assertEq(nft.balanceOf(address(this), tokenId + 1), 0);
        assertEq(nft.totalSupply(tokenId), amount);
        assertEq(nft.totalSupply(tokenId + 1), amount);
        assertEq(nft.getMintAmountLeft(tokenId), supplyCap - amount);
        assertEq(nft.getMintAmountLeft(tokenId + 1), supplyCap - amount);
    }

    function testSendTokensToContractFails() public {
        testMintSucceedsMinter(10_000);

        vm.expectRevert("ERC1155: transfer to non-ERC1155Receiver implementer");
        nft.safeTransferFrom(address(this), address(nft), tokenId, 1, "");
    }

    function testNotLockedMintFails() public {
        vm.expectRevert("GlobalReentrancyLock: invalid lock level");
        vm.prank(addresses.minterAddress);
        nft.mint(address(this), tokenId, supplyCap);
    }

    function testNotLockedBatchMintFails() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = supplyCap;

        vm.expectRevert("GlobalReentrancyLock: invalid lock level");
        vm.prank(addresses.minterAddress);
        nft.mintBatch(address(this), tokenIds, amounts);
    }

    /// EIP-165 Interface Support Tests

    function testSupportsERC5633Interface() public view {
        assertTrue(nft.supportsInterface(type(IERC5633).interfaceId));
    }

    function testSupportsERC5192Interface() public view {
        assertTrue(nft.supportsInterface(type(IERC5192).interfaceId));
    }

    function testSupportsERC1155Interface() public view {
        assertTrue(nft.supportsInterface(0xd9b67a26));
    }

    function testDoesNotSupportInvalidInterface() public view {
        assertFalse(nft.supportsInterface(0xffffffff));
    }

    /// Batch API Tests

    function testSetSupplyCapBatchWithoutRoleFails() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory caps = new uint256[](2);
        caps[0] = 100;
        caps[1] = 200;

        vm.expectRevert("CoreRef: no role on core");
        nft.setSupplyCapBatch(ids, caps);
    }

    function testSetSupplyCapBatchSuccess() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        uint256[] memory caps = new uint256[](3);
        caps[0] = 100;
        caps[1] = 200;
        caps[2] = 300;

        vm.prank(addresses.adminAddress);
        nft.setSupplyCapBatch(ids, caps);

        assertEq(nft.maxTokenSupply(1), 100);
        assertEq(nft.maxTokenSupply(2), 200);
        assertEq(nft.maxTokenSupply(3), 300);
    }

    function testSetSupplyCapBatchLengthMismatchReverts() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory caps = new uint256[](1);
        caps[0] = 100;

        vm.prank(addresses.adminAddress);
        vm.expectRevert("ERC1155: length mismatch");
        nft.setSupplyCapBatch(ids, caps);
    }

    function testSetSupplyCapBatchTooSmallRevertsAtomic() public {
        // First mint some tokens to tokenId 7
        vm.prank(addresses.adminAddress);
        nft.setSupplyCap(7, 1000);

        vm.prank(address(sale));
        lock.lock(1);

        vm.prank(addresses.minterAddress);
        nft.mint(address(this), 7, 100);

        // Now try to set cap < 100 in batch - should revert atomically
        uint256[] memory ids = new uint256[](2);
        ids[0] = 8; // this one would succeed
        ids[1] = 7; // this one should fail
        uint256[] memory caps = new uint256[](2);
        caps[0] = 500;
        caps[1] = 50; // less than current supply of 100

        vm.prank(addresses.adminAddress);
        vm.expectRevert("BaseERC1155NFT: maxSupply cannot be less than current supply");
        nft.setSupplyCapBatch(ids, caps);

        // Ensure neither value was set (atomic revert)
        assertEq(nft.maxTokenSupply(8), 0);
    }

    function testSetNonTransferableBatchWithoutRoleFails() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        bool[] memory flags = new bool[](2);
        flags[0] = true;
        flags[1] = true;

        vm.expectRevert("CoreRef: no role on core");
        nft.setNonTransferableBatch(ids, flags);
    }

    function testSetNonTransferableBatchSuccess() public {
        // First set supply caps to initialize tokens
        uint256[] memory ids = new uint256[](3);
        ids[0] = 10;
        ids[1] = 11;
        ids[2] = 12;
        uint256[] memory caps = new uint256[](3);
        caps[0] = 1000;
        caps[1] = 1000;
        caps[2] = 1000;

        vm.prank(addresses.adminAddress);
        nft.setSupplyCapBatch(ids, caps);

        // Now set non-transferable flags
        bool[] memory flags = new bool[](3);
        flags[0] = true;
        flags[1] = false;
        flags[2] = true;

        vm.prank(addresses.adminAddress);
        nft.setNonTransferableBatch(ids, flags);

        assertTrue(nft.nonTransferableTokens(10));
        assertFalse(nft.nonTransferableTokens(11));
        assertTrue(nft.nonTransferableTokens(12));
    }

    function testSetNonTransferableBatchLengthMismatchReverts() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        bool[] memory flags = new bool[](1);
        flags[0] = true;

        vm.prank(addresses.adminAddress);
        vm.expectRevert("ERC1155: length mismatch");
        nft.setNonTransferableBatch(ids, flags);
    }

    function testSetSupplyCapAndNonTransferableBatchWithoutRoleFails() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory caps = new uint256[](2);
        caps[0] = 100;
        caps[1] = 200;
        bool[] memory flags = new bool[](2);
        flags[0] = true;
        flags[1] = true;

        vm.expectRevert("CoreRef: no role on core");
        nft.setSupplyCapAndNonTransferableBatch(ids, caps, flags);
    }

    function testSetSupplyCapAndNonTransferableBatchSuccess() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 20;
        ids[1] = 21;
        ids[2] = 22;
        uint256[] memory caps = new uint256[](3);
        caps[0] = 100;
        caps[1] = 200;
        caps[2] = 300;
        bool[] memory flags = new bool[](3);
        flags[0] = true;
        flags[1] = false;
        flags[2] = true;

        vm.prank(addresses.adminAddress);
        nft.setSupplyCapAndNonTransferableBatch(ids, caps, flags);

        assertEq(nft.maxTokenSupply(20), 100);
        assertEq(nft.maxTokenSupply(21), 200);
        assertEq(nft.maxTokenSupply(22), 300);
        assertTrue(nft.nonTransferableTokens(20));
        assertFalse(nft.nonTransferableTokens(21));
        assertTrue(nft.nonTransferableTokens(22));
    }

    function testSetSupplyCapAndNonTransferableBatchLengthMismatchReverts() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory caps = new uint256[](2);
        caps[0] = 100;
        caps[1] = 200;
        bool[] memory flags = new bool[](1);
        flags[0] = true;

        vm.prank(addresses.adminAddress);
        vm.expectRevert("ERC1155: length mismatch");
        nft.setSupplyCapAndNonTransferableBatch(ids, caps, flags);
    }

    /// exists() function tests

    function testExistsReturnsFalseForUnmintedToken() public view {
        // Token that has never been minted should return false
        assertFalse(nft.exists(999));
    }

    function testExistsReturnsTrueAfterMint() public {
        // Mint some tokens
        vm.prank(address(sale));
        lock.lock(1);

        vm.prank(addresses.minterAddress);
        nft.mint(address(this), tokenId, 100);

        // Token should now exist
        assertTrue(nft.exists(tokenId));
    }

    function testExistsReturnsTrueAfterBurn() public {
        // Mint then burn - exists should still return true (totalSupply doesn't decrease)
        vm.prank(address(sale));
        lock.lock(1);

        vm.prank(addresses.minterAddress);
        nft.mint(address(this), tokenId, 100);

        // Burn all tokens
        nft.burn(address(this), tokenId, 100);

        // Token should still exist (totalSupply tracks minted, not current balance)
        assertTrue(nft.exists(tokenId));
    }
}
