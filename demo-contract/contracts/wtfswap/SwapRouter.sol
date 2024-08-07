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
        // 用 index 记录当前正在读取的 index
        uint256 index = 0;
        // while 循环遍历 indexPath，获取每个 pool 的价格
        while (index < params.indexPath.length) {
            address _pool = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[index]
            );
            IPool pool = IPool(_pool);
            // TODO 交易
            bytes memory data;
            // 交易的钱统一转给本合约，最后都完成之后在 swapCallback 中打给用户
            pool.swap(msg.sender, true, 12, 12, data);
            amountOut += 2;
            index++;
        }
    }

    // 确定输出的 token 交易
    function exactOutput(
        ExactOutputParams calldata params
    ) external payable override returns (uint256 amountIn) {}

    // 确认输入的 token，估算可以获得多少输出的 token
    function quoteExactInput(
        QuoteExactInputParams memory params
    ) external view override returns (uint256 amountOut) {
        // 用 index 记录当前正在读取的 index
        uint256 index = 0;
        // while 循环遍历 indexPath，获取每个 pool 的价格
        while (index < params.indexPath.length) {
            address _pool = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[index]
            );
            IPool pool = IPool(_pool);
            uint160 sqrtPriceX96 = pool.sqrtPriceX96();
            // TODO 计算 amountOut
            amountOut = sqrtPriceX96;
            // 更新 index
            index++;
        }
    }

    // 确认输出的 token，估算需要多少输入的 token
    function quoteExactOutput(
        QuoteExactOutputParams memory params
    ) external view override returns (uint256 amountIn) {}

    function swapCallback(
        uint256 amount0In,
        uint256 amount1In,
        bytes calldata data
    ) external override {
        // 每次 swap 后 pool 会调用这个方法
        // 最后一次 swap 完成后这里统一把钱打给用户
    }
}
