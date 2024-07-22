// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./interfaces/IPool.sol";

contract Pool is IPool {
    function factory() external view override returns (address) {}

    function token0() external view override returns (address) {}

    function token1() external view override returns (address) {}

    function fee() external view override returns (uint24) {}

    function tickLower() external view override returns (int24) {}

    function tickUpper() external view override returns (int24) {}

    function sqrtPriceX96() external view override returns (uint160) {}

    function tick() external view override returns (int24) {}

    function liquidity() external view override returns (uint128) {}

    function initialize(
        uint160 sqrtPriceX96_,
        int24 tickLower_,
        int24 tickUpper_
    ) external override {}

    function mint(
        address recipient,
        uint128 amount,
        bytes calldata data
    ) external override returns (uint256 amount0, uint256 amount1) {}

    function collect(
        address recipient
    ) external override returns (uint128 amount0, uint128 amount1) {}

    function burn(
        uint128 amount
    ) external override returns (uint256 amount0, uint256 amount1) {}

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {}
}
