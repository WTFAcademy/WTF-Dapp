// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

library Position {
    //为每个用户存储的流动性信息
    struct Info {
        // 此 position 中包含的流动性大小，即 L 值
        uint128 liquidity;
        //截至上次更新流动性或所欠费用时每单位流动性的费用增长
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        //token0/token1 中欠头寸所有者的费用
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /// @notice 返回position 的信息结构，给定所有者和 position 边界
    ///@param self 包含所有用户流动性的映射
    ///@param Owner 头寸所有者的地址
    ///@param tickLower 持仓下刻度线边界
    ///@param tickUpper 头寸上刻度边界
    ///@returnposition 给定所有者流动性的流动性信息结构体
    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Position.Info storage position) {
        position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    ///@notice 将累计费用记入用户的仓位
    ///@param self 要更新的个人流动性
    ///@param LiquidityDelta 仓位更新导致的资金池流动性变化
    ///@param FeeGrowthInside0X128 在头寸的报价范围内，token0 每单位流动性的历史费用增长
    ///@param FeeGrowthInside1X128 在头寸的报价范围内，token1 每单位流动性的历史费用增长
    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        Info memory _self = self;

        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            require(_self.liquidity > 0, 'NP'); //不允许对 0 流动性头寸进行 Poke
            liquidityNext = _self.liquidity;
        } else {
            liquidityNext = LiquidityMath.addDelta(_self.liquidity, liquidityDelta);
        }

        //计算累计费用
        uint128 tokensOwed0 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside0X128 - _self.feeGrowthInside0LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );
        uint128 tokensOwed1 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside1X128 - _self.feeGrowthInside1LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );

        //更新流动性
        if (liquidityDelta != 0) self.liquidity = liquidityNext;
        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            //溢出是可以接受的，必须在输入 type(uint128).max 费用之前提款
            self.tokensOwed0 += tokensOwed0;
            self.tokensOwed1 += tokensOwed1;
        }
    }
}