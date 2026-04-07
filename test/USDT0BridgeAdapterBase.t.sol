// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeAdapter} from "@shift-defi/core/interfaces/IBridgeAdapter.sol";
import {Base} from "./Base.t.sol";


contract USDT0BridgeAdapterBase is Base {
    using SafeERC20 for IERC20;

    function test_BridgeFromL1ToL2() public {
        vm.selectFork(l1ForkId);

        uint256 amount = _randomBridgeAmount();
        uint256 minAmountOut = amount * 99 / 100;

        IBridgeAdapter.BridgeInstruction memory ix = IBridgeAdapter.BridgeInstruction({
            payload: l1Peer.encodeUsdt0Payload(l2Fork.eid),
            token: l1Fork.usdt,
            amount: amount,
            chainTo: l2Fork.chainId,
            value: 0,
            minTokenAmount: minAmountOut
        });

        vm.startPrank(roles.bridger);
        IERC20(l1Fork.usdt).safeIncreaseAllowance(address(l1Peer), amount);
        uint256 bridgedAmount = l1Peer.bridge{value: 1 ether}(ix, receiver);
        vm.stopPrank();
        assertEq(bridgedAmount, amount);
    }

    function test_BridgeFromL2ToL1() public {
        vm.selectFork(l2ForkId);

        uint256 amount = _randomBridgeAmount();
        uint256 minAmountOut = amount * 99 / 100;

        IBridgeAdapter.BridgeInstruction memory ix = IBridgeAdapter.BridgeInstruction({
            payload: l2Peer.encodeUsdt0Payload(l1Fork.eid),
            token: l2Fork.usdt,
            amount: amount,
            chainTo: l1Fork.chainId,
            value: 0,
            minTokenAmount: minAmountOut
        });

        vm.startPrank(roles.bridger);
        IERC20(l2Fork.usdt).safeIncreaseAllowance(address(l2Peer), amount);
        uint256 bridgedAmount = l2Peer.bridge{value: 1 ether}(ix, receiver);
        vm.stopPrank();
        assertEq(bridgedAmount, amount);
    }
}
