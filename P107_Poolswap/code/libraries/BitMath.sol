// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
///@title 位运算库
library BitMath {
    ///@notice 返回数字最高有效位的索引，
    ///其中最低有效位位于索引 0 处，最高有效位位于索引 255 处
    ///@dev 该函数满足属性：
    ///x >= 2**mostSignificantBit(x) 且 x < 2**(mostSignificantBit(x)+1)
    ///@param x 要计算最高有效位的值，必须大于 0
    ///@return r 最高有效位的索引
    function mostSignificantBit(uint256 x) internal pure returns (uint8 r) {
        require(x > 0);

        if (x >= 0x100000000000000000000000000000000) {
            x >>= 128;
            r += 128;
        }
        if (x >= 0x10000000000000000) {
            x >>= 64;
            r += 64;
        }
        if (x >= 0x100000000) {
            x >>= 32;
            r += 32;
        }
        if (x >= 0x10000) {
            x >>= 16;
            r += 16;
        }
        if (x >= 0x100) {
            x >>= 8;
            r += 8;
        }
        if (x >= 0x10) {
            x >>= 4;
            r += 4;
        }
        if (x >= 0x4) {
            x >>= 2;
            r += 2;
        }
        if (x >= 0x2) r += 1;
    }

    ///@notice 返回数字最低有效位的索引，
    ///其中最低有效位位于索引 0 处，最高有效位位于索引 255 处
    ///@dev 该函数满足属性：
    ///(x & 2**leastSignificantBit(x)) != 0 且 (x & (2**(leastSignificantBit(x)) -1)) == 0)
    ///@param x 要计算最低有效位的值，必须大于 0
    ///@return r 最低有效位的索引
    function leastSignificantBit(uint256 x) internal pure returns (uint8 r) {
        require(x > 0);

        r = 255;
        if (x & type(uint128).max > 0) {
            r -= 128;
        } else {
            x >>= 128;
        }
        if (x & type(uint64).max > 0) {
            r -= 64;
        } else {
            x >>= 64;
        }
        if (x & type(uint32).max > 0) {
            r -= 32;
        } else {
            x >>= 32;
        }
        if (x & type(uint16).max > 0) {
            r -= 16;
        } else {
            x >>= 16;
        }
        if (x & type(uint8).max > 0) {
            r -= 8;
        } else {
            x >>= 8;
        }
        if (x & 0xf > 0) {
            r -= 4;
        } else {
            x >>= 4;
        }
        if (x & 0x3 > 0) {
            r -= 2;
        } else {
            x >>= 2;
        }
        if (x & 0x1 > 0) r -= 1;
    }
}