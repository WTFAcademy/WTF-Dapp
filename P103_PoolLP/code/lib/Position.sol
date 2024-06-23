// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./FullMath.sol";
import "./FixedPoint128.sol";

library Position {
    struct Info {
        // 本仓位流动性数量
        uint128 liquidity;
        // 流动性上次更新时每单位流动性的费用增长
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // 应向仓位所有者支付的 token0/token1 费用
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Info storage position) {
        position = self[
            keccak256(abi.encodePacked(owner, tickLower, tickUpper))
        ];
    }

    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        Info memory _self = self;

        if (liquidityDelta == 0) {
            require(_self.liquidity > 0, "0 liquidity");
        }

        // tokens owed
        uint128 tokensOwed0 = uint128(
            FullMath.mulDiv(
                // latest feeGrowthInsideOX128 - previousfeeGrowthInside0X128
                feeGrowthInside0X128 - _self.feeGrowthInside0LastX128,
                _self.liquidity,
                FixedPoint128.Q128
            )
        );

        uint128 tokensOwed1 = uint128(
            FullMath.mulDiv(
                // latest feeGrowthInsideOX128 - previousfeeGrowthInside0X128
                feeGrowthInside1X128 - _self.feeGrowthInside1LastX128,
                _self.liquidity,
                FixedPoint128.Q128
            )
        );

        if (liquidityDelta != 0) {
            self.liquidity = liquidityDelta < 0
                ? _self.liquidity - uint128(-liquidityDelta)
                : _self.liquidity + uint128(liquidityDelta);
        }

        // 更新 position tokens owed
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            self.tokensOwed0 += tokensOwed0;
            self.tokensOwed1 += tokensOwed1;
        }
    }
}
