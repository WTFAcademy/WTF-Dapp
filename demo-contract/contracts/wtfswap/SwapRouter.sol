// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./interfaces/ISwapRouter.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolManager.sol";

contract SwapRouter is ISwapRouter {
    IPoolManager public poolManager;

    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
    }

    // 确定输入的 token 交易
    function exactInput(
        ExactInputParams calldata params
    ) external payable override returns (uint256 amountOut) {
        uint256 amountIn = params.amountIn;

        for (uint256 i = 0; i < params.indexPath.length; i++) {
            address _pool = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i]
            );
            IPool pool = IPool(_pool);

            (uint256 amount0Out, uint256 amount1Out) = pool.getAmountsOut(
                amountIn
            );
            amountOut = params.tokenIn < params.tokenOut
                ? amount1Out
                : amount0Out;

            bytes memory data = abi.encode(
                msg.sender,
                params.tokenIn,
                params.tokenOut
            );
            pool.swap(
                msg.sender,
                params.tokenIn < params.tokenOut,
                amountIn,
                amountOut,
                data
            );

            amountIn = amountOut; // 为下一次循环准备
        }
    }

    // 确定输出的 token 交易
    function exactOutput(
        ExactOutputParams calldata params
    ) external payable override returns (uint256 amountIn) {
        uint256 amountOut = params.amountOut;

        for (uint256 i = params.indexPath.length; i > 0; i--) {
            address _pool = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i - 1]
            );
            IPool pool = IPool(_pool);

            (uint256 amount0In, uint256 amount1In) = pool.getAmountsIn(
                amountOut
            );
            amountIn = params.tokenIn < params.tokenOut ? amount0In : amount1In;

            bytes memory data = abi.encode(
                msg.sender,
                params.tokenIn,
                params.tokenOut
            );
            pool.swap(
                msg.sender,
                params.tokenIn > params.tokenOut,
                amountIn,
                amountOut,
                data
            );

            amountOut = amountIn; // 为下一次循环准备
        }
    }

    // 确认输入的 token，估算可以获得多少输出的 token
    function quoteExactInput(
        QuoteExactInputParams memory params
    ) external view override returns (uint256 amountOut) {
        uint256 amountIn = params.amountIn;

        for (uint256 i = 0; i < params.indexPath.length; i++) {
            address _pool = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i]
            );
            IPool pool = IPool(_pool);

            (uint256 amount0Out, uint256 amount1Out) = pool.getAmountsOut(
                amountIn
            );
            amountOut = params.tokenIn < params.tokenOut
                ? amount1Out
                : amount0Out;

            amountIn = amountOut; // 为下一次循环准备
        }
    }

    // 确认输出的 token，估算需要多少输入的 token
    function quoteExactOutput(
        QuoteExactOutputParams memory params
    ) external view override returns (uint256 amountIn) {
        uint256 amountOut = params.amountOut;

        for (uint256 i = params.indexPath.length; i > 0; i--) {
            address _pool = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i - 1]
            );
            IPool pool = IPool(_pool);

            (uint256 amount0In, uint256 amount1In) = pool.getAmountsIn(
                amountOut
            );
            amountIn = params.tokenIn < params.tokenOut ? amount0In : amount1In;

            amountOut = amountIn; // 为下一次循环准备
        }
    }

    function swapCallback(
        uint256 amount0In,
        uint256 amount1In,
        bytes calldata data
    ) external override {
        (address sender, address tokenIn, address tokenOut) = abi.decode(
            data,
            (address, address, address)
        );
        uint256 amountIn = tokenIn < tokenOut ? amount0In : amount1In;
        require(
            IERC20(tokenIn).transferFrom(sender, msg.sender, amountIn),
            "Transfer failed"
        );
    }
}
