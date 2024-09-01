// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./interfaces/IFactory.sol";
import "./interfaces/IPool.sol";
import "./Pool.sol";

contract Factory is IFactory {
    struct PoolInfo {
        address tokenA;
        address tokenB;
        int24 tickLower;
        int24 tickUpper;
        uint24 fee;
    }

    mapping(address => mapping(address => address[])) public pools;

    PoolInfo public poolInfo;

    function parameters()
        public
        view
        override
        returns (address, address, address, int24, int24, uint24)
    {
        return (
            msg.sender,
            poolInfo.tokenA,
            poolInfo.tokenB,
            poolInfo.tickLower,
            poolInfo.tickUpper,
            poolInfo.fee
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

        // save pool info
        poolInfo = PoolInfo(tokenA, tokenB, tickLower, tickUpper, fee);

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
                delete poolInfo;
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

        delete poolInfo;

        return address(pool);
    }
}
