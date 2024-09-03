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

    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable override returns (address pool) {
        uint256 index = pools[params.token0][params.token1].length;
        pool = this.createPool(params.token0, params.token1, params.tickLower, params.tickUpper, params.fee);

        if (index == 0) {
            // 如果是新增，还需要初始化价格
            IPool(pool).initialize(params.sqrtPriceX96);
            pairs.push(Pair({
                token0: params.token0,
                token1: params.token1
            }));
        }
        
    }
}
