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
    function exactInput(ExactInputParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        uint256 amountIn = params.amountIn;
        uint256 amountOut;

        /**
         * 在创建池子时为了避免 token 顺序导致的重复问题
         * 我们将 token 按照从小到大的顺序确定为池子中的 token0 和 token1
         * 此处需要根据 tokenIn 和 tokenOut 的大小关系来确定输入和输出的 token
         */
        bool zeroForOne = params.tokenIn < params.tokenOut;

        for (uint256 i = 0; i < params.indexPath.length; i++) {
            address _pool = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i]
            );

            require(_pool != address(0), "Pool not found");

            IPool pool = IPool(_pool);

            bytes memory data = abi.encode(
                msg.sender,
                params.tokenIn,
                params.tokenOut
            );

            // 执行交易
            (int256 amount0, int256 amount1) = pool.swap(
                msg.sender,
                zeroForOne,
                amountIn,
                params.sqrtPriceLimitX96,
                data
            );

            // 将输入的 token 数量减去交易用掉的 token 数量
            amountIn -= zeroForOne ? amount0 : amount1;

            // 将输出的 token 数量加上交易得到的 token 数量
            amountOut += zeroForOne ? amount1 : amount0;

            // 如果输入的 token 数量为 0，则退出循环
            if (amountIn == 0) {
                break;
            }
        }

        require(amountOut >= params.amountOutMinimum, "Slippage exceeded");

        emit Swap(msg.sender, zeroForOne, params.amountIn, amountIn, amountOut);

        return amountOut;
    }

    // 确定输出的 token 交易
    function exactOutput(ExactOutputParams calldata params)
        external
        payable
        override
        returns (uint256 amountIn)
    {
        uint256 amountIn = params.amountIn;
        uint256 amountOut;

        /**
         * 在创建池子时为了避免 token 顺序导致的重复问题
         * 我们将 token 按照从小到大的顺序确定为池子中的 token0 和 token1
         * 此处需要根据 tokenIn 和 tokenOut 的大小关系来确定输入和输出的 token
         */
        bool zeroForOne = params.tokenIn < params.tokenOut;

        for (uint256 i = 0; i < params.indexPath.length; i++) {
            address _pool = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i]
            );

            require(_pool != address(0), "Pool not found");

            IPool pool = IPool(_pool);

            bytes memory data = abi.encode(
                msg.sender,
                params.tokenIn,
                params.tokenOut
            );

            // 执行交易
            (int256 amount0, int256 amount1) = pool.swap(
                msg.sender,
                zeroForOne,
                amountIn,
                params.sqrtPriceLimitX96,
                data
            );

            // 将输入的 token 数量减去交易用掉的 token 数量
            amountIn -= zeroForOne ? amount0 : amount1;

            // 将输出的 token 数量加上交易得到的 token 数量
            amountOut += zeroForOne ? amount1 : amount0;

            // 如果输入的 token 数量为 0，则退出循环
            if (amountIn == 0) {
                break;
            }
        }

        require(amountOut >= params.amountOutMinimum, "Slippage exceeded");

        emit Swap(msg.sender, zeroForOne, params.amountIn, amountIn, amountOut);

        return amountOut;
    }

    // 确认输入的 token，估算可以获得多少输出的 token
    function quoteExactInput(QuoteExactInputParams memory params)
        external
        view
        override
        returns (uint256 amountOut)
    {}

    // 确认输出的 token，估算需要多少输入的 token
    function quoteExactOutput(QuoteExactOutputParams memory params)
        external
        view
        override
        returns (uint256 amountIn)
    {}
}
