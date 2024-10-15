import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { TickMath, encodeSqrtRatioX96 } from "@uniswap/v3-sdk";

describe("PoolManager", function () {
  async function deployFixture() {
    const manager = await hre.viem.deployContract("PoolManager");
    const publicClient = await hre.viem.getPublicClient();
    return {
      manager,
      publicClient,
    };
  }

  it("getPairs & getAllPools", async function () {
    const { manager } = await loadFixture(deployFixture);
    const tokenA: `0x${string}` = "0xEcd0D12E21805803f70de03B72B1C162dB0898d9";
    const tokenB: `0x${string}` = "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984";
    const tokenC: `0x${string}` = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599";
    const tokenD: `0x${string}` = "0x6B175474E89094C44Da98b954EedeAC495271d0F";

    await manager.write.createAndInitializePoolIfNecessary([
      {
        tokenA: tokenA,
        tokenB: tokenB,
        fee: 3000,
        tickLower: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(1, 1)),
        tickUpper: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(10000, 1)),
        sqrtPriceX96: BigInt(encodeSqrtRatioX96(100, 1).toString()),
      },
    ]);

    await manager.write.createAndInitializePoolIfNecessary([
      {
        tokenA: tokenB,
        tokenB: tokenA,
        fee: 3000,
        tickLower: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(1, 1)),
        tickUpper: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(10000, 1)),
        sqrtPriceX96: BigInt(encodeSqrtRatioX96(100, 1).toString()),
      },
    ]);

    await manager.write.createAndInitializePoolIfNecessary([
      {
        tokenA: tokenC,
        tokenB: tokenD,
        fee: 2000,
        tickLower: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(100, 1)),
        tickUpper: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(5000, 1)),
        sqrtPriceX96: BigInt(encodeSqrtRatioX96(200, 1).toString()),
      },
    ]);

    const pairs = await manager.read.getPairs();
    expect(pairs.length).to.equal(2);

    const pools = await manager.read.getAllPools();
    expect(pools.length).to.equal(2);
    expect(pools[0].token0).to.equal(tokenB);
    expect(pools[0].token1).to.equal(tokenA);
    expect(pools[0].sqrtPriceX96).to.equal(
      BigInt(encodeSqrtRatioX96(100, 1).toString())
    );
    expect(pools[1].token0).to.equal(tokenC);
    expect(pools[1].token1).to.equal(tokenD);
    expect(pools[1].sqrtPriceX96).to.equal(
      BigInt(encodeSqrtRatioX96(200, 1).toString())
    );
  });
});
