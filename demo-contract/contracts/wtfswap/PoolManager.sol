// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./interfaces/IPoolManager.sol";
import "./Factory.sol";
import "./interfaces/IPool.sol";

contract PoolManager is Factory, IPoolManager {
    Pair[] public pairs;

    function getAllPools()
        external
        view
        override
        returns (PoolInfo[] memory poolsInfo)
    {
        uint32 length = 0;
        // 先算一下大小
        for (uint32 i = 0; i < pairs.length; i++) {
            address[] memory addresses = pools[pairs[i].token0][pairs[i].token1];
            length += uint32(addresses.length);
        }

        // 再填充数据
        poolsInfo = new PoolInfo[](length);
        for (uint32 i = 0; i < pairs.length; i++) {
            address[] memory addresses = pools[pairs[i].token0][pairs[i].token1];
            for (uint32 j = 0; j < addresses.length; j++) {
                IPool pool = IPool(addresses[j]);
                poolsInfo[i] = PoolInfo({
                    token0: pool.token0(),
                    token1: pool.token1(),
                    index: j,
                    fee: pool.fee(),
                    feeProtocol: 0,
                    tickLower: pool.tickLower(),
                    tickUpper: pool.tickUpper(),
                    tick: pool.tick(),
                    sqrtPriceX96: pool.sqrtPriceX96()
                });
            }
        }
        return poolsInfo;
    }


    // 遍历 poolInfos，查找下一个 index 以及是否已经存在。返回的 index 代表应该出现的位置
    function getPoolIndex(CreateAndInitializeParams calldata params) external view returns ( uint32 length, bool isExist) {
        address[] memory pools = pools[params.token0][params.token1];
        for (uint32 i = 0; i < pools.length; i++) {
            IPool pool = IPool(pools[i]);
            if (pool.fee() == params.fee && pool.tickUpper() == params.tickUpper && pool.tickLower() == params.tickLower) {
                return (i, true);
            }
        }
        return (0, false);
    }

    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable override returns (address pool) {
        // 需要找一下对应的 Pool index
        (uint32 index, bool isExist) = this.getPoolIndex(params);
        
        if (isExist) {
            pool = this.getPool(params.token0, params.token1, index);
            return pool;
        }

        // 如果没有对应的 Pool 就创建一个 Pool
        pool = this.createPool(params.token0, params.token1, params.tickLower, params.tickUpper, params.fee);

        if (index == 0) {
            pairs.push(Pair({
                token0: params.token0,
                token1: params.token1
            }));
        }
        
    }
}
