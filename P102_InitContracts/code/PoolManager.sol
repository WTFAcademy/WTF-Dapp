// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./interfaces/IPoolManager.sol";

contract PoolManager is IPoolManager {
    function getPools()
        external
        view
        override
        returns (PoolKey[] memory pools)
    {}

    function getTokens()
        external
        view
        override
        returns (address[] memory tokens)
    {}

    function getTokenPools(
        address token
    ) external view override returns (PoolKey[] memory pools) {}

    function getPoolInfo(
        address token0,
        address token1,
        uint24 fee
    ) external view override returns (PoolInfo memory poolInfo) {}

    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable override returns (address pool) {}
}
