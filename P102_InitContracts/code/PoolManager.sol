// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./interfaces/IPoolManager.sol";

/**
  * @Auther Eli Lee
  * @Describe
  */
contract PoolManager is IPoolManager {

    // PoolKey 映射到 PoolInfo
    mapping(bytes32 => PoolInfo) private pools;

    // 所有 PoolKey 的数组
    PoolKey[] private poolKeys;

    // 从代币地址映射到 PoolKeys 数组
    mapping(address => PoolKey[]) private tokenPools;

    // 所有代币的集合
    address[] private tokens;

    // 映射以检查某个 token 是否已添加到 tokens 数组中
    mapping(address => bool) private tokenExists;

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
        return tokens;
    }

    function getTokenPools(
        address token
    ) external view override returns (PoolKey[] memory pools) {
        //bytes32 poolId = keccak256(abi.encode(token0, token1, fee));
        //return pools[poolId];
        return tokenPools[token];
    }

    function getPoolInfo(
        address token0,
        address token1,
        uint24 fee
    ) external view override returns (PoolInfo memory poolInfo) {
        bytes32 poolId = keccak256(abi.encodePacked(token0, token1, fee));
        return pools[poolId];
    }

    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable override returns (address pool) {
        bytes32 poolId = keccak256(abi.encode(params.token0, params.token1, params.fee));

        //判断是否已存在相同交易对以及费率的池子
        if(pools[poolId].sqrtPriceX96 == 0){
            PoolInfo memory newPool;
            newPool.feeProtocol = params.fee;
            newPool.tickLower = params.tickLower;
            newPool.tickUpper = params.tickUpper;
            newPool.tick = 0;
            newPool.sqrtPriceX96 = params.sqrtPriceX96;

            pools[poolId] = newPool;
            //添加代币新坚池子刀池子集合中
            poolKeys.push(PoolKey({
                     token0 : params.token0,
                     token1 : params.token1,
                     fee : params.fee
                })
            );

            // 添加代币对应池子的映射
            tokenPools[params.token0].push(PoolKey({
                token0: params.token0,
                token1: params.token1,
                fee: params.fee
            }));
            tokenPools[params.token1].push(PoolKey({
                token0: params.token0,
                token1: params.token1,
                fee: params.fee
            }));

            //添加代币在代币列表中昂不存在那么将代币添加到代币列表中,并且改变其在tokens中的状态
            if(!tokenExists[params.token0]){
                tokens.push(params.token0);
                tokenExists[params.token0] = true;
            }
            if(!tokenExists[params.token1]){
                tokens.push(params.token1);
                tokenExists[params.token1] = true;
            }

            return address(this);
        }else{
            //已经存在的池子直接返回
            return address(this);
        }
    }
}
