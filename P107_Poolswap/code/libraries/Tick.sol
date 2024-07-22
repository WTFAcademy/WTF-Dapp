// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

// 用于在 Uniswap V3 池中管理刻度的库
library Tick {
    using LowGasSafeMath for int256;
    using SafeCast for int256;

    //为每个初始化的单独刻度存储信息
    struct Info {
        // 记录了所有引用这个 tick 的 position 流动性的和
        uint128 liquidityGross;
        // 当此 tick 被越过时（从左至右），池子中整体流动性需要变化的值
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        int56 tickCumulativeOutside;
        uint160 secondsPerLiquidityOutsideX128;
        uint32 secondsOutside;
        //是否已初始化
        bool initialized;
    }

    ///@notice 从给定的价格变动间隔导出每个价格变动的最大流动性
    ///@dev 在池构造函数内执行
    ///@param tickSpacing 所需的刻度间隔量，以 `tickSpacing` 的倍数实现
    ///例如，tickSpacing 为 3 需要每第 3 个刻度初始化刻度，即 ..., -6, -3, 0, 3, 6, ...
    ///@return 每个报价的最大流动性
    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        return type(uint128).max / numTicks;
    }

    ///@notice 检索费用增长数据
    ///@param self 包含初始化报价的所有报价信息的映射
    ///@param tickLower 持仓下刻度线边界
    ///@param tickUpper 仓位上刻度边界
    ///@param tickCurrent 当前报价
    ///@param FeeGrowthGlobal0X128 每单位流动性的历史全球费用增长，以 token0 为单位
    ///@param FeeGrowthGlobal1X128 每单位流动性的历史全球费用增长（以 token1 为单位）
    ///@return FeeGrowthInside0X128 在头寸的报价范围内，token0 每单位流动性的历史费用增长
    ///@return FeeGrowthInside1X128 在头寸的报价范围内，token1 每单位流动性的历史费用增长
    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        Info storage lower = self[tickLower];
        Info storage upper = self[tickUpper];

        //计算下面的费用增长
        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (tickCurrent >= tickLower) {
            feeGrowthBelow0X128 = lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lower.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 = feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128;
        }

        ///@notice 计算上面的费用增长
        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
        if (tickCurrent < tickUpper) {
            feeGrowthAbove0X128 = upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upper.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128;
        }

        feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
        feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
    }

    ///@notice 更新刻度，如果刻度从初始化翻转为未初始化则返回 true，反之亦然
    ///@param self 包含初始化报价的所有报价信息的映射
    ///@param tick 将更新的刻度
    ///@param tickCurrent 当前报价
    ///@param LiquidityDelta 从左到右（从右到左）交叉时要添加（减去）的新流动性数量
    ///@param FeeGrowthGlobal0X128 每单位流动性的历史全球费用增长，以 token0 为单位
    ///@param FeeGrowthGlobal1X128 每单位流动性的历史全球费用增长（以 token1 为单位）
    ///@param timesPerLiquidityCumulativeX128 池中每个 max(1, 流动性) 的所有时间秒数
    ///@param time 当前块时间戳转换为 uint32
    ///@param upper true 表示更新仓位的上方报价，或 false 表示更新仓位的下方报价
    ///@param maxLiquidity 单笔报价的最大流动性分配
    ///@return Flipped 刻度是否从初始化翻转为未初始化，反之亦然
    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        int24 tickCurrent,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time,
        bool upper,
        uint128 maxLiquidity
    ) internal returns (bool flipped) {
        Tick.Info storage info = self[tick];

        uint128 liquidityGrossBefore = info.liquidityGross;
        uint128 liquidityGrossAfter = LiquidityMath.addDelta(liquidityGrossBefore, liquidityDelta);

        require(liquidityGrossAfter <= maxLiquidity, 'LO');

        flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

        if (liquidityGrossBefore == 0) {
            // 按照惯例，我们假设在初始化刻度之前的所有增长都发生在刻度之下
            if (tick <= tickCurrent) {
                info.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
                info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128;
                info.tickCumulativeOutside = tickCumulative;
                info.secondsOutside = time;
            }
            info.initialized = true;
        }

        info.liquidityGross = liquidityGrossAfter;

        // 当下方（上方）刻度线从左向右（从右向左）穿过时，必须添加（移除）流动性
        info.liquidityNet = upper
            ? int256(info.liquidityNet).sub(liquidityDelta).toInt128()
            : int256(info.liquidityNet).add(liquidityDelta).toInt128();
    }

    ///@notice 清除刻度数据
///@param self 包含初始化报价的所有初始化报价信息的映射
///@param tick 将被清除的刻度
    function clear(mapping(int24 => Tick.Info) storage self, int24 tick) internal {
        delete self[tick];
    }

    ///@notice 根据价格变动的需要转换到下一个价格变动
///@param self 包含初始化报价的所有报价信息的映射
///@param tick 过渡的目标刻度
///@param FeeGrowthGlobal0X128 每单位流动性的历史全球费用增长，以 token0 为单位
///@param FeeGrowthGlobal1X128 每单位流动性的历史全球费用增长（以 token1 为单位）
///@param timesPerLiquidityCumulativeX128 每个流动性的当前秒数
///@param time 当前区块.timestamp
///@return LiquidityNet 当tick从左到右（从右到左）交叉时增加（减去）的流动性数量
    function cross(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time
    ) internal returns (int128 liquidityNet) {
        Tick.Info storage info = self[tick];
        info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
        info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128 - info.secondsPerLiquidityOutsideX128;
        info.tickCumulativeOutside = tickCumulative - info.tickCumulativeOutside;
        info.secondsOutside = time - info.secondsOutside;
        liquidityNet = info.liquidityNet;
    }
}