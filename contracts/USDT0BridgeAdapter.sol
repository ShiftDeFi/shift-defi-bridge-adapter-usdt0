// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OptionsBuilder} from "@layer-zero/devtools/packages/oapp-evm/oapp/libs/OptionsBuilder.sol";
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

    uint256 private constant ETH_CHAIN_ID = 1;

    address public usdt0;
    address public oft;

    mapping(address => bool) public approvedOApps;

    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function initialize(
        address _defaultAdmin,
        address _bridgeAdapterManager,
        address _cacheManager,
        uint256 _slippageCapPct,
        uint256 _maxCacheSize,
        address _usdt0,
        address _oft
    ) external override initializer {
        require(_usdt0 != address(0), Errors.ZeroAddress());
        require(_oft != address(0), Errors.ZeroAddress());
        usdt0 = _usdt0;
        oft = _oft;
        __BridgeAdapter_init(_defaultAdmin, _bridgeAdapterManager, _cacheManager, _slippageCapPct, _maxCacheSize);
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function encodeUsdt0Payload(uint32 dstEid, address claimer, uint128 gasLimit)
        external
        pure
        override
        returns (bytes memory)
    {
        return abi.encode(Payload({dstEid: dstEid, claimer: claimer, gasLimit: gasLimit}));
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function decodeUsdt0Payload(bytes memory payload) public pure override returns (Payload memory) {
        return abi.decode(payload, (Payload));
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function encodeLzComposeMessage(address claimer, uint256 amount) public pure override returns (bytes memory) {
        return abi.encode(claimer, amount);
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function decodeLzComposeMessage(bytes memory data) public pure override returns (address, uint256) {
        return abi.decode(data, (address, uint256));
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function quoteBridgeNativeFee(BridgeInstruction calldata instruction, address receiver)
        public
        view
        override
        returns (MessagingFee memory, SendParam memory)
    {
        Payload memory payload = decodeUsdt0Payload(instruction.payload);
        bytes memory composeMsg = encodeLzComposeMessage(payload.claimer, instruction.amount);
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzComposeOption(0, payload.gasLimit, 0);

        SendParam memory sendParam = SendParam({
            dstEid: payload.dstEid,
            to: bytes32(uint256(uint160(receiver))),
            amountLD: instruction.amount,
            minAmountLD: instruction.minTokenAmount,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: new bytes(0)
        });
        (,, OFTReceipt memory oftReceipt) = IOFT(oft).quoteOFT(sendParam);
        sendParam.minAmountLD = oftReceipt.amountReceivedLD;
        MessagingFee memory msgFee = IOFT(oft).quoteSend(sendParam, false);
        return (msgFee, sendParam);
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function lzCompose(
        address _fromOApp,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable override(IUSDT0BridgeAdapter, ILayerZeroComposer) {
        require(msg.sender == oft, NotOFT());
        require(approvedOApps[_fromOApp], NotApprovedOApp());
        (address claimer, uint256 amount) = decodeLzComposeMessage(_message);
        _finalizeBridge(claimer, usdt0, amount);
    }

    /// @inheritdoc IUSDT0BridgeAdapter
    function setOAppAllowance(address oapp, bool allowance) external onlyRole(BRIDGE_ADAPTER_MANAGER_ROLE) override {
        bool oldAllowance = approvedOApps[oapp];
        require(oldAllowance != allowance, AlreadySet());
        approvedOApps[oapp] = allowance;
    }

    function _bridge(BridgeInstruction calldata instruction, address receiver, address)
        internal
        override
        returns (uint256)
    {
        address oftCached = oft;
        if (block.chainid == ETH_CHAIN_ID) {
            IERC20(usdt0).safeIncreaseAllowance(oftCached, instruction.amount);
        }

        (MessagingFee memory msgFee, SendParam memory sendParam) = quoteBridgeNativeFee(instruction, receiver);
        uint256 ethSelfBalance = address(this).balance;
        if (ethSelfBalance < msgFee.nativeFee) {
            revert NotEnougthNativeBalance(ethSelfBalance, msgFee.nativeFee);
        }

        IOFT(oftCached).send{value: msgFee.nativeFee}(sendParam, msgFee, tx.origin);
        return instruction.amount;
    }
}
