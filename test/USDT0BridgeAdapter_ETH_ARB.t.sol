// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {USDT0BridgeAdapterBase} from "./USDT0BridgeAdapterBase.sol";
import {IBridgeAdapter} from "@shift-defi/core/interfaces/IBridgeAdapter.sol";
import {ICrossChainContainer} from "@shift-defi/core/interfaces/ICrossChainContainer.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract USDT0BridgeAdapterTest is USDT0BridgeAdapterBase {
    using SafeERC20 for IERC20;

    uint256 constant ETHEREUM_CHAIN_ID = 1;
    uint256 constant ARBITRUM_CHAIN_ID = 42161;

    uint32 constant ETHEREUM_EID = 30101;
    uint32 constant ARBITRUM_EID = 30110;
    address constant ETHEREUM_USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant ETHEREUM_OFT = 0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee;
    address constant ARBITRUM_USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address constant ARBITRUM_OFT = 0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92;

    function setUp() public {
        string memory ETHEREUM_RPC = vm.envString("ETH_RPC_URL");
        string memory ARBITRUM_RPC = vm.envString("ARB_RPC_URL");

        _setUp(
            Fork({
                rpc: ETHEREUM_RPC, usdt: ETHEREUM_USDT, oft: ETHEREUM_OFT, chainId: ETHEREUM_CHAIN_ID, eid: ETHEREUM_EID
            }),
            Fork({
                rpc: ARBITRUM_RPC, usdt: ARBITRUM_USDT, oft: ARBITRUM_OFT, chainId: ARBITRUM_CHAIN_ID, eid: ARBITRUM_EID
            })
        );
    }

    function test_BridgeFromContainer() public {
        vm.selectFork(l1ForkId);

        uint256 amount = _randomBridgeAmount();
        uint256 minAmountOut = amount * 99 / 100;
        uint256 nativeFee = 10 ether;
        uint128 gasLimit = 1_000_000;

        address vault = makeAddr("vault");
        address claimer = makeAddr("claimer");
        deal(l1Fork.usdt, vault, amount);
        vm.startPrank(vault);
        IERC20(l1Fork.usdt).safeIncreaseAllowance(address(containerPrincipal), amount);
        containerPrincipal.registerDepositRequest(amount);
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
            payload: l1Peer.encodeUsdt0Payload(l2Fork.eid, claimer, gasLimit)
        });

        vm.startPrank(roles.operator);
        containerPrincipal.sendDepositRequest{value: nativeFee}(
            ICrossChainContainer.MessageInstruction({
                value: 0, adapter: makeAddr("messageAdapter"), parameters: new bytes(0)
            }),
            bridgeAdapters,
            bridgeIxs
        );
        vm.stopPrank();
    }
}
