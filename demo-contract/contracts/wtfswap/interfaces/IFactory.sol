// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

interface IFactory {
    function parameters()
        external
        view
        returns (address factory, address token0, address token1, uint24 fee);

    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        uint8 bump,
        address pool
    );

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee,
        uint8 bump
    ) external view returns (address pool);

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee,
        uint8 bump
    ) external returns (address pool);
}
