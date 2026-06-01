// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OptionsBuilder} from "@layer-zero/devtools/packages/oapp-evm/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {BridgeAdapter} from "@shift-defi/core/BridgeAdapter.sol";
import {Errors} from "@shift-defi/core/libraries/Errors.sol";

import {IUSDT0BridgeAdapter} from "./interfaces/IUSDT0BridgeAdapter.sol";
import {IOAppComposer} from "@layer-zero/devtools/packages/oapp-evm/oapp/interfaces/IOAppComposer.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";

/// @title USDT0BridgeAdapter
/// @notice Bridge adapter for USDT0 Network
contract USDT0BridgeAdapter is BridgeAdapter, IUSDT0BridgeAdapter, IOAppComposer {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;
    using OFTComposeMsgCodec for bytes;

    uint256 private constant ETH_CHAIN_ID = 1;

    address public usdt0;
    address public localOft;
    address public lzEndpoint;

    mapping(uint32 => mapping(address => bool)) public approvedOApps;
    mapping(uint32 => mapping(address => bool)) public approvedPeers;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the adapter.
     * @param _defaultAdmin Address that receives the default admin role.
     * @param _bridgeAdapterManager Address that receives the bridge adapter manager role.
     * @param _cacheManager Address that receives the cache manager role.
     * @param _slippageCapPct Maximum allowed slippage delta in 1e18 precision.
     * @param _maxCacheSize Maximum bridge retry cache size.
     * @param _usdt0 USDT0 token address on the current chain.
     * @param _localOft LayerZero OFT endpoint used for bridging.
     * @param _lzEndpoint LayerZero endpoint address.
     */
    function initialize(
        address _defaultAdmin,
        address _bridgeAdapterManager,
        address _cacheManager,
        uint256 _slippageCapPct,
        uint256 _maxCacheSize,
        address _usdt0,
        address _localOft,
        address _lzEndpoint
    ) external initializer {
        require(_usdt0 != address(0), Errors.ZeroAddress());
        require(_localOft != address(0), Errors.ZeroAddress());
        require(_lzEndpoint != address(0), Errors.ZeroAddress());
        usdt0 = _usdt0;
        localOft = _localOft;
        lzEndpoint = _lzEndpoint;
        __BridgeAdapter_init(_defaultAdmin, _bridgeAdapterManager, _cacheManager, _slippageCapPct, _maxCacheSize);
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function encodeUsdt0Payload(uint32 dstEid, address refundRecipient, uint128 gasLimit)
        external
        pure
        override
        returns (bytes memory)
    {
        return abi.encode(Payload({dstEid: dstEid, refundRecipient: refundRecipient, gasLimit: gasLimit}));
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function decodeUsdt0Payload(bytes memory payload) public pure override returns (Payload memory) {
        return abi.decode(payload, (Payload));
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function encodeLzComposeMessage(address claimer) public pure override returns (bytes memory) {
        return abi.encode(claimer);
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function decodeLzComposeMessage(bytes memory message) public pure override returns (address) {
        return abi.decode(message, (address));
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function quoteBridgeNativeFee(BridgeInstruction calldata instruction, address claimer, address peer)
        public
        view
        override
        returns (MessagingFee memory, SendParam memory)
    {
        Payload memory payload = decodeUsdt0Payload(instruction.payload);
        bytes memory composeMsg = encodeLzComposeMessage(claimer);
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzComposeOption(0, payload.gasLimit, 0);

        SendParam memory sendParam = SendParam({
            dstEid: payload.dstEid,
            to: bytes32(uint256(uint160(peer))),
            amountLD: instruction.amount,
            minAmountLD: instruction.minTokenAmount,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: new bytes(0)
        });
        (,, OFTReceipt memory oftReceipt) = IOFT(localOft).quoteOFT(sendParam);
        uint256 minAmountReceived = oftReceipt.amountReceivedLD;
        require(
            minAmountReceived >= instruction.minTokenAmount,
            InsufficientAmount(minAmountReceived, instruction.minTokenAmount)
        );
        sendParam.minAmountLD = minAmountReceived;
        MessagingFee memory msgFee = IOFT(localOft).quoteSend(sendParam, false);
        return (msgFee, sendParam);
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function lzCompose(address _fromOApp, bytes32, bytes calldata _message, address, bytes calldata)
        external
        payable
        override(IUSDT0BridgeAdapter, ILayerZeroComposer)
    {
        require(msg.sender == lzEndpoint, NotLZEndpoint());

        uint32 srcEid = _message.srcEid();
        require(approvedOApps[srcEid][_fromOApp], NotApprovedOApp());

        bytes32 peerBytes32 = _message.composeFrom();
        address peer = OFTComposeMsgCodec.bytes32ToAddress(peerBytes32);
        require(approvedPeers[srcEid][peer], NotApprovedPeer());

        bytes memory composeMsg = _message.composeMsg();
        address claimer = decodeLzComposeMessage(composeMsg);
        _finalizeBridge(claimer, usdt0, _message.amountLD());
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function setOAppAndPeerAllowance(uint32 srcEid, address oapp, address peer, bool allowance)
        public
        override
        onlyRole(BRIDGE_ADAPTER_MANAGER_ROLE)
    {
        bool oldOAppAllowance = approvedOApps[srcEid][oapp];
        require(oldOAppAllowance != allowance, AlreadySet());
        approvedOApps[srcEid][oapp] = allowance;

        bool oldPeerAllowance = approvedPeers[srcEid][peer];
        require(oldPeerAllowance != allowance, AlreadySet());
        approvedPeers[srcEid][peer] = allowance;
        emit OAppAndPeerAllowanceSet(srcEid, oapp, peer, oldOAppAllowance, allowance);
    }

    function _bridge(BridgeInstruction calldata instruction, address receiver, address peer)
        internal
        override
        returns (uint256)
    {
        (MessagingFee memory msgFee, SendParam memory sendParam) = quoteBridgeNativeFee(instruction, receiver, peer);
        uint256 ethSelfBalance = address(this).balance;
        require(ethSelfBalance >= msgFee.nativeFee, NotEnougthNativeBalance(ethSelfBalance, msgFee.nativeFee));

        address oftCached = localOft;
        if (block.chainid == ETH_CHAIN_ID) {
            IERC20(usdt0).safeIncreaseAllowance(oftCached, instruction.amount);
        }
        Payload memory payload = decodeUsdt0Payload(instruction.payload);
        IOFT(oftCached).send{value: msgFee.nativeFee}(sendParam, msgFee, payload.refundRecipient);
        return sendParam.minAmountLD;
    }
}
