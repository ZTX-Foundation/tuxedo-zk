pragma solidity 0.8.28;

import "test/BaseTest.sol";
import {SingleFunctionReentrancy} from "test/mock/SingleFunctionReentrancy.sol";
import {CrossFunctionReentrancy} from "test/mock/CrossFunctionReentrancy.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Mock receiver that attempts to re-enter Sale.buyToken from onERC1155BatchReceived
contract BatchToSaleReentrant is ERC1155Holder {
    ERC1155Sale public sale;
    IERC20 public token;
    bool public shouldReenter;

    constructor(ERC1155Sale _sale, address _token) {
        sale = _sale;
        token = IERC20(_token);
        token.approve(address(_sale), type(uint256).max);
    }

    function setReenter(bool _shouldReenter) external {
        shouldReenter = _shouldReenter;
    }

    /// @notice Initiate a batch purchase that will trigger reentrancy attempt in callback
    function purchaseBatch(uint256 tokenId, uint256 amount) external {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](0);

        sale.buyTokens(tokenIds, amounts, amounts, proofs, address(this));
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory ids,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        if (shouldReenter) {
            shouldReenter = false; // prevent infinite loop
            bytes32[] memory proof = new bytes32[](0);
            // Attempt to re-enter Sale during callback - should fail with globalLock
            sale.buyToken(ids[0], 1, 1, proof, address(this));
        }
        return this.onERC1155BatchReceived.selector;
    }
}

contract UnitTestERC1155Reentrancy is BaseTest {

    SingleFunctionReentrancy public receiver;
    CrossFunctionReentrancy public cReceiver;

    function setUp() public override {
        super.setUp();
        vm.prank(addresses.adminAddress);
        sale.setTokenConfig(tokenId, address(token), uint96(block.timestamp + 1), tokenPrice, fee, true, bytes32(0));
        vm.warp(block.timestamp + 1);

        receiver = new SingleFunctionReentrancy(sale, address(token));
        cReceiver = new CrossFunctionReentrancy(sale, address(token), address(nft));
    }

    function testSetup() public {
        assertEq(address(receiver.sale()), address(sale));
        assertTrue(!receiver.isBuying());
        assertEq(token.allowance(address(receiver), address(sale)), type(uint256).max);
    }

    /// @notice Tests that re-entering Sale.buyToken from mint callback fails via globalLock
    /// @dev Flow: receiver.purchaseTokens() → Sale.buyToken() [lock(1)] → nft.mint()
    ///      → onERC1155Received callback → attempts Sale.buyToken() again → fails
    /// @dev This validates that even without globalLock(2) on mint, the Sale's globalLock(1)
    ///      still prevents reentrancy because lock(1) requires currentLevel == 0
    function testSingleFunctionReentrancyFails() public {
        (uint256 total, , ) = sale.getPurchasePrice(tokenId, supplyCap);

        token.mint(address(receiver), total);

        // Reentrancy fails because Sale.buyToken has globalLock(1) and lock level is already 1
        vm.expectRevert("GlobalReentrancyLock: invalid lock level");
        receiver.purchaseTokens(tokenId, supplyCap);
    }
    
    function testCrossFunctionReentrancySucceeds() public {
        (uint256 total, , ) = sale.getPurchasePrice(tokenId, supplyCap);
    
        token.mint(address(cReceiver), total);
    
        cReceiver.purchaseTokens(tokenId, supplyCap);

        assertEq(nft.balanceOf(address(1), tokenId), supplyCap);
        assertEq(nft.totalSupply(tokenId), supplyCap);
    }
    
    function testCrossFunctionReentrancySucceedsMintBatch() public {
        vm.prank(address(sale));
        lock.lock(1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = supplyCap;

        vm.prank(addresses.minterAddress);
        nft.mintBatch(address(cReceiver), tokenIds, amounts);
    
        assertEq(nft.balanceOf(address(1), tokenId), supplyCap);
        assertEq(nft.totalSupply(tokenId), supplyCap);
    }
    
    function testCrossFunctionReentrancySucceedsMintBatchMultiIds() public {
        uint256 tokenIdTwo = tokenId + 1;
        setSupplyCap(vm, nft, tokenIdTwo, supplyCap);

        vm.prank(address(sale));
        lock.lock(1);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId;
        tokenIds[1] = tokenIdTwo;
    
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = supplyCap;
        amounts[1] = supplyCap;

        vm.prank(addresses.minterAddress);
        nft.mintBatch(address(cReceiver), tokenIds, amounts);
    
        assertEq(nft.balanceOf(address(1), tokenId), supplyCap);
        assertEq(nft.totalSupply(tokenId), supplyCap);

        assertEq(nft.balanceOf(address(1), tokenIdTwo), supplyCap);
        assertEq(nft.totalSupply(tokenIdTwo), supplyCap);
    }

    /// @notice Tests that unauthorized address cannot call mintBatch
    /// @dev mint/mintBatch require both MINTER_PROTOCOL_ROLE and caller holding globalLock(1)
    function testBatchMintWithoutRoleFails() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        // Fails because receiver doesn't have MINTER_PROTOCOL_ROLE
        vm.prank(address(receiver));
        vm.expectRevert("CoreRef: no role on core");
        nft.mintBatch(address(receiver), tokenIds, amounts);
    }

    /// @notice Tests that re-entering Sale from mintBatch callback fails via globalLock
    /// @dev Flow: receiver.purchaseBatch() → Sale.buyTokens() [lock(1)] → nft.mintBatch()
    ///      → onERC1155BatchReceived callback → attempts Sale.buyToken() → fails
    /// @dev This validates the reentrancy protection for batch mint flow
    function testBatchMintCallbackReenterSaleFails() public {
        BatchToSaleReentrant reentrantReceiver = new BatchToSaleReentrant(sale, address(token));

        // Get price and fund the receiver for both initial purchase and reentrant attempt
        (uint256 total, , ) = sale.getPurchasePrice(tokenId, 100);
        token.mint(address(reentrantReceiver), total * 2);

        // Enable reentrancy attempt
        reentrantReceiver.setReenter(true);

        // This should fail because during mintBatch callback, the receiver tries to
        // call Sale.buyToken which has globalLock(1), but lock level is already 1
        vm.expectRevert("GlobalReentrancyLock: invalid lock level");
        reentrantReceiver.purchaseBatch(tokenId, 100);
    }

    /// @notice Tests that re-entering mint from callback fails via globalLock(2)
    /// @dev Flow: minter calls mintBatch() [globalLock(2), lock 1→2] → onERC1155BatchReceived
    ///      callback on SingleFunctionReentrancy → callback tries mintBatch() → fails at lock
    ///      because lock level is already 2 (needs level 1 to acquire globalLock(2))
    function testBatchMintReentrancyFails() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.expectRevert("GlobalReentrancyLock: invalid lock level");
        vm.prank(addresses.minterAddress);
        nft.mintBatch(address(receiver), tokenIds, amounts);
    }
}
