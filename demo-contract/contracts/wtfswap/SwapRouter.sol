// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/ISwapRouter.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolManager.sol";

contract SwapRouter is ISwapRouter {
    IPoolManager public poolManager;

    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
    }

    /// @dev Parses a revert reason that should contain the numeric quote
    function parseRevertReason(
        bytes memory reason
    ) private pure returns (int256, int256) {
        if (reason.length != 64) {
            if (reason.length < 68) revert("Unexpected error");
            assembly {
                reason := add(reason, 0x04)
            }
            revert(abi.decode(reason, (string)));
        }
        return abi.decode(reason, (int256, int256));
    }

    function swapInPool(
        IPool pool,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        try
            pool.swap(
                recipient,
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                data
            )
        returns (int256 _amount0, int256 _amount1) {
            return (_amount0, _amount1);
        } catch (bytes memory reason) {
            return parseRevertReason(reason);
        }
    }

    function exactInput(
        ExactInputParams calldata params
    ) external payable override returns (uint256 amountOut) {
        // 记录确定的输入 token 的 amount
        uint256 amountIn = params.amountIn;

        // 根据 tokenIn 和 tokenOut 的大小关系，确定是从 token0 到 token1 还是从 token1 到 token0
        bool zeroForOne = params.tokenIn < params.tokenOut;

        // 遍历指定的每一个 pool
        for (uint256 i = 0; i < params.indexPath.length; i++) {
            address poolAddress = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i]
            );

            // 如果 pool 不存在，则抛出错误
            require(poolAddress != address(0), "Pool not found");

            // 获取 pool 实例
            IPool pool = IPool(poolAddress);

            // 构造 swapCallback 函数需要的参数
            bytes memory data = abi.encode(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i],
                params.recipient == address(0) ? address(0) : msg.sender
            );

            // 调用 pool 的 swap 函数，进行交换，并拿到返回的 token0 和 token1 的数量
            (int256 amount0, int256 amount1) = this.swapInPool(
                pool,
                params.recipient,
                zeroForOne,
                int256(amountIn),
                params.sqrtPriceLimitX96,
                data
            );

            // 更新 amountIn 和 amountOut
            amountIn -= uint256(zeroForOne ? amount0 : amount1);
            amountOut += uint256(zeroForOne ? -amount1 : -amount0);

            // 如果 amountIn 为 0，表示交换完成，跳出循环
            if (amountIn == 0) {
                break;
            }
        }

        // 如果交换到的 amountOut 小于指定的最少数量 amountOutMinimum，则抛出错误
        require(amountOut >= params.amountOutMinimum, "Slippage exceeded");

        // 发送 Swap 事件
        emit Swap(msg.sender, zeroForOne, params.amountIn, amountIn, amountOut);

        // 返回 amountOut
        return amountOut;
    }

    function exactOutput(
        ExactOutputParams calldata params
    ) external payable override returns (uint256 amountIn) {
        // 记录确定的输出 token 的 amount
        uint256 amountOut = params.amountOut;

        // 根据 tokenIn 和 tokenOut 的大小关系，确定是从 token0 到 token1 还是从 token1 到 token0
        bool zeroForOne = params.tokenIn < params.tokenOut;

        // 遍历指定的每一个 pool
        for (uint256 i = 0; i < params.indexPath.length; i++) {
            address poolAddress = poolManager.getPool(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i]
            );

            // 如果 pool 不存在，则抛出错误
            require(poolAddress != address(0), "Pool not found");

            // 获取 pool 实例
            IPool pool = IPool(poolAddress);

            // 构造 swapCallback 函数需要的参数
            bytes memory data = abi.encode(
                params.tokenIn,
                params.tokenOut,
                params.indexPath[i],
                params.recipient == address(0) ? address(0) : msg.sender
            );

            // 调用 pool 的 swap 函数，进行交换，并拿到返回的 token0 和 token1 的数量
            (int256 amount0, int256 amount1) = this.swapInPool(
                pool,
                params.recipient,
                zeroForOne,
                -int256(amountOut),
                params.sqrtPriceLimitX96,
                data
            );

            // 更新 amountOut 和 amountIn
            amountOut -= uint256(zeroForOne ? -amount1 : -amount0);
            amountIn += uint256(zeroForOne ? amount0 : amount1);

            // 如果 amountOut 为 0，表示交换完成，跳出循环
            if (amountOut == 0) {
                break;
            }
        }

        // 如果交换到指定数量 tokenOut 消耗的 tokenIn 数量超过指定的最大值，报错
        require(amountIn <= params.amountInMaximum, "Slippage exceeded");

        // 发射 Swap 事件
        emit Swap(
            msg.sender,
            zeroForOne,
            params.amountOut,
            amountOut,
            amountIn
        );

        // 返回交换后的 amountIn
        return amountIn;
    }

    // 报价，指定 tokenIn 的数量和 tokenOut 的最小值，返回 tokenOut 的实际数量
    function quoteExactInput(
        QuoteExactInputParams calldata params
    ) external override returns (uint256 amountOut) {
        // 因为没有实际 approve，所以这里交易会报错，我们捕获错误信息，解析需要多少 token

        return
            this.exactInput(
                ExactInputParams({
                    tokenIn: params.tokenIn,
                    tokenOut: params.tokenOut,
                    indexPath: params.indexPath,
                    recipient: address(0),
                    deadline: block.timestamp + 1 hours,
                    amountIn: params.amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: params.sqrtPriceLimitX96
                })
            );
    }

    // 报价，指定 tokenOut 的数量和 tokenIn 的最大值，返回 tokenIn 的实际数量
    function quoteExactOutput(
        QuoteExactOutputParams calldata params
    ) external override returns (uint256 amountIn) {
        return
            this.exactOutput(
                ExactOutputParams({
                    tokenIn: params.tokenIn,
                    tokenOut: params.tokenOut,
                    indexPath: params.indexPath,
                    recipient: address(0),
                    deadline: block.timestamp + 1 hours,
                    amountOut: params.amountOut,
                    amountInMaximum: type(uint256).max,
                    sqrtPriceLimitX96: params.sqrtPriceLimitX96
                })
            );
    }

    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        // transfer token
        (address tokenIn, address tokenOut, uint32 index, address payer) = abi
            .decode(data, (address, address, uint32, address));
        address _pool = poolManager.getPool(tokenIn, tokenOut, index);

        // 检查 callback 的合约地址是否是 Pool
        require(_pool == msg.sender, "Invalid callback caller");

        uint256 amountToPay = amount0Delta > 0
            ? uint256(amount0Delta)
            : uint256(amount1Delta);
        // payer 是 address(0)，这是一个用于预估 token 的请求（quoteExactInput or quoteExactOutput）
        // 参考代码 https://github.com/Uniswap/v3-periphery/blob/main/contracts/lens/Quoter.sol#L38
        if (payer == address(0)) {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amount0Delta)
                mstore(add(ptr, 0x20), amount1Delta)
                revert(ptr, 64)
            }
        }

        // 正常交易，转账给交易池
        if (amountToPay > 0) {
            IERC20(tokenIn).transferFrom(payer, _pool, amountToPay);
        }
    }
}
