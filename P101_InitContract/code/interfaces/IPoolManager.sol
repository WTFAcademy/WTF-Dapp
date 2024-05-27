// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

interface PoolManager {
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    function getPools() external view returns (PoolKey[] memory pools);

    function getTokens() external view returns (address[] memory token0);

    function getTokenPools(address token) external view returns (PoolKey[] memory pools);

    struct PoolInfo {
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // tick range
        int24 tickLower;
        int24 tickUpper;
        // the current tick
        int24 tick; 
        // the current price
        uint160 sqrtPriceX96;
    }

    function getPoolInfo(address token0, address token1, uint24 fee) 
        external 
        view 
        returns (PoolInfo memory poolInfo);

    struct CreateAndInitializeParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint160 sqrtPriceX96;
    }

    function createAndInitializePoolIfNecessary(CreateAndInitializeParams calldata params) 
        external 
        payable 
        returns (address pool);
}