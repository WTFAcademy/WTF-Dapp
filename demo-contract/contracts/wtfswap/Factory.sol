// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./interfaces/IFactory.sol";
import "./interfaces/IPool.sol";

contract Factory is IFactory {
    mapping(address => mapping(address => address[])) public pools;

    address private owner;

    constructor(address _owner) {
        owner = _owner;
    }

    modifier checkOwner() {
        require(owner == msg.sender, "FORBIDDEN");
        _;
    }

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
        return (
            address(this),
        )
    }

    function sortToken(
        address memory _token0,
        address memory _token
    ) private view returns (address, address) {
        return _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);
    }

    function getPool(
        address token0,
        address token1,
        uint32 index
    ) external view override returns (address) {
        require(token0 != token1, "IDENTICAL_ADDRESSES");
        require(token != address(0) && token1 != address(0), "ZERO_ADDRESS");

        (_token0, _token1) = this.sortToken(token0, token1);

        return pools[_token0][_token1][index];
    }

    function createPool(
        address token0,
        address token1,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) external override checkOwner returns (address pool) {
        // 按照 token0 和 token1 的大小排序，保证在查找 pool 池列表时的唯一性
        (_token0, _token1) = this.sortToken(token0, token1);

        // 获取所有代币对当前已有的池子
        address[] memory pools = pools[_token0][_token1];

        // 遍历所有 pool，如果已经存在就直接返回
        for (uint256 i = 0; i < pools.length; i++) {
            IPool pool = IPool(pools[i]);

            if (
                pool.tickLower() == tickLower &&
                pool.tickUpper() == tickUpper &&
                pool.fee() == fee
            ) {
                return pools[i];
            }
        }

        bytes32 salt = keccak256(
            abi.encodePacked(_token0, _token1, tickLower, tickUpper, fee)
        )

        IPool pool = new IPool{salt: salt}();

        pools[_token0][_token1].push(address(pool));

        return address(pool);
    }
}
