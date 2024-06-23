pragma solidity ^0.8.24;

import "./FullMath.sol";
import "./SqrtPriceMath.sol";

library SwapMath {
    /**
     * @dev computeSwapStep
     * @notice 参数当前流动性 liquidity、剩余金额（amountTokenIn 时，剩余金额 amountRemaining 是正， amountTokenOut 时剩余金额是负）
     * @notice feePip 是 swap 要收取的百分比：1e6 = 100%, 1/100 of a bip
     * @notice 1 bip = 1/100 * 1% = 1 / 1e4
     * @notice amountIn 是从 sqrtRatioCurrentX96 到 sqrtRatioTargetX96
     * @notice amountOut 是 amountIn对应的输出
     */
    function computeSwapStep(
        uint160 sqrtRatioCurrentX96, // current tick
        uint160 sqrtRatioTargetX96, // target tick 如果在 current tick 的左边， 那么这个 trade 就是 0 for 1， 否则就是 1 for 0
        uint128 liquidity,
        int256 amountRemaining,
        uint24 feePips
    )
        internal
        pure
        returns (
            uint160 sqrtRatioNextX96,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        //  0 for 1 就是存入 token0 取出 token1 会导致 curent tick 左移，因为会导致 token0 增加， token1 减少 ( 1 for 0 就是存入 token1 取出token0)
        // token 1 | token 0
        // current tick
        // <--- 0 for 1
        //      1 for 0 --->
        // target tick  如果在 current tick 的左边， 那么这个 trade 就是 0 for 1， 否则就是 1 for 0
        bool zeroForOne = sqrtRatioCurrentX96 >= sqrtRatioTargetX96;
        // exactIn 是 true时， amountRemaining 是正数（如果是 false 就是负数）
        bool exactIn = amountRemaining >= 0;

        // 计算最大 amounIn 或 amounOut 金额（这取决于amountRemaining 是正数还是负数）
        if (exactIn) {
            // 剩余金额减去费用、
            uint256 amountRemainingLessFee = FullMath.mulDiv(
                uint256(amountRemaining),
                1e6 - feePips,
                1e6
            );
            // 计算最大 amount in（round up）
            // 因为 zeroForOne 情况下， sqrtRatioTargetX96 在 sqrtRatioCurrentX96 左边
            amountIn = zeroForOne
                ? SqrtPriceMath.getAmount0Delta(
                    sqrtRatioTargetX96,
                    sqrtRatioCurrentX96,
                    liquidity,
                    true
                )
                : SqrtPriceMath.getAmount1Delta(
                    sqrtRatioCurrentX96,
                    sqrtRatioTargetX96,
                    liquidity,
                    true
                );

            if (amountRemainingLessFee >= amountIn) {
                sqrtRatioNextX96 = sqrtRatioTargetX96;
            } else {
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    amountRemainingLessFee,
                    zeroForOne
                );
            }
            // 如果 swap 导致 sqrtRatioCurrentX96 向 sqrtRatioTargetX96 移动， 那么 fee 将从 amountRemaining 中扣除（否则 fee 就从 amountIn 中扣除）
        } else {
            // 计算最大 amount out（round down，如果是 round up 的话会导致给多了)
            amountOut = zeroForOne
                ? SqrtPriceMath.getAmount1Delta(
                    sqrtRatioTargetX96,
                    sqrtRatioCurrentX96,
                    liquidity,
                    false
                )
                : SqrtPriceMath.getAmount0Delta(
                    sqrtRatioCurrentX96,
                    sqrtRatioTargetX96,
                    liquidity,
                    false
                );

            // 此时 amountIn 会是负数
            if (uint256(-amountRemaining) >= amountOut) {
                sqrtRatioNextX96 = sqrtRatioTargetX96;
            } else {
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromOutput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    uint256(-amountRemaining),
                    zeroForOne
                );
            }
        }

        // maxTrade: 这个 swap 使用完了所有 amountIn 或 amountOut
        bool max = sqrtRatioTargetX96 == sqrtRatioNextX96;
        if (zeroForOne) {
            amountIn = max && exactIn
                ? amountIn
                : SqrtPriceMath.getAmount0Delta(
                    sqrtRatioNextX96,
                    sqrtRatioCurrentX96,
                    liquidity,
                    true
                );
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount1Delta(
                    sqrtRatioNextX96,
                    sqrtRatioCurrentX96,
                    liquidity,
                    false
                );
        } else {
            amountIn = max && exactIn
                ? amountIn
                : SqrtPriceMath.getAmount1Delta(
                    sqrtRatioCurrentX96,
                    sqrtRatioNextX96,
                    liquidity,
                    true
                );
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount0Delta(
                    sqrtRatioCurrentX96,
                    sqrtRatioNextX96,
                    liquidity,
                    false
                );
        }

        // 确保 amountOut 不会超过剩余的数量
        if (!exactIn && amountOut > uint256(-amountRemaining)) {
            amountOut = uint256(-amountRemaining);
        }

        if (exactIn && sqrtRatioNextX96 != sqrtRatioTargetX96) {
            feeAmount = uint256(amountRemaining) - amountIn;
        } else {
            // fee 公式的推导过程
            // a = amountIn
            // f = feePips
            // x = a + fee = a + x * f
            // fee = x * f = a * f / (1- f)
            feeAmount = FullMath.mulDivRoundingUp(
                amountIn,
                feePips,
                1e6 - feePips
            );
        }
    }
}
