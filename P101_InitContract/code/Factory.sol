// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

import "./interfaces/IFactory.sol";

contract Factory is IFactory {
    function parameters()
        external
        view
        override
        returns (address factory, address token0, address token1, uint24 fee)
    {}

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view override returns (address pool) {}

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override returns (address pool) {}
}
