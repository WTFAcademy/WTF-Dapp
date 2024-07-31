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
            uint24 fee,
            int24 tickLower,
            int24 tickUpper
        );

    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint32 indexed index,
        address pool
    );

    function getPool(
        address tokenA,
        address tokenB,
        uint32 index
    ) external view returns (address pool);

    function createPool(
        address tokenA,
        address tokenB,
        uint32 index,
        uint24 fee
    ) external returns (address pool);
}
