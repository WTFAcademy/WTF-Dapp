// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

interface IMintCallback {
    function mintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}

interface ISwapCallback {
    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

interface IPool {
    // function factory() external view returns (address);

    function getToken0() external view returns (address);

    function getToken1() external view returns (address);

    function getFee() external view returns (uint24);

    function getTickLower() external view returns (int24);

    function getTickUpper() external view returns (int24);

    function getSqrtPriceX96() external view returns (uint160);

    function getTick() external view returns (int24);

    function getLiquidity() external view returns (uint128);

    function getPositions(
        address owner,
        int24 tickLower,
        int24 tickUpper
    )
        external
        view
        returns (uint128 _liquidity, uint128 tokensOwed0, uint128 tokensOwed1);

    function initialize(
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) external;

    event Mint(
        address sender,
        address indexed owner,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    function mint(
        address recipient,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    event Collect(
        address indexed owner,
        address recipient,
        uint128 amount0,
        uint128 amount1
    );

    function collect(
        address recipient
    ) external returns (uint128 amount0, uint128 amount1);

    event Burn(
        address indexed owner,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    function burn(
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96
    ) external returns (int256 amount0, int256 amount1);
}
