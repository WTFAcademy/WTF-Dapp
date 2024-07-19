// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./interfaces/IPoolManager.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/IPool.sol";

contract PoolManager is IPoolManager {
    address public factory;

    // 所有 PoolKey 的数组
    PoolKey[] private poolKeys;

    // 从代币地址映射到 PoolKeys 索引数组
    mapping(address => uint32[]) private tokenPoolIndexes;

    // 所有代币的集合
    address[] private tokenList;

    // 映射以检查某个 token 是否已添加到 tokens 数组中
    mapping(address => bool) private tokenExists;

    constructor(address _factory) {
        factory = _factory;
    }

    function getPools()
        external
        view
        override
        returns (PoolKey[] memory pools)
    {
        return poolKeys;
    }

    function getTokens()
        external
        view
        override
        returns (address[] memory tokens)
    {
        return tokenList;
    }

    function getTokenPools(
        address token
    ) external view override returns (PoolKey[] memory pools) {
        uint32[] memory indexes = tokenPoolIndexes[token];
        pools = new PoolKey[](indexes.length);
        for (uint256 i = 0; i < indexes.length; i++) {
            pools[i] = poolKeys[indexes[i]];
        }
    }

    function getPoolInfo(
        address token0,
        address token1,
        uint24 fee
    ) external view override returns (PoolInfo memory poolInfo) {
        address poolAddress = IFactory(factory).getPool(token0, token1, fee);
        require(poolAddress != address(0), "PoolManager: POOL_NOT_FOUND");
        IPool pool = IPool(poolAddress);
        poolInfo = PoolInfo({
            feeProtocol: 0,
            tickLower: pool.tickLower(),
            tickUpper: pool.tickUpper(),
            tick: pool.tick(),
            sqrtPriceX96: pool.sqrtPriceX96()
        });
    }

    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable override returns (address pool) {
        pool = IFactory(factory).getPool(params.token0, params.token1, params.fee);

        if (pool != address(0)) {
            return pool;
        }

        pool = IFactory(factory).createPool(params.token0, params.token1, params.fee);

        IPool(pool).initialize(params.sqrtPriceX96, params.tickLower, params.tickUpper);

        // 添加 PoolKey 到 poolKeys 数组
        PoolKey memory poolKey = PoolKey({
            token0: params.token0,
            token1: params.token1,
            fee: params.fee
        });
        poolKeys.push(poolKey);

        // 检查并添加代币到 tokens 数组
        if (!tokenExists[params.token0]) {
            tokenList.push(params.token0);
            tokenExists[params.token0] = true;
        }
        if (!tokenExists[params.token1]) {
            tokenList.push(params.token1);
            tokenExists[params.token1] = true;
        }

        //从代币地址映射到 PoolKeys
        uint32 index = uint32(poolKeys.length - 1);
        tokenPoolIndexes[params.token0].push(index);
        tokenPoolIndexes[params.token1].push(index);

        return pool;
    }
}
