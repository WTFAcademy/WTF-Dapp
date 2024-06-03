// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

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

    function positions(
        int8 positionType
    )
        external
        view
        override
        returns (uint128 _liquidity, uint128 tokensOwed0, uint128 tokensOwed1)
    {}

    function initialize(
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) external override {}

    function mint(
        address recipient,
        int8 positionType,
        uint128 amount,
        bytes calldata data
    ) external override returns (uint256 amount0, uint256 amount1) {}

    function collect(
        address recipient,
        int8 positionType
    ) external override returns (uint128 amount0, uint128 amount1) {}

    function burn(
        int8 positionType
    ) external override returns (uint256 amount0, uint256 amount1) {}

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {}
}
