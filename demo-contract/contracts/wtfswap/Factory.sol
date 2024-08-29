// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./interfaces/IFactory.sol";
import "./interfaces/IPool.sol";
import "./Pool.sol";

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
            address token0,
            address token1,
            int24 tickLower,
            int24 tickUpper,
            uint24 fee
        )
    {
        IPool pool = IPool(msg.sender);

        return (
            address(this),
            pool.token0(),
            pool.token1(),
            pool.tickLower(),
            pool.tickUpper(),
            pool.fee()
        );
    }

    function sortToken(
        address tokenA,
        address tokenB
    ) private pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function getPool(
        address tokenA,
        address tokenB,
        uint32 index
    ) external view override returns (address) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");

        // Declare token0 and token1
        address token0;
        address token1;

        (token0, token1) = sortToken(tokenA, tokenB);

        return pools[tokenA][tokenB][index];
    }

    function createPool(
        address tokenA,
        address tokenB,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) external override returns (address pool) {
        // validate token's individuality
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");

        // Declare token0 and token1
        address token0;
        address token1;

        // sort token, avoid the mistake of the order
        (token0, token1) = sortToken(tokenA, tokenB);

        // get current all pools
        address[] memory existingPools = pools[token0][token1];

        // check if the pool already exists
        for (uint256 i = 0; i < existingPools.length; i++) {
            IPool currentPool = IPool(existingPools[i]);

            if (
                currentPool.tickLower() == tickLower &&
                currentPool.tickUpper() == tickUpper &&
                currentPool.fee() == fee
            ) {
                return existingPools[i];
            }
        }

        // generate create2 salt
        bytes32 salt = keccak256(
            abi.encodePacked(token0, token1, tickLower, tickUpper, fee)
        );

        // create pool
        address poolAddress = address(new Pool{salt: salt}());

        // save pool
        pools[token0][token1].push(poolAddress);

        return address(pool);
    }
}
