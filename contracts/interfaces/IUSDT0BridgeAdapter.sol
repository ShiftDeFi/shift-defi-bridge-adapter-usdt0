// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {IBridgeAdapter} from "@shift-defi/core/interfaces/IBridgeAdapter.sol";

interface IUSDT0BridgeAdapter {
    event OAppAllowanceSet(address indexed oapp, bool oldAllowance, bool newAllowance);

    error NotEnougthNativeBalance(uint256 balance, uint256 needed);
    error InsufficientAmount(uint256 received, uint256 required);
    error NotOFT();
    error NotApprovedOApp();
    error AlreadySet();

    struct Payload {
        uint32 dstEid;
        address claimer;
        uint128 gasLimit;
    }

    /**
     * @notice Initializes the adapter.
     * @param _defaultAdmin Address that receives the default admin role.
     * @param _bridgeAdapterManager Address that receives the bridge adapter manager role.
     * @param _cacheManager Address that receives the cache manager role.
     * @param _slippageCapPct Maximum allowed slippage delta in 1e18 precision.
     * @param _maxCacheSize Maximum bridge retry cache size.
     * @param _usdt0 USDT0 token address on the current chain.
     * @param _oft LayerZero OFT endpoint used for bridging.
     */
    function initialize(
        address _defaultAdmin,
        address _bridgeAdapterManager,
        address _cacheManager,
        uint256 _slippageCapPct,
        uint256 _maxCacheSize,
        address _usdt0,
        address _oft
    ) external;

    /**
     * @notice Encodes the adapter payload used for a bridge instruction.
     * @param dstEid LayerZero destination endpoint id.
     * @param claimer Address that will be able to claim bridged funds on the destination chain.
     * @param gasLimit Gas limit for the compose call on the destination chain.
     * @return Encoded adapter payload.
     */
    function encodeUsdt0Payload(uint32 dstEid, address claimer, uint128 gasLimit) external pure returns (bytes memory);

    /**
     * @notice Decodes an adapter payload from a bridge instruction.
     * @param payload Encoded adapter payload.
     * @return Decoded payload struct.
     */
    function decodeUsdt0Payload(bytes memory payload) external pure returns (Payload memory);

    /**
     * @notice Encodes the compose message sent through LayerZero.
     * @param claimer Address that will receive claimable funds after compose.
     * @param amount Amount encoded into the compose message.
     * @return Encoded compose message.
     */
    function encodeLzComposeMessage(address claimer, uint256 amount) external pure returns (bytes memory);

    /**
     * @notice Decodes a LayerZero compose message.
     * @param data Encoded compose message.
     * @return claimer Address that will receive claimable funds.
     * @return amount Amount contained in the compose message.
     */
    function decodeLzComposeMessage(bytes memory data) external pure returns (address claimer, uint256 amount);

    /**
     * @notice Quotes the native LayerZero fee and derived send parameters for a bridge instruction.
     * @param instruction Bridge instruction to quote.
     * @param receiver Address that receives the bridged OFT on the destination chain.
     * @return msgFee LayerZero messaging fee quote.
     * @return sendParam Final OFT send parameters after quote adjustments.
     */
    function quoteBridgeNativeFee(IBridgeAdapter.BridgeInstruction calldata instruction, address receiver)
        external
        view
        returns (MessagingFee memory msgFee, SendParam memory sendParam);

    /**
     * @notice Completes a LayerZero compose callback and credits claimable USDT0.
     * @param _fromOApp OApp that initiated the compose flow.
     * @param _guid Unique LayerZero message id.
     * @param _message Encoded compose message payload.
     * @param _executor Executor address supplied by LayerZero.
     * @param _extraData Additional executor-provided data.
     */
    function lzCompose(
        address _fromOApp,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable;

    /**
     * @notice Sets whether an OApp is allowed to trigger compose finalization.
     * @param oapp OApp address to update.
     * @param allowance Whether the OApp is approved.
     */
    function setOAppAllowance(address oapp, bool allowance) external;
}
