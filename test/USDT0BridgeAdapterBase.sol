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
}
