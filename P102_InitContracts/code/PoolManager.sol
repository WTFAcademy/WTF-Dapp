// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./interfaces/IPoolManager.sol";
import "./Factory.sol";

contract PoolManager is Factory, IPoolManager {
    Pair[] public pairs;

    function getPairs() external view override returns (Pair[] memory) {
        // 返回有哪些交易对，DApp 和 getAllPools 会用到
        return pairs;
    }

    function getAllPools()
        external
        view
        override
        returns (PoolInfo[] memory poolsInfo)
    {
        // 遍历 pairs，获取当前有的所有的交易对
        // 然后调用 Factory 的 getPools 获取每个交易对的所有 pool
        // 然后获取每个 pool 的信息
        // 然后返回
        // 先 mock
        poolsInfo = new PoolInfo[](pairs.length);
        return poolsInfo;
    }

    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable override returns (address pool) {
        // 如果没有对应的 Pool 就创建一个 Pool
        // 创建成功后记录到 pairs 中
    }
}
