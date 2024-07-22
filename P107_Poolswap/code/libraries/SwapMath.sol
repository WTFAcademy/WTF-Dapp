// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

// swap合约核心 这里计算了交易是否能在目标价格范围内结束，以及消耗的 tokenIn 和得到的 tokenOut. 
/// @title Computes the result of a swap within ticks
/// @notice Contains methods for computing the result of a swap within a single tick price range, i.e., a single tick.
library SwapMath {
    /// @notice 这里计算了交易是否能在目标价格范围内结束，以及消耗的 tokenIn 和得到的 tokenOut
    /// @dev The fee, plus the amount in, will never exceed the amount remaining if the swap's `amountSpecified` is positive
    /// @param sqrtRatioCurrentX96 The current sqrt price of the pool
    /// @param sqrtRatioTargetX96 The price that cannot be exceeded, from which the direction of the swap is inferred
    /// @param liquidity The usable liquidity
    /// @param amountRemaining How much input or output amount is remaining to be swapped in/out
    /// @param feePips The fee taken from the input amount, expressed in hundredths of a bip
    /// @return sqrtRatioNextX96 The price after swapping the amount in/out, not to exceed the price target
    /// @return amountIn The amount to be swapped in, of either token0 or token1, based on the direction of the swap
    /// @return amountOut The amount to be received, of either token0 or token1, based on the direction of the swap
    /// @return feeAmount The amount of input that will be taken as a fee
    //函数的输入参数是当前价格，目标价格，当前的流动性，以及 tokenIn 的余额。
    function computeSwapStep(
        uint160 sqrtRatioCurrentX96,
        uint160 sqrtRatioTargetX96,
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
        bool zeroForOne = sqrtRatioCurrentX96 >= sqrtRatioTargetX96;    // 判断交易的方向，即价格降低或升高
        bool exactIn = amountRemaining >= 0;         // 判断是否指定了精确的 tokenIn 数量

        if (exactIn) {// 先将 tokenIn 的余额扣除掉最大所需的手续费
            uint256 amountRemainingLessFee = FullMath.mulDiv(uint256(amountRemaining), 1e6 - feePips, 1e6);
            amountIn = zeroForOne         // 通过公式计算出到达目标价所需要的 tokenIn 数量，这里对 x token 和 y token 计算的公式是不一样的
                ? SqrtPriceMath.getAmount0Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, true)
                : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, true);
            // 判断余额是否充足，如果充足，那么这次交易可以到达目标交易价格，否则需要计算出当前 tokenIn 能到达的目标交易价
            if (amountRemainingLessFee >= amountIn) sqrtRatioNextX96 = sqrtRatioTargetX96;        
            else    // 当余额不充足的时候计算能够到达的目标交易价
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    amountRemainingLessFee,
                    zeroForOne
                );
        } else {
            amountOut = zeroForOne
                ? SqrtPriceMath.getAmount1Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, false)
                : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, false);
            if (uint256(-amountRemaining) >= amountOut) sqrtRatioNextX96 = sqrtRatioTargetX96;
            else
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromOutput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    uint256(-amountRemaining),
                    zeroForOne
                );
        }
        // 判断是否能够到达目标价
        bool max = sqrtRatioTargetX96 == sqrtRatioNextX96;

        // 获取输入/输出量
        if (zeroForOne) {
            // 根据是否到达目标价格，计算 amountIn/amountOut 的值
            amountIn = max && exactIn
                ? amountIn
                : SqrtPriceMath.getAmount0Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true);
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount1Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false);
        } else {
            amountIn = max && exactIn
                ? amountIn
                : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true);
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
        }

        // 这里对 Output 进行 cap 是因为前面在计算 amountOut 时，有可能会使用 sqrtRatioNextX96 来进行计算，而 sqrtRatioNextX96
        // 可能被 Round 之后导致 sqrt_P 偏大，从而导致计算的 amountOut 偏大
        if (!exactIn && amountOut > uint256(-amountRemaining)) {
            amountOut = uint256(-amountRemaining);
        }

        if (exactIn && sqrtRatioNextX96 != sqrtRatioTargetX96) {
            // 如果没能到达目标价，即交易结束，剩余的 tokenIn 将全部作为手续费
        // 为了不让计算进一步复杂化，这里直接将剩余的 tokenIn 将全部作为手续费
        // 因此会多收取一部分手续费，即按本次交易的最大手续费收取
            feeAmount = uint256(amountRemaining) - amountIn;
        } else {
            feeAmount = FullMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
        }
    }
}