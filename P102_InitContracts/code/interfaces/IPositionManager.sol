// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

interface IPositionManager {
    function getPositions(
        address owner
    ) external view returns (uint256[] memory positionIds);

    struct PositionInfo {
        // address owner;
        address token0;
        address token1;
        uint24 fee;
        int128 liquidity;
        // tick range
        int24 tickLower;
        int24 tickUpper;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
    }

    function getPositionInfo(
        uint256 positionId
    ) external view returns (PositionInfo memory positionInfo);

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
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
}
