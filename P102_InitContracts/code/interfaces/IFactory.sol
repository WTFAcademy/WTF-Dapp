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
        address pool
    );

    function getPool(
        address token0,
        address token1,
        uint24 fee
    ) external view returns (address pool);

    function createPool(
        address token0,
        address token1,
        uint24 fee
    ) external returns (address pool);
}
