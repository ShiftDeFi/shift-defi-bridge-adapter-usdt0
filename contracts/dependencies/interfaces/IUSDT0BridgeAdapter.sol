// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IUSDT0BridgeAdapter {
    error NotEnougthNativeBalance(uint256 balance, uint256 needed);

    struct Payload {
        uint32 dstEid;
    }
}
