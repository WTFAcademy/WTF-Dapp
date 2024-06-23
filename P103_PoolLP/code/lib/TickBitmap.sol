// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./BitMath.sol";

library TickBitmap {
    function position(
        int24 tick
    ) private pure returns (int16 wordPos, uint8 bitPos) {
        // position 将 tick 分为 wordPos 和 bitpos
        // wordPos 是前 16 位（也就是右移 8 位）
        wordPos = int16(tick >> 8);
        //因为 2 的 8 次方等于 256， 所以模运算能获取最后 8 位
        bitPos = uint8(uint24(tick % 256));
    }

    // 翻转 tick
    function flipTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        // self 就是tickBitmap
        // tick 是要被 flip 翻转的 tick
        // tickSpacing 是 tick 的间隔 (tick 实际上会按照刻度间距更新)
        // 假设一个 trade, current trade crosses over the upper tick, 那么 next tick 就不是 upper tick + 1（而是 + tickSpacing）
        require(tick % tickSpacing == 0);
        (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
        // 创建 mask: bit position 是 1 （通过 shift 1 by bit position 来创建）
        uint256 mask = 1 << bitPos;
        // self[wordPos] 获取 current value, 如果是 1 表示刻度存在，需要翻转
        // 翻转就是做异或运算 ^=
        self[wordPos] ^= mask;
    }

    // 返回 next tick
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        // initialized 是下个刻度是否已初始化

        // 假设一个 trade, current trade crosses over the upper tick, 那么 next tick 就不是 upper tick + 1（而是 + tickSpacing）
        int24 compressed = tick / tickSpacing;
        // 让这个 compressed 向下舍入到负无穷： tick 除以 tickSpacing 时做的是整数除法，所以会截掉小数（对于正数是这样， 对于负数时向下舍入就会增加数字，所以要特殊处理）
        if (tick < 0 && tick % tickSpacing != 0) {
            // tick 没有被 tickSpacing 均匀划分 divide evenly 时就时 != 0, 此时通过减少一个 compressed 来向下舍入到负无穷
            // 用于找到 next tick
            compressed--;
        }
        if (lte) {
            // next tick <= current tick, 就是找 current tick 的右边
            (int16 wordPos, uint8 bitPos) = position(compressed);
            // 创建 mask:
            // bit position 是 1 （通过 shift 1 by bit position 来创建）同上， 然后减去 1， 就会在该位置的右侧得到所有 1
            // 最后在该位置处加1
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = self[wordPos] & mask;

            // 如果 mask ==0 就没有下个刻度， 初始化就等于 false
            initialized = masked != 0;

            // 如果 tick 初始化： nect = (compressed - remove current bit pos + right most bit of masked) * tickSpacing
            // 如果 tick 没有初始化： nect = compressed - remove current bit pos
            next = initialized
                ? (compressed -
                    int24(
                        uint24(bitPos - BitMath.mostSignificantBit(masked))
                    )) * tickSpacing
                : (compressed - int24(uint24(bitPos))) * tickSpacing;
        } else {
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);

            // next tick >= current tick, 所以是当前 tick 的左边
            // 现在当前位置创建1，-1 就是该位置右边都是 1， 然后取反就得到该位置及其左边都是 1
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = self[wordPos] & mask;

            initialized = masked != 0;

            // 加 1 是因为要找一个 > current tick 的
            next = initialized
                ? (compressed +
                    1 +
                    int24(
                        uint24(BitMath.leastSignificantBit(masked) - bitPos)
                    )) * tickSpacing
                : (compressed + 1 + int24(uint24(type(uint8).max - bitPos))) *
                    tickSpacing;
            // 没有初始化的话就是 compressed + 1, 然后用1 填充所有 bit position, 然后减去 current bit
        }
    }
}
