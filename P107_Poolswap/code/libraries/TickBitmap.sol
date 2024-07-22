// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;


///@title 位图库
library TickBitmap {
    ///@notice 计算报价的初始化位所在的映射中的流动性
    ///@param tick 用于计算流动性的刻度
    ///@return wordPos 映射中包含存储位的word的键
    ///@return bitPos 存储标志的word中的位流动性
    function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8);
        bitPos = uint8(uint24(tick % 256));
    }

    ///@notice 将给定刻度的初始化状态从 false 翻转为 true，反之亦然
    ///@param self 翻转刻度的映射
    ///@param tick 要翻转的刻度
    ///@param tickSpacing 可用刻度之间的间距
    function flipTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        require(tick % tickSpacing == 0); // ensure that the tick is spaced
        (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
        uint256 mask = 1 << bitPos;
        self[wordPos] ^= mask;
    }

    ///@notice 返回与以下任一标记相同的word（或相邻word）中包含的下一个初始化标记
    ///给定刻度的左侧（小于或等于）或右侧（大于）
    ///@param self 用于计算下一个初始化刻度的映射
    ///@param tick 起始刻度
    ///@param tickSpacing 可用刻度之间的间距
    ///@param lte 是否搜索左侧下一个初始化的刻度（小于或等于起始刻度）
    ///@return next 距离当前刻度最多 256 个刻度的下一个已初始化或未初始化刻度
    ///@returninitialized 是否初始化下一个刻度，因为该函数仅在最多 256 个刻度内搜索
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--; // round towards negative infinity

        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            //当前bitPos右边或右边的所有1
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = self[wordPos] & mask;

            //如果当前刻度的右侧或当前刻度处没有初始化的刻度，则返回最右边的刻度 word
            initialized = masked != 0;
            //上溢/下溢是可能的，但可以通过限制tickSpacing和tick从外部防止
            next = initialized
                ? (compressed - int24(uint24(bitPos - BitMath.mostSignificantBit(masked)))) * tickSpacing
                : (compressed - int24(uint24(bitPos))) * tickSpacing;
        } else {
            ///从下一个刻度的word开始，因为当前刻度状态无关紧要
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            //bitPos 左边或左边的所有 1
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = self[wordPos] & mask;

            //如果当前刻度左侧没有初始化的刻度，则返回最左边的刻度 word
            initialized = masked != 0;
            //上溢/下溢是可能的，但可以通过限制tickSpacing和tick从外部防止
            next = initialized
                ? (compressed + 1 + int24(uint24(BitMath.leastSignificantBit(masked) - bitPos))) * tickSpacing
                : (compressed + 1 + int24(uint24(type(uint8).max - bitPos))) * tickSpacing;
        }
    }
}