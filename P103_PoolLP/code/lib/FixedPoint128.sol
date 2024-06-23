// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

// 复制的 Uniswap 原合约 https://github.com/Uniswap/v4-core

/// @title FixedPoint128
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
library FixedPoint128 {
    // one shifted over to the left 128 times
    // 这个数字用来乘以和除以liquidity（除以流动性是因为流动性都是乘以了 Q128）
    // Q128 = 2**128 = 1 << 128
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;
}
