// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import {console} from "@forge-std/console.sol";
import {Script} from "@forge-std/Script.sol";
import {ERC1155MaxSupplyMintable} from "@protocol/nfts/ERC1155MaxSupplyMintable.sol";
import {Core} from "@protocol/core/Core.sol";
import {Roles} from "@protocol/core/Roles.sol";
import {MintHelper} from "@protocol/test/MintHelper.sol";

/*
How to use:
forge script script/deploy/DeployProposal.s.sol:DeployProposal \
    -vvvv \
    --rpc-url $ETH_RPC_URL \
    --broadcast
Remove --broadcast if you want to try locally first, without paying any gas.
*/

contract TestTransferWebhook is Script {
    ERC1155MaxSupplyMintable erc1155;
    Core core;
    MintHelper mintHelper;

    function setUp() public {
        erc1155 = ERC1155MaxSupplyMintable(0xc6bf3609C14d381A6eFfDC875076442B2C316Da2);
        core = Core(0xBCb65E8C79E7953FD4927B12178C4088b45999DA);
    }

    function run() public {
        vm.startBroadcast(0x73bBdE7e45E26546f2ef0202865917E4D6CE2A01);

        uint256 randomTokenId = 999888777666555444333;

        erc1155.safeTransferFrom(
            0x73bBdE7e45E26546f2ef0202865917E4D6CE2A01,
            0xb31865DBd173549c6BdA0FEBfCCC4cB02B0E41B3,
            randomTokenId,
            1,
            ""
        );

        //
        // // First, set supply cap if needed (requires ADMIN role)
        // erc1155.setSupplyCap(randomTokenId, 1000000 ether);
        //
        // // Deploy the MintHelper contract
        // mintHelper = new MintHelper(address(core));
        //
        // // Grant MINTER role to the MintHelper contract (so it can call mint)
        // core.grantRole(Roles.MINTER_PROTOCOL_ROLE, address(mintHelper));
        //
        // // Grant LOCKER role to the MintHelper contract (so it can acquire locks)
        // core.grantRole(Roles.LOCKER_PROTOCOL_ROLE, address(mintHelper));
        //
        // // Grant MINTER role to your address so it can call mintHelper
        // core.grantRole(Roles.MINTER_PROTOCOL_ROLE, 0x73bBdE7e45E26546f2ef0202865917E4D6CE2A01);
        //
        // // Now mint through the helper - this handles lock levels properly
        // mintHelper.mintWithLock(address(erc1155), 0x73bBdE7e45E26546f2ef0202865917E4D6CE2A01, randomTokenId, 100);

        vm.stopBroadcast();
    }
}
