// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

///@title 安全类型转换库
library SafeCast {
    ///@notice 将 uint256 转换为 uint160，溢出时恢复
    ///@param y 要向下转换的 uint256
    ///@return z 向下转型的整数，现在类型为 uint160
    function toUint160(uint256 y) internal pure returns (uint160 z) {
        require((z = uint160(y)) == y);
    }

    ///@notice 将 int256 转换为 int128，在上溢或下溢时恢复
    ///@param y 要向下转换的 int256
    ///@return z 向下转换的整数，现在类型为 int128
    function toInt128(int256 y) internal pure returns (int128 z) {
        require((z = int128(y)) == y);
    }

    ///@notice 将 uint256 转换为 int256，溢出时恢复
    ///@param y 要转换的 uint256
    ///@return z 转换后的整数，现在类型为 int256
    function toInt256(uint256 y) internal pure returns (int256 z) {
        require(y < 2**255);
        z = int256(y);
    }
}