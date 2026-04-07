// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IContainer} from "@shift-defi/core/interfaces/IContainer.sol";
import {ContainerPrincipal} from "@shift-defi/core/ContainerPrincipal.sol";
import {ICrossChainContainer} from "@shift-defi/core/interfaces/ICrossChainContainer.sol";
import {IMessageRouter} from "@shift-defi/core/interfaces/IMessageRouter.sol";
import {USDT0BridgeAdapter} from "../contracts/USDT0BridgeAdapter.sol";

abstract contract Base is Test {
    USDT0BridgeAdapter public l1Peer;
    USDT0BridgeAdapter public l2Peer;

    uint256 public l1ForkId;
    uint256 public l2ForkId;

    struct Roles {
        address defaultAdmin;
        address bridgeAdapterManager;
        address cacheManager;
        address bridger;
        address operator;
        address messengerManager;
        address messageRouter;
    }

    Roles public roles = Roles({
        defaultAdmin: makeAddr("defaultAdmin"),
        bridgeAdapterManager: makeAddr("bridgeAdapterManager"),
        cacheManager: makeAddr("cacheManager"),
        bridger: makeAddr("bridger"),
        operator: makeAddr("operator"),
        messengerManager: makeAddr("messengerManager"),
        messageRouter: makeAddr("messageRouter")
    });

    address receiver = makeAddr("receiver");

    bytes32 public constant BRIDGE_ADAPTER_MANAGER_ROLE = keccak256("BRIDGE_ADAPTER_MANAGER_ROLE");
    uint256 public constant MIN_BRIDGE_AMOUNT = 1e6;
    uint256 public constant MAX_BRIDGE_AMOUNT = 100_000e6;
    uint256 public constant BRIDGE_CACHE_MAX_SIZE = 8;
    uint256 public constant SLIPPAGE_CAP_PCT = 1e17;

    struct Fork {
        string rpc;
        address usdt;
        address oft;
        uint256 chainId;
        uint32 eid;
    }

    Fork l1Fork;
    Fork l2Fork;

    uint256 public baseL1SnapshotId;
    uint256 public baseL2SnapshotId;

    ContainerPrincipal containerPrincipal;

    function _setUp(Fork memory _l1Fork, Fork memory _l2Fork) internal {
        l1Fork = _l1Fork;
        l2Fork = _l2Fork;

        l1ForkId = vm.createFork(l1Fork.rpc);
        l2ForkId = vm.createFork(l2Fork.rpc);

        l1Peer = _proxify(l1ForkId, roles, l1Fork);
        l2Peer = _proxify(l2ForkId, roles, l2Fork);

        vm.selectFork(l1ForkId);
        vm.startPrank(roles.bridgeAdapterManager);
        l1Peer.setPeer(l2Fork.chainId, address(l2Peer));
        l1Peer.setBridgePath(l1Fork.usdt, l2Fork.chainId, l2Fork.usdt);
        l1Peer.whitelistBridger(roles.bridger);
        vm.stopPrank();

        vm.selectFork(l2ForkId);
        vm.startPrank(roles.bridgeAdapterManager);
        l2Peer.setBridgePath(l2Fork.usdt, l1Fork.chainId, l2Fork.usdt);
        l2Peer.setPeer(l1Fork.chainId, address(l1Peer));
        l2Peer.whitelistBridger(roles.bridger);
        vm.stopPrank();

        vm.selectFork(l1ForkId);
        deal(l1Fork.usdt, roles.bridger, 10 ether);
        deal(roles.bridger, 50 ether);

        containerPrincipal = _proxifyContainerPrincipal(l1ForkId, roles, l1Fork);
        deal(roles.operator, 100 ether);

        vm.prank(roles.messengerManager);
        containerPrincipal.setPeerContainer(makeAddr("containerAgent"));

        vm.prank(roles.bridgeAdapterManager);
        containerPrincipal.setBridgeAdapter(address(l1Peer), true);

        vm.prank(roles.bridgeAdapterManager);
        l1Peer.whitelistBridger(address(containerPrincipal));

        vm.mockCall(roles.messageRouter, IMessageRouter.send.selector, "");

        vm.selectFork(l2ForkId);
        deal(l2Fork.usdt, roles.bridger, 10 ether);
        deal(roles.bridger, 50 ether);
    }

    function _randomBridgeAmount() internal view returns (uint256) {
        return vm.randomUint(MIN_BRIDGE_AMOUNT, MAX_BRIDGE_AMOUNT);
    }

    function _proxify(uint256 forkId, Roles memory _roles, Fork memory _fork) internal returns (USDT0BridgeAdapter) {
        vm.selectFork(forkId);
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(new USDT0BridgeAdapter()),
            _roles.defaultAdmin,
            abi.encodeWithSelector(
                USDT0BridgeAdapter.initialize.selector,
                _roles.defaultAdmin,
                _roles.bridgeAdapterManager,
                _roles.cacheManager,
                SLIPPAGE_CAP_PCT,
                BRIDGE_CACHE_MAX_SIZE,
                _fork.usdt,
                _fork.oft
            )
        );

        USDT0BridgeAdapter adapter = USDT0BridgeAdapter(payable(address(proxy)));
        return adapter;
    }

    function _proxifyContainerPrincipal(uint256 forkId, Roles memory _roles, Fork memory _fork)
        internal
        returns (ContainerPrincipal)
    {
        uint256 remoteChainId = _fork.chainId == l1Fork.chainId ? l2Fork.chainId : l1Fork.chainId;

        vm.selectFork(forkId);
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(new ContainerPrincipal()),
            _roles.defaultAdmin,
            abi.encodeWithSelector(
                ContainerPrincipal.initialize.selector,
                IContainer.ContainerInitParams({
                    vault: makeAddr("vault"),
                    notion: _fork.usdt,
                    defaultAdmin: _roles.defaultAdmin,
                    operator: _roles.operator,
                    emergencyPauser: makeAddr("emergencyPauser"),
                    tokenManager: makeAddr("tokenManager"),
                    swapRouter: makeAddr("swapRouter")
                }),
                ICrossChainContainer.CrossChainContainerInitParams({
                    messageRouter: _roles.messageRouter,
                    remoteChainId: remoteChainId,
                    messengerManager: _roles.messengerManager,
                    bridgeAdapterManager: _roles.bridgeAdapterManager
                })
            )
        );

        ContainerPrincipal principal = ContainerPrincipal(payable(address(proxy)));
        return principal;
    }
}
