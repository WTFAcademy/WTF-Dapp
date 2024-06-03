// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
pragma abicoder v2;

import "./interfaces/IPositionManager.sol";

contract PositionManager is IPositionManager {
    function getPositions(
        address owner
    ) external view override returns (uint256[] memory positionIds) {}

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
    {}

    function burn(
        uint256 positionId
    ) external override returns (uint256 amount0, uint256 amount1) {}

    function collect(
        uint256 positionId,
        address recipient
    ) external override returns (uint256 amount0, uint256 amount1) {}
}
