// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./IFactory.sol";

interface IPoolManager is IFactory {
    struct PoolInfo {
        address pool;
        address token0;
        address token1;
        uint32 index;
        uint24 fee;
        uint8 feeProtocol;
        int24 tickLower;
        int24 tickUpper;
        int24 tick;
        uint160 sqrtPriceX96;
        uint128 liquidity;
    }

    struct Pair {
        address token0;
        address token1;
    }

    function getPairs() external view returns (Pair[] memory);

    function getAllPools() external view returns (PoolInfo[] memory poolsInfo);

    struct CreateAndInitializeParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint160 sqrtPriceX96;
    }

    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable returns (address pool);
}
