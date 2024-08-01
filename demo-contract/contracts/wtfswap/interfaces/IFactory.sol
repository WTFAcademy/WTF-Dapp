// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

interface IFactory {
    function parameters()
        external
        view
        returns (
            address factory,
            address token0,
            address token1,
            int24 tickLower,
            int24 tickUpper,
            uint24 fee
        );

    event PoolCreated(
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee,
        address pool
    );

    function getPools(
        address tokenA,
        address tokenB
    ) external view returns (address[] memory pools);

    function createPool(
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) external returns (address pool);
}
