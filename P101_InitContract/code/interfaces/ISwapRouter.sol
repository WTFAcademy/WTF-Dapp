// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

interface SwapRouter {
    struct ExactInputParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInput(ExactInputParams calldata params) 
        external 
        payable 
        returns (uint256 amountOut);

    struct ExactOutputParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutput(ExactOutputParams calldata params) 
        external 
        payable 
        returns (uint256 amountIn);

    struct QuoteExactInputParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactInput(QuoteExactInputParams memory params)
        external
        returns (uint256 amountOut);

    struct QuoteExactOutputParams {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactOutput(QuoteExactOutputParams memory params)
        external
        returns (uint256 amountIn);
}