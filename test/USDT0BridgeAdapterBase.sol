// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeAdapter} from "@shift-defi/core/interfaces/IBridgeAdapter.sol";
import {ICrossChainContainer} from "@shift-defi/core/interfaces/ICrossChainContainer.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {IUSDT0BridgeAdapter} from "contracts/interfaces/IUSDT0BridgeAdapter.sol";
import {Base} from "./Base.sol";

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
            payload: l1Peer.encodeUsdt0Payload(l2Fork.eid, refundRecipient, gasLimit),
            token: l1Fork.usdt,
            amount: amount,
            chainTo: l2Fork.chainId,
            value: 0,
            minTokenAmount: minAmountOut
        });

        vm.startPrank(roles.bridger);
        IERC20(l1Fork.usdt).safeIncreaseAllowance(address(l1Peer), amount);
        (MessagingFee memory msgFee,) = l1Peer.quoteBridgeNativeFee(ix, claimer, address(l2Peer));
        uint256 nativeFee = msgFee.nativeFee;
        ix.value = nativeFee;
        deal(roles.bridger, nativeFee);
        uint256 bridgedAmount = l1Peer.bridge{value: nativeFee}(ix, address(l2Peer));
        vm.stopPrank();
        assertEq(bridgedAmount, amount);
    }

    function test_BridgeFromL1ToL2_ComposeMsg() public {
        address claimer = makeAddr("claimer");
        uint256 amount = _randomBridgeAmount();
        address composeFrom = address(l1Peer);
        uint32 srcEid = l1Fork.eid;

        vm.startPrank(l2Fork.lzEndpoint);
        bytes memory _msg = _wrapComposeMsg(srcEid, composeFrom, amount, l2Peer.encodeLzComposeMessage(claimer));
        l2Peer.lzCompose(address(l1Fork.oft), bytes32(0x0), _msg, address(1), new bytes(0));
        vm.stopPrank();

        uint256 claimableAmount = l2Peer.claimableAmounts(claimer, l2Fork.usdt);
        assertEq(claimableAmount, amount);
    }

    function test_BridgeFromL1ToL2_ComposeMsg_InvalidEndpoint() public {
        address fakeEndpoint = makeAddr("fakeEndpoint");

        vm.selectFork(l2ForkId);

        vm.prank(fakeEndpoint);
        vm.expectRevert(abi.encodeWithSelector(IUSDT0BridgeAdapter.NotLZEndpoint.selector));
        l2Peer.lzCompose(address(l1Fork.oft), bytes32(0x0), bytes(""), address(1), bytes(""));
    }

    function test_BridgeFromL1ToL2_ComposeMsg_InvalidOApp() public {
        address fakeOApp = makeAddr("fakeOApp");

        vm.selectFork(l2ForkId);
        bytes memory _msg = _wrapComposeMsg(l1Fork.eid, address(1), 1, l2Peer.encodeLzComposeMessage(address(1)));

        vm.expectRevert(abi.encodeWithSelector(IUSDT0BridgeAdapter.NotApprovedOApp.selector));
        vm.prank(l2Fork.lzEndpoint);
        l2Peer.lzCompose(fakeOApp, bytes32(0x0), _msg, address(1), bytes(""));
    }

    function test_BridgeFromL1ToL2_ComposeMsg_NotApprovedPeer() public {
        address fakePeer = makeAddr("fakePeer");

        vm.selectFork(l2ForkId);
        bytes memory _msg = _wrapComposeMsg(l1Fork.eid, fakePeer, 1, l2Peer.encodeLzComposeMessage(address(1)));

        vm.expectRevert(abi.encodeWithSelector(IUSDT0BridgeAdapter.NotApprovedPeer.selector));
        vm.prank(l2Fork.lzEndpoint);
        l2Peer.lzCompose(l1Fork.oft, bytes32(0x0), _msg, address(1), bytes(""));
    }

    function test_BridgeFromL2ToL1() public {
        vm.selectFork(l2ForkId);

        uint256 amount = _randomBridgeAmount();
        uint256 minAmountOut = amount * 99 / 100;
        address claimer = makeAddr("claimer");
        address refundRecipient = makeAddr("refundRecipient");
        uint128 gasLimit = 1_000_000;

        IBridgeAdapter.BridgeInstruction memory ix = IBridgeAdapter.BridgeInstruction({
            payload: l2Peer.encodeUsdt0Payload(l1Fork.eid, refundRecipient, gasLimit),
            token: l2Fork.usdt,
            amount: amount,
            chainTo: l1Fork.chainId,
            value: 0,
            minTokenAmount: minAmountOut
        });

        vm.startPrank(roles.bridger);
        IERC20(l2Fork.usdt).safeIncreaseAllowance(address(l2Peer), amount);
        (MessagingFee memory msgFee,) = l2Peer.quoteBridgeNativeFee(ix, claimer, address(l1Peer));
        uint256 nativeFee = msgFee.nativeFee;
        ix.value = nativeFee;
        deal(roles.bridger, nativeFee);
        uint256 bridgedAmount = l2Peer.bridge{value: nativeFee}(ix, address(l1Peer));
        vm.stopPrank();
        assertEq(bridgedAmount, amount);
    }

    function test_BridgeFromL2ToL1_ComposeMsg() public {
        address claimer = makeAddr("claimer");
        uint256 amount = _randomBridgeAmount();
        address composeFrom = address(l2Peer);
        uint32 srcEid = l2Fork.eid;

        vm.selectFork(l1ForkId);

        vm.startPrank(l1Fork.lzEndpoint);
        bytes memory _msg = _wrapComposeMsg(srcEid, composeFrom, amount, l1Peer.encodeLzComposeMessage(claimer));
        l1Peer.lzCompose(address(l2Fork.oft), bytes32(0x0), _msg, address(1), new bytes(0));
        vm.stopPrank();

        uint256 claimableAmount = l1Peer.claimableAmounts(claimer, l1Fork.usdt);
        assertEq(claimableAmount, amount);
    }

    function test_BridgeFromL2ToL1_ComposeMsg_InvalidEndpoint() public {
        address fakeEndpoint = makeAddr("fakeEndpoint");

        vm.selectFork(l1ForkId);

        vm.prank(fakeEndpoint);
        vm.expectRevert(abi.encodeWithSelector(IUSDT0BridgeAdapter.NotLZEndpoint.selector));
        l1Peer.lzCompose(address(l2Fork.oft), bytes32(0x0), bytes(""), address(1), bytes(""));
    }

    function test_BridgeFromL2ToL1_ComposeMsg_InvalidOApp() public {
        address fakeOApp = makeAddr("fakeOApp");

        vm.selectFork(l1ForkId);
        bytes memory _msg = _wrapComposeMsg(l2Fork.eid, address(1), 1, l1Peer.encodeLzComposeMessage(address(1)));

        vm.expectRevert(abi.encodeWithSelector(IUSDT0BridgeAdapter.NotApprovedOApp.selector));
        vm.prank(l1Fork.lzEndpoint);
        l1Peer.lzCompose(fakeOApp, bytes32(0x0), _msg, address(1), bytes(""));
    }

    function test_BridgeFromL2ToL1_ComposeMsg_NotApprovedPeer() public {
        address fakePeer = makeAddr("fakePeer");

        vm.selectFork(l1ForkId);
        bytes memory _msg = _wrapComposeMsg(l2Fork.eid, fakePeer, 1, l1Peer.encodeLzComposeMessage(address(1)));

        vm.expectRevert(abi.encodeWithSelector(IUSDT0BridgeAdapter.NotApprovedPeer.selector));
        vm.prank(l1Fork.lzEndpoint);
        l1Peer.lzCompose(l2Fork.oft, bytes32(0x0), _msg, address(1), bytes(""));
    }

    function test_BridgeFromContainer() public {
        vm.selectFork(l1ForkId);

        uint256 amount = _randomBridgeAmount();
        uint256 minAmountOut = amount * 99 / 100;
        uint256 nativeFee = 10 ether;
        uint128 gasLimit = 1_000_000;

        address vault = makeAddr("vault");
        address refundRecipient = makeAddr("refundRecipient");
        deal(l1Fork.usdt, vault, amount);
        vm.startPrank(vault);
        IERC20(l1Fork.usdt).safeIncreaseAllowance(address(l1ContainerPrincipal), amount);
        l1ContainerPrincipal.registerDepositRequest(amount);
        vm.stopPrank();

        address[] memory bridgeAdapters = new address[](1);
        bridgeAdapters[0] = address(l1Peer);

        IBridgeAdapter.BridgeInstruction[] memory bridgeIxs = new IBridgeAdapter.BridgeInstruction[](1);
        bridgeIxs[0] = IBridgeAdapter.BridgeInstruction({
            value: nativeFee,
            chainTo: l2Fork.chainId,
            amount: amount,
            minTokenAmount: minAmountOut,
            token: l1Fork.usdt,
            payload: l1Peer.encodeUsdt0Payload(l2Fork.eid, refundRecipient, gasLimit)
        });

        vm.expectEmit();
        emit IBridgeAdapter.BridgeSent(l1Fork.usdt, amount, l2Fork.chainId, 0);

        vm.startPrank(roles.operator);
        l1ContainerPrincipal.sendDepositRequest{value: nativeFee}(
            ICrossChainContainer.MessageInstruction({
                value: 0, adapter: makeAddr("messageAdapter"), parameters: new bytes(0)
            }),
            bridgeAdapters,
            bridgeIxs
        );
        vm.stopPrank();

        // Emulate bridge and compose message from lzEndpoint on L2
        vm.selectFork(l2ForkId);

        deal(l2Fork.usdt, address(l2Peer), amount);

        bytes memory _msg = _wrapComposeMsg(
            l1Fork.eid, address(l1Peer), amount, l2Peer.encodeLzComposeMessage(address(l2ContainerAgent))
        );

        vm.expectEmit();
        emit IBridgeAdapter.Bridged(address(l2ContainerAgent), l2Fork.usdt, amount);

        vm.prank(l2Fork.lzEndpoint);
        l2Peer.lzCompose(address(l1Fork.oft), bytes32(0x0), _msg, address(1), new bytes(0));

        uint256 claimableAmount = l2Peer.claimableAmounts(address(l2ContainerAgent), l2Fork.usdt);
        assertEq(claimableAmount, amount);

        // Emulate claim to the container agent on L2
        uint256 balanceBefore = IERC20(l2Fork.usdt).balanceOf(address(l2ContainerAgent));
        assertEq(balanceBefore, 0);

        vm.expectEmit();
        emit IBridgeAdapter.Claimed(address(l2ContainerAgent), l2Fork.usdt, amount);

        vm.prank(address(l2ContainerAgent));
        l2Peer.claim(l2Fork.usdt);

        uint256 balanceAfter = IERC20(l2Fork.usdt).balanceOf(address(l2ContainerAgent));
        assertEq(balanceAfter, amount);

        claimableAmount = l2Peer.claimableAmounts(address(l2ContainerAgent), l2Fork.usdt);
        assertEq(claimableAmount, 0);
    }

    function _wrapComposeMsg(uint32 srcEid, address composeFrom, uint256 amountLD, bytes memory composeMessage)
        internal
        pure
        returns (bytes memory)
    {
        return OFTComposeMsgCodec.encode(
            0, srcEid, amountLD, abi.encodePacked(bytes32(uint256(uint160(composeFrom))), composeMessage)
        );
    }
}
