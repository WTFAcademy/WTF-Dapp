// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./SafeCast.sol";
import "./TickMath.sol";

library Tick {
    using SafeCast for int256;

    struct Info {
        uint128 liquidityGross; // tick 的总流动性
        int128 liquidityNet; // 该 tick active 是要增加或减少的流动性
        uint256 feeGrowthOutside0X128; // fee 相关
        uint256 feeGrowthOutside1X128;
        bool initialized;
    }

    function tickSpacingToMaxLiquidityPerTick(
        int24 tickSpacing
    ) internal pure returns (uint128) {
        // 两个报价之间的最大流动性， 其中两个报价由报价间隔分开（没有讲 TickMath）
        // 总 ticks（报价数）： 向下取整（MIN_TIC 是负数时向上舍入， 先除以 tickSpacing 就可以先得到整数，然后再乘以 tickSpacing）
        // 最大流动性是 type(uint128).max (因为 uniswapV3 池子的流动性定义是 uint128 public override liquidity)

        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1; // 要向上舍入， 所以加 1
        return type(uint128).max / numTicks;
    }

    // 计算费用
    function getFeeGrowthInside(
        mapping(int24 => Info) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    )
        internal
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        Info storage lower = self[tickLower];
        Info storage upper = self[tickUpper];

        // 计算费用增长（uniswapV3 里 fee 增长可以是负数， 所以处理 uint256 时可以溢出或下溢）
        unchecked {
            uint256 feeGrowthBelow0X128;
            uint256 feeGrowthBelow1X128;
            if (tickLower <= tickCurrent) {
                feeGrowthBelow0X128 = lower.feeGrowthOutside0X128;
                feeGrowthBelow1X128 = lower.feeGrowthOutside1X128;
            } else {
                feeGrowthBelow0X128 =
                    feeGrowthGlobal0X128 -
                    lower.feeGrowthOutside0X128;
                feeGrowthBelow1X128 =
                    feeGrowthGlobal1X128 -
                    lower.feeGrowthOutside1X128;
            }

            uint256 feeGrowthAbove0X128;
            uint256 feeGrowthAbove1X128;
            if (tickCurrent < tickUpper) {
                feeGrowthAbove0X128 = upper.feeGrowthOutside0X128;
                feeGrowthAbove1X128 = upper.feeGrowthOutside1X128;
            } else {
                feeGrowthAbove0X128 =
                    feeGrowthGlobal0X128 -
                    lower.feeGrowthOutside0X128;
                feeGrowthAbove1X128 =
                    feeGrowthGlobal1X128 -
                    lower.feeGrowthOutside1X128;
            }

            feeGrowthInside0X128 =
                feeGrowthGlobal0X128 -
                feeGrowthBelow0X128 -
                feeGrowthAbove0X128;
            feeGrowthInside1X128 =
                feeGrowthGlobal1X128 -
                feeGrowthBelow1X128 -
                feeGrowthAbove1X128;
        }
    }

    function update(
        mapping(int24 => Info) storage self,
        int24 tick, // 将要更新的 tick
        int24 tickCurrent, // 将被存储在 slot0
        int128 liquidityDelta,
        uint256 feeGrowthGlobalOX128,
        uint256 feeGrowthGlobal1X128,
        bool upper, // tick 是 upper 还是 lower
        uint128 maxLiquidity
    )
        internal
        returns (
            // flipped 是 true 时表示流动性激活（没有激活时流动性等于0， 返回 false; 但也有可能流动性激活的时候本身是 0）
            bool flipped
        )
    {
        // 更新liquidity before 和 after （就是加上或减去 delta）
        Info storage info = self[tick];

        uint128 liquidityGrossBefore = info.liquidityGross;
        uint128 liquidityGrossAfter = liquidityDelta < 0
            ? liquidityGrossBefore - uint128(-liquidityDelta)
            : liquidityGrossBefore + uint128(liquidityDelta);

        require(liquidityGrossAfter <= maxLiquidity, "liquidity > max");

        flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

        if (liquidityGrossBefore == 0) {
            // 4.2 update
            // f_{out,i} = f_g - f_{out, i}
            if (tick <= tickCurrent) {
                info.feeGrowthOutside0X128 = feeGrowthGlobalOX128;
                info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
            }
            info.initialized = true;
        }
        // upper tick 存储的是负 net, lower tick 存储的是正 net; 价格下降是减去（upper 负负得正， lower 正负得负），上涨是加上（upper 负正得负， lower 正正得正）
        // lower ... upper
        //    |        |
        //    +        -
        //  ------> one for zero +
        //  <------ zero for one -
        info.liquidityNet = upper
            ? info.liquidityNet - liquidityDelta
            : info.liquidityNet + liquidityDelta;
    }

    function clear(mapping(int24 => Info) storage self, int24 tick) internal {
        delete self[tick];
    }

    // tick cross 时 swap 会调用该函数（swap 时， price 穿过 cross 特定 tick 时会更新 tick 的 state）
    function cross(
        mapping(int24 => Info) storage self, // 存储 current tick 的信息
        int24 tick,
        uint256 feeGrowthGlobal0X128, // fee
        uint256 feeGrowthGlobal1X128
    ) internal returns (int128 liquidityNet) {
        // 返回 liquidityNet 用于更新当前 liquidity
        Info storage info = self[tick];

        // tick cross 的时候要更新 fee
        unchecked {
            info.feeGrowthOutside0X128 =
                feeGrowthGlobal0X128 -
                info.feeGrowthOutside0X128;
            info.feeGrowthOutside1X128 =
                feeGrowthGlobal1X128 -
                info.feeGrowthOutside1X128;
            liquidityNet = info.liquidityNet;
        }
    }
}
