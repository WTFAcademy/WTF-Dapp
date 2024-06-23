// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

// 复制的 Uniswap 原合约 https://github.com/Uniswap/v4-core

/// @title FixedPoint96
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Used in SqrtPriceMath.sol
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    // Q96 = 2**96 = 1 << 96
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}
