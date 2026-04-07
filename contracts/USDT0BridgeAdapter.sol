// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BridgeAdapter} from "@shift-defi/core/BridgeAdapter.sol";
import {Errors} from "@shift-defi/core/libraries/Errors.sol";

import {IOFT} from "./dependencies/interfaces/layerzero/IOFT.sol";
import {IUSDT0BridgeAdapter} from "./dependencies/interfaces/IUSDT0BridgeAdapter.sol";

/// @title USDT0BridgeAdapter
/// @notice Bridge adapter for USDT0 Network
contract USDT0BridgeAdapter is BridgeAdapter, IUSDT0BridgeAdapter {
    using SafeERC20 for IERC20;

    uint64 private constant ETH_CHAIN_ID = 1;

    address public usdt0;
    address public oft;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _defaultAdmin,
        address _bridgeAdapterManager,
        address _cacheManager,
        uint256 _slippageCapPct,
        uint256 _maxCacheSize,
        address _usdt0,
        address _oft
    ) external initializer {
        require(_usdt0 != address(0), Errors.ZeroAddress());
        require(_oft != address(0), Errors.ZeroAddress());
        usdt0 = _usdt0;
        oft = _oft;
        __BridgeAdapter_init(_defaultAdmin, _bridgeAdapterManager, _cacheManager, _slippageCapPct, _maxCacheSize);
    }

    function encodeUsdt0Payload(uint32 dstEid) external pure returns (bytes memory) {
        return abi.encode(Payload({dstEid: dstEid}));
    }

    function decodeUsdt0Payload(bytes memory payload) public pure returns (Payload memory) {
        return abi.decode(payload, (Payload));
    }

    function _bridge(BridgeInstruction calldata instruction, address receiver, address)
        internal
        override
        returns (uint256)
    {
        Payload memory payload = decodeUsdt0Payload(instruction.payload);

        if (block.chainid == ETH_CHAIN_ID) {
            IERC20(usdt0).safeIncreaseAllowance(oft, instruction.amount);
        }

        IOFT.SendParam memory sendParam = IOFT.SendParam({
            dstEid: payload.dstEid,
            to: bytes32(uint256(uint160(receiver))),
            amountLD: instruction.amount,
            minAmountLD: instruction.minTokenAmount,
            extraOptions: new bytes(0),
            composeMsg: new bytes(0),
            oftCmd: new bytes(0)
        });
        (,, IOFT.OFTReceipt memory oftReceipt) = IOFT(oft).quoteOFT(sendParam);
        sendParam.minAmountLD = oftReceipt.amountReceivedLD;
        IOFT.MessagingFee memory msgFee = IOFT(oft).quoteSend(sendParam, false);

        uint256 ethSelfBalance = address(this).balance;
        if (ethSelfBalance < msgFee.nativeFee) {
            revert NotEnougthNativeBalance(ethSelfBalance, msgFee.nativeFee);
        }

        IOFT(oft).send{value: msgFee.nativeFee}(sendParam, msgFee, tx.origin);
        return instruction.amount;
    }
}
