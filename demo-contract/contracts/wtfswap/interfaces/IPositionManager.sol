// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IPositionManager is IERC721 {
    struct PositionInfo {
        uint256 id;
        address owner;
        address token0;
        address token1;
        uint32 index;
        uint24 fee;
        uint128 liquidity;
        int24 tickLower;
        int24 tickUpper;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        // feeGrowthInside0LastX128 和 feeGrowthInside1LastX128 用于计算手续费
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
    }

    function getAllPositions()
        external
        view
        returns (PositionInfo[] memory positionInfo);

    struct MintParams {
        address token0;
        address token1;
        uint32 index;
        uint256 amount0Desired;
        uint256 amount1Desired;
        address recipient;
        uint256 deadline;
    }

    function mint(
        MintParams calldata params
    )
        external
        payable
        returns (
            uint256 positionId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    function burn(
        uint256 positionId
    ) external returns (uint256 amount0, uint256 amount1);

    function collect(
        uint256 positionId,
        address recipient
    ) external returns (uint256 amount0, uint256 amount1);

    function mintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}
