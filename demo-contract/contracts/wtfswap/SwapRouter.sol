// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./interfaces/ISwapRouter.sol";

contract SwapRouter is ISwapRouter {
    function exactInput(
        ExactInputParams calldata params
    ) external payable override returns (uint256 amountOut) {}

    function exactOutput(
        ExactOutputParams calldata params
    ) external payable override returns (uint256 amountIn) {}

    function quoteExactInput(
        QuoteExactInputParams memory params
    ) external override returns (uint256 amountOut) {}

    function quoteExactOutput(
        QuoteExactOutputParams memory params
    ) external override returns (uint256 amountIn) {}
}
