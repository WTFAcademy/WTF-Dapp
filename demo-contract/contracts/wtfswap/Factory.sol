// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./interfaces/IFactory.sol";

contract Factory is IFactory {
    mapping(address => mapping(address => address[])) public pools;

    // parameters 是用于 Pool 创建时回调获取参数用
    // 不是用构造函数是为了避免构造函数变化，那样会导致 Pool 合约地址不能按照参数计算出来
    // 具体参考 https://docs.openzeppelin.com/cli/2.8/deploying-with-create2
    // new_address = hash(0xFF, sender, salt, bytecode)
    function parameters()
        external
        view
        override
        returns (
            address factory,
            address tokenA,
            address tokenB,
            int24 tickLower,
            int24 tickUpper,
            uint24 fee
        )
    {}

    function getPools(
        address tokenA,
        address tokenB
    ) external view override returns (address[] memory) {
        return pools[tokenA][tokenB];
    }

    function getPool(
        address tokenA,
        address tokenB,
        uint32 index
    ) external view override returns (address) {
        return pools[tokenA][tokenB][index];
    }

    function createPool(
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) external override returns (address pool) {
        // 先调用 getPools 获取当前 tokenA tokenB 的所有 pool
        // 然后判断是否已经存在 tickLower tickUpper fee 相同的 pool
        // 如果存在就直接返回
        // 如果不存在就创建一个新的 pool
        // 然后记录到 pools 中
    }
}
