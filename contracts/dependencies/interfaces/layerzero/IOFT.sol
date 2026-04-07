// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IOFT {
    /**
     * @dev Struct representing token parameters for the OFT send() operation.
     */
    struct SendParam {
        uint32 dstEid; // Destination endpoint ID.
        bytes32 to; // Recipient address.
        uint256 amountLD; // Amount to send in local decimals.
        uint256 minAmountLD; // Minimum amount to send in local decimals.
        bytes extraOptions; // Additional options supplied by the caller to be used in the LayerZero message.
        bytes composeMsg; // The composed message for the send() operation.
        bytes oftCmd; // The OFT command to be executed, unused in default OFT implementations.
    }

    /**
     * @dev Struct representing OFT receipt information.
     */
    struct OFTReceipt {
        uint256 amountSentLD; // Amount of tokens ACTUALLY debited from the sender in local decimals.
        // @dev In non-default implementations, the amountReceivedLD COULD differ from this value.
        uint256 amountReceivedLD; // Amount of tokens to be received on the remote side.
    }

    struct MessagingFee {
        uint256 nativeFee; // Native fee in the source chain's token.
        uint256 lzTokenFee; // LayerZero token fee in the LZ
    }

    function send(SendParam memory sendParam, MessagingFee memory msgFee, address refundAddress) external payable;
    function quoteOFT(SendParam memory sendParam) external view returns (uint256, uint256, OFTReceipt memory);
    function quoteSend(SendParam memory sendParam, bool useZro) external view returns (MessagingFee memory);
}
