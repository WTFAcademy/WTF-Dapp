// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

library LiquidityMath {
    ///@notice 将签名的流动性增量添加到流动性中，并在溢出或下溢时恢复
    ///@param x 变动前的流动性
    ///@param y 流动性应改变的增量
    ///@return z 流动性增量
    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            require((z = x - uint128(-y)) < x, 'LS');
        } else {
            require((z = x + uint128(y)) >= x, 'LA');
        }
    }
}