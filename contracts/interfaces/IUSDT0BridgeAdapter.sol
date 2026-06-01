// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {IBridgeAdapter} from "@shift-defi/core/interfaces/IBridgeAdapter.sol";

interface IUSDT0BridgeAdapter {
    event OAppAndPeerAllowanceSet(
        uint32 indexed srcEid, address indexed oapp, address indexed peer, bool oldAllowance, bool newAllowance
    );

    error NotEnougthNativeBalance(uint256 balance, uint256 needed);
    error InsufficientAmount(uint256 received, uint256 required);
    error NotLZEndpoint();
    error NotApprovedOApp();
    error NotApprovedPeer();
    error AlreadySet();

    struct Payload {
        uint32 dstEid;
        address refundRecipient;
        uint128 gasLimit;
    }

    /**
     * @notice Encodes the adapter payload used for a bridge instruction.
     * @param dstEid LayerZero destination endpoint id.
     * @param refundRecipient Address that will get refund
     * @param gasLimit Gas limit for the compose call on the destination chain.
     * @return Encoded adapter payload.
     */
    function encodeUsdt0Payload(uint32 dstEid, address refundRecipient, uint128 gasLimit)
        external
        pure
        returns (bytes memory);

    /**
     * @notice Decodes an adapter payload from a bridge instruction.
     * @param payload Encoded adapter payload.
     * @return Decoded payload struct.
     */
    function decodeUsdt0Payload(bytes memory payload) external pure returns (Payload memory);

    /**
     * @notice Encodes the compose message sent through LayerZero.
     * @param claimer Address that will receive claimable funds after compose.
     * @return Encoded compose message.
     */
    function encodeLzComposeMessage(address claimer) external pure returns (bytes memory);

    /**
     * @notice Decodes a LayerZero compose message.
     * @param data Encoded compose message.
     * @return claimer Address that will receive claimable funds.
     */
    function decodeLzComposeMessage(bytes memory data) external pure returns (address claimer);

    /**
     * @notice Quotes the native LayerZero fee and derived send parameters for a bridge instruction.
     * @param instruction Bridge instruction to quote.
     * @param claimer Address that will receive claimable funds after compose.
     * @param peer Address that receives the bridged OFT on the destination chain.
     * @return msgFee LayerZero messaging fee quote.
     * @return sendParam Final OFT send parameters after quote adjustments.
     */
    function quoteBridgeNativeFee(IBridgeAdapter.BridgeInstruction calldata instruction, address claimer, address peer)
        external
        view
        returns (MessagingFee memory msgFee, SendParam memory sendParam);

    /**
     * @notice Completes a LayerZero compose callback and credits claimable USDT0.
     * @param _fromOApp OApp that initiated the compose flow in destination chain.
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
     * @notice Sets whether an OApp and peer are allowed to bridge funds.
     * @param srcEid Source endpoint id.
     * @param oapp OApp address.
     * @param peer Peer address.
     * @param allowance Whether the OApp and peer are approved.
     */
    function setOAppAndPeerAllowance(uint32 srcEid, address oapp, address peer, bool allowance) external;
}
