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
    const tokenA: `0x${string}` = "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984";
    const tokenB: `0x${string}` = "0xEcd0D12E21805803f70de03B72B1C162dB0898d9";
    const tokenC: `0x${string}` = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599";
    const tokenD: `0x${string}` = "0x6B175474E89094C44Da98b954EedeAC495271d0F";

    // 创建 tokenA-tokenB
    await manager.write.createAndInitializePoolIfNecessary([
      {
        token0: tokenA,
        token1: tokenB,
        fee: 3000,
        tickLower: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(1, 1)),
        tickUpper: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(10000, 1)),
        sqrtPriceX96: BigInt(encodeSqrtRatioX96(100, 1).toString()),
      },
    ]);

    // 由于和前一个参数一样，会被合并
    await manager.write.createAndInitializePoolIfNecessary([
      {
        token0: tokenA,
        token1: tokenB,
        fee: 3000,
        tickLower: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(1, 1)),
        tickUpper: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(10000, 1)),
        sqrtPriceX96: BigInt(encodeSqrtRatioX96(100, 1).toString()),
      },
    ]);

    await manager.write.createAndInitializePoolIfNecessary([
      {
        token0: tokenC,
        token1: tokenD,
        fee: 2000,
        tickLower: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(100, 1)),
        tickUpper: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(5000, 1)),
        sqrtPriceX96: BigInt(encodeSqrtRatioX96(200, 1).toString()),
      },
    ]);

    // 判断返回的 pairs 的数量是否正确
    const pairs = await manager.read.getPairs();
    expect(pairs.length).to.equal(2);

    // 判断返回的 pools 的数量、参数是否正确
    const pools = await manager.read.getAllPools();
    expect(pools.length).to.equal(2);
    expect(pools[0].token0).to.equal(tokenA);
    expect(pools[0].token1).to.equal(tokenB);
    expect(pools[0].sqrtPriceX96).to.equal(
      BigInt(encodeSqrtRatioX96(100, 1).toString())
    );
    expect(pools[1].token0).to.equal(tokenC);
    expect(pools[1].token1).to.equal(tokenD);
    expect(pools[1].sqrtPriceX96).to.equal(
      BigInt(encodeSqrtRatioX96(200, 1).toString())
    );
  });

  it("require token0 < token1", async function () {
    const { manager } = await loadFixture(deployFixture);
    const tokenA: `0x${string}` = "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984";
    const tokenB: `0x${string}` = "0xEcd0D12E21805803f70de03B72B1C162dB0898d9";

    await expect(
      manager.write.createAndInitializePoolIfNecessary([
        {
          token0: tokenB,
          token1: tokenA,
          fee: 3000,
          tickLower: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(1, 1)),
          tickUpper: TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(10000, 1)),
          sqrtPriceX96: BigInt(encodeSqrtRatioX96(100, 1).toString()),
        },
      ])
    ).to.be.rejected;
  });
});
