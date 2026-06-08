// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {USDT0BridgeAdapterBase} from "./USDT0BridgeAdapterBase.sol";

contract USDT0BridgeAdapterTest is USDT0BridgeAdapterBase {
    uint256 constant ETHEREUM_CHAIN_ID = 1;
    uint256 constant ARBITRUM_CHAIN_ID = 42161;

    uint32 constant ETHEREUM_EID = 30101;
    uint32 constant ARBITRUM_EID = 30110;
    address constant ETHEREUM_USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant ETHEREUM_OFT = 0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee;
    address constant ARBITRUM_USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address constant ARBITRUM_OFT = 0x14E4A1B13bf7F943c8ff7C51fb60FA964A298D92;
    address constant ETHEREUM_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address constant ARBITRUM_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;

    function setUp() public {
        string memory ETHEREUM_RPC = vm.envString("ETH_RPC_URL");
        string memory ARBITRUM_RPC = vm.envString("ARB_RPC_URL");

        _setUp(
            Fork({
                rpc: ETHEREUM_RPC,
                usdt: ETHEREUM_USDT,
                oft: ETHEREUM_OFT,
                lzEndpoint: ETHEREUM_LZ_ENDPOINT,
                chainId: ETHEREUM_CHAIN_ID,
                eid: ETHEREUM_EID
            }),
            Fork({
                rpc: ARBITRUM_RPC,
                usdt: ARBITRUM_USDT,
                oft: ARBITRUM_OFT,
                lzEndpoint: ARBITRUM_LZ_ENDPOINT,
                chainId: ARBITRUM_CHAIN_ID,
                eid: ARBITRUM_EID
            })
        );
    }
}
