// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./interfaces/IPoolManager.sol";
import "./Factory.sol";

contract PoolManager is Factory, IPoolManager {
    Pair[] public pairs;
    PoolInfo[] public poolInfos;

    function getPairs() external view override returns (Pair[] memory) {
        // 返回有哪些交易对，DApp 和 getAllPools 会用到
        return pairs;
    }

    function getAllPools()
        external
        pure
        override
        returns (PoolInfo[] memory poolsInfo)
    {
        // 遍历 pairs，获取当前有的所有的交易对
        // 然后调用 Factory 的 getPools 获取每个交易对的所有 pool
        // 然后获取每个 pool 的信息
        // 然后返回
        // 先 mock
        return poolsInfo;
    }


    // 遍历 poolInfos，查找下一个 index 以及是否已经存在。返回的 index 代表应该出现的位置
    function getNextPoolIndex(address token0, address token1, uint24 fee) external view returns ( uint32 length, bool isExist) {
        length = 0;
        for (uint32 i = 0; i < poolInfos.length; i++) {
            PoolInfo memory pool = poolInfos[i];
            if (pool.token0 == token0 && pool.token1 == token1) {
                if (pool.fee == fee) {
                    // 返回当前的 index
                    return (length, true);
                } else {
                    length++;
                }
            }
        }
        return (length, false);
    }

    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable override returns (address pool) {
        (uint32 index, bool isExist) = this.getNextPoolIndex(params.token0, params.token1, params.fee);
        
        if (isExist) {
            pool = this.getPool(params.token0, params.token1, index);
            return pool;
        }

        // 如果没有对应的 Pool 就创建一个 Pool
        pool = this.createPool(params.token0, params.token1, params.tickLower, params.tickUpper, params.fee);

        // 记录 poolInfo, tick 和 feeProtocol 需要看一下从哪里获取
        PoolInfo memory poolInfo = PoolInfo({
            token0: params.token0,
            token1: params.token1,
            index: index,
            fee: params.fee,
            feeProtocol: 0,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            sqrtPriceX96: params.sqrtPriceX96,
            tick: 0
        });

        poolInfos.push(poolInfo);
        // 创建成功后记录到 pairs 中。如果 index 为 1，说明是新的交易对
        if (index == 1) {
            pairs.push(Pair({
                token0: params.token0,
                token1: params.token1
            }));
        }
        
    }
}
