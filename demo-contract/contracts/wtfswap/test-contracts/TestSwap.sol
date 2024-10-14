// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "../interfaces/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestSwap is ISwapCallback {
    function testSwap(
        address recipient,
        int256 amount,
        uint160 sqrtPriceLimitX96,
        address pool,
        address token0,
        address token1
    ) external returns (int256 amount0, int256 amount1) {
        (amount0, amount1) = IPool(pool).swap(
            recipient,
            true,
            amount,
            sqrtPriceLimitX96,
            abi.encode(token0, token1)
        );
    }

    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        // transfer token
        (address token0, address token1) = abi.decode(data, (address, address));
        if (amount0Delta > 0) {
            IERC20(token0).transfer(msg.sender, uint(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(token1).transfer(msg.sender, uint(amount1Delta));
        }
    }
}
