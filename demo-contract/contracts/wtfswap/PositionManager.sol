// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./interfaces/IPositionManager.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolManager.sol";

contract PositionManager is IPositionManager, ERC721 {
    // 保存 PoolManager 合约地址
    IPoolManager public poolManager;

    constructor(address _poolManger) ERC721("WTFSwapPosition", "WTFP") {
        poolManager = IPoolManager(_poolManger);
    }

    // 用一个 mapping 来存放所有 Position 的信息
    mapping(uint256 => PositionInfo) public positions;

    // 通过 positionId 获取 Position 信息，positionId 就是 NFT 的 tokenId
    // 如果要获得某个用户的所有的 Position 信息，需要自己遍历所有的 tokenId，可以通过 ZAN 的节点服务来获取
    function getPositionInfo(
        uint256 positionId
    ) external view override returns (PositionInfo memory positionInfo) {}

    function mint(
        MintParams calldata params
    )
        external
        payable
        override
        returns (
            uint256 positionId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // mint 一个 NFT 作为 position 发给 LP
        // NFT 的 tokenId 就是 positionId
        // 通过 MintParams 里面的 token0 和 token1 以及 index 获取对应的 Pool
        // 调用 poolManager 的 getPool 方法获取 Pool 地址
        address _pool = poolManager.getPool(
            params.token0,
            params.token1,
            params.index
        );
        IPool pool = IPool(_pool);
        // 通过获取 pool 相关信息，结合 params.amount0Desired 和 params.amount1Desired 计算这次要注入的流动性
        // TODO: 计算 _liquidity，这里只是随便写的
        uint128 _liquidity = uint128(
            params.amount0Desired * params.amount1Desired
        );
        // data 是 mint 后回调 PositionManager 会额外带的数据
        // 需要 PoistionManger 实现回调，在回调中给 Pool 打钱
        bytes memory data = abi.encode("todo");
        (amount0, amount1) = pool.mint(params.recipient, _liquidity, data);
        positionId = 1;
        liquidity = _liquidity;
        // TODO 以 NFT 的形式把 Position 的所有权发给 LP
    }

    function burn(
        uint256 positionId
    ) external override returns (uint256 amount0, uint256 amount1) {
        // TODO 检查 positionId 是否属于 msg.sender
        // 移除流动性，但是 token 还是保留在 pool 中，需要再调用 collect 方法才能取回 token
        // 通过 positionId 获取对应 LP 的流动性
        uint128 _liquidity = positions[positionId].liquidity;
        // 调用 Pool 的方法给 LP 退流动性
        address _pool = poolManager.getPool(
            positions[positionId].token0,
            positions[positionId].token1,
            positions[positionId].index
        );
        IPool pool = IPool(_pool);
        (amount0, amount1) = pool.burn(_liquidity);
        // 修改 positionInfo 中的信息
        positions[positionId].liquidity = 0;
        positions[positionId].tokensOwed0 = amount0;
        positions[positionId].tokensOwed1 = amount1;
    }

    function collect(
        uint256 positionId,
        address recipient
    ) external override returns (uint256 amount0, uint256 amount1) {
        // TODO 检查 positionId 是否属于 msg.sender
        // 调用 Pool 的方法给 LP 退流动性
        address _pool = poolManager.getPool(
            positions[positionId].token0,
            positions[positionId].token1,
            positions[positionId].index
        );
        IPool pool = IPool(_pool);
        (amount0, amount1) = pool.collect(recipient);
        // 修改 positionInfo 中的信息
        positions[positionId].tokensOwed0 = 0;
        positions[positionId].tokensOwed1 = 0;
    }

    function mintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        // 在这里给 Pool 打钱，需要用户先 approve 足够的金额，这里才会成功
    }
}
