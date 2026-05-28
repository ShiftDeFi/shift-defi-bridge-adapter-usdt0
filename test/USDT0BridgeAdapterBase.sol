// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeAdapter} from "@shift-defi/core/interfaces/IBridgeAdapter.sol";
import {Base} from "./Base.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

abstract contract USDT0BridgeAdapterBase is Base {
    using SafeERC20 for IERC20;

    function test_BridgeFromL1ToL2() public {
        vm.selectFork(l1ForkId);

        uint256 amount = _randomBridgeAmount();
        uint256 minAmountOut = amount * 99 / 100;
        address claimer = makeAddr("claimer");
        address refundRecipient = makeAddr("refundRecipient");
        uint128 gasLimit = 1_000_000;

        IBridgeAdapter.BridgeInstruction memory ix = IBridgeAdapter.BridgeInstruction({
            payload: l1Peer.encodeUsdt0Payload(l2Fork.eid, claimer, refundRecipient, gasLimit),
            token: l1Fork.usdt,
            amount: amount,
            chainTo: l2Fork.chainId,
            value: 0,
            minTokenAmount: minAmountOut
        });

        vm.startPrank(roles.bridger);
        IERC20(l1Fork.usdt).safeIncreaseAllowance(address(l1Peer), amount);
        (MessagingFee memory msgFee,) = l1Peer.quoteBridgeNativeFee(ix, receiver);
        uint256 nativeFee = msgFee.nativeFee;
        ix.value = nativeFee;
        deal(roles.bridger, nativeFee);
        uint256 bridgedAmount = l1Peer.bridge{value: nativeFee}(ix, receiver);
        vm.stopPrank();
        assertEq(bridgedAmount, amount);
    }

    function test_BridgeFromL1ToL2_ComposeMsg() public {
        address claimer = makeAddr("claimer");
        uint256 amount = _randomBridgeAmount();

        vm.selectFork(l2ForkId);

        vm.startPrank(l2Fork.lzEndpoint);
        bytes memory _msg = _wrapComposeMsg(abi.encode(claimer, amount));
        l2Peer.lzCompose(address(l1Peer), bytes32(0x0), _msg, address(1), new bytes(0));
        vm.stopPrank();

        uint256 claimableAmount = l2Peer.claimableAmounts(claimer, l2Fork.usdt);
        assertEq(claimableAmount, amount);
    }

    function test_BridgeFromL2ToL1() public {
        vm.selectFork(l2ForkId);

        uint256 amount = _randomBridgeAmount();
        uint256 minAmountOut = amount * 99 / 100;
        address claimer = makeAddr("claimer");
        address refundRecipient = makeAddr("refundRecipient");
        uint128 gasLimit = 1_000_000;

        IBridgeAdapter.BridgeInstruction memory ix = IBridgeAdapter.BridgeInstruction({
            payload: l2Peer.encodeUsdt0Payload(l1Fork.eid, claimer, refundRecipient, gasLimit),
            token: l2Fork.usdt,
            amount: amount,
            chainTo: l1Fork.chainId,
            value: 0,
            minTokenAmount: minAmountOut
        });

        vm.startPrank(roles.bridger);
        IERC20(l2Fork.usdt).safeIncreaseAllowance(address(l2Peer), amount);
        (MessagingFee memory msgFee,) = l2Peer.quoteBridgeNativeFee(ix, receiver);
        uint256 nativeFee = msgFee.nativeFee;
        ix.value = nativeFee;
        deal(roles.bridger, nativeFee);
        uint256 bridgedAmount = l2Peer.bridge{value: nativeFee}(ix, receiver);
        vm.stopPrank();
        assertEq(bridgedAmount, amount);
    }

    function test_BridgeFromL2ToL1_ComposeMsg() public {
        address claimer = makeAddr("claimer");
        uint256 amount = _randomBridgeAmount();

        vm.selectFork(l1ForkId);

        vm.startPrank(l1Fork.lzEndpoint);
        bytes memory _msg = _wrapComposeMsg(abi.encode(claimer, amount));
        l1Peer.lzCompose(address(l2Peer), bytes32(0x0), _msg, address(1), new bytes(0));
        vm.stopPrank();

        uint256 claimableAmount = l1Peer.claimableAmounts(claimer, l1Fork.usdt);
        assertEq(claimableAmount, amount);
    }

    function _wrapComposeMsg(bytes memory msg) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0x0), bytes32(0x0), bytes12(0x0), msg);
    }
}
