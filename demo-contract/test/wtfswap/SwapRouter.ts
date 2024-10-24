import { expect } from "chai";
import { viem } from "hardhat";
import hre from "hardhat";
import { encodeSqrtRatioX96, TickMath } from "@uniswap/v3-sdk";

describe("SwapRouter", function () {
  async function deployFixture() {
    // 部署两个测试代币
    const tokenA = await viem.deployContract("TestToken");
    const tokenB = await viem.deployContract("TestToken");

    // 部署一个 PoolManager 合约
    const poolManager = await viem.deployContract("PoolManager");

    // 初始化池子的价格上下限
    const tickLower = TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(1, 1));
    const tickUpper = TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(40000, 1));
    const sqrtPriceX96 = BigInt(encodeSqrtRatioX96(10000, 1).toString());

    // 建立池子，同样的 tokenA 和 tokenB，两种不同的费率
    await poolManager.write.createAndInitializePoolIfNecessary([
      {
        tokenA: tokenA.address,
        tokenB: tokenB.address,
        tickLower: tickLower,
        tickUpper: tickUpper,
        fee: 3000,
        sqrtPriceX96,
      },
    ]);

    await poolManager.write.createAndInitializePoolIfNecessary([
      {
        tokenA: tokenA.address,
        tokenB: tokenB.address,
        tickLower: tickLower,
        tickUpper: tickUpper,
        fee: 10000,
        sqrtPriceX96,
      },
    ]);

    // 拿到 PoolManager 合约的地址，部署 SwapRouter 合约
    const swapRouter = await viem.deployContract("SwapRouter", [
      poolManager.address,
    ]);

    // 注入流动性
    // 部署一个 LP 测试合约
    const testLP = await viem.deployContract("TestLP");
    // 给 testLP 发 token
    const initBalanceValue = 1000000000000n * 10n ** 18n;
    await tokenA.write.mint([testLP.address, initBalanceValue]);
    await tokenB.write.mint([testLP.address, initBalanceValue]);
    // 给池子1注入流动性
    // 获取池子1的地址
    const pool1Address = await poolManager.read.getPool([
      tokenA.address,
      tokenB.address,
      0,
    ]);
    // 给池子1注入流动性
    await tokenA.write.approve([pool1Address, initBalanceValue]);
    await tokenB.write.approve([pool1Address, initBalanceValue]);
    await testLP.write.mint([
      testLP.address,
      50000n * 10n ** 18n,
      pool1Address,
      tokenA.address,
      tokenB.address,
    ]);

    // 给池子2注入流动性
    // 获取池子2的地址
    const pool2Address = await poolManager.read.getPool([
      tokenA.address,
      tokenB.address,
      1,
    ]);
    // 给池子2注入流动性
    await tokenA.write.approve([pool2Address, initBalanceValue]);
    await tokenB.write.approve([pool2Address, initBalanceValue]);
    await testLP.write.mint([
      testLP.address,
      50000n * 10n ** 18n,
      pool2Address,
      tokenA.address,
      tokenB.address,
    ]);

    const [owner] = await hre.viem.getWalletClients();
    const [sender] = await owner.getAddresses();

    return {
      swapRouter,
      tokenA,
      tokenB,
      sender,
    };
  }

  it("exactInput", async function () {
    const { swapRouter, tokenA, tokenB, sender } = await deployFixture();

    await tokenA.write.mint([sender, 1000000000000n * 10n ** 18n]);
    await tokenA.write.approve([swapRouter.address, 10000n * 10n ** 18n]);

    await swapRouter.write.exactInput([
      {
        tokenIn: tokenA.address,
        tokenOut: tokenB.address,
        amountIn: 10n * 10n ** 18n,
        amountOutMinimum: 0n,
        indexPath: [0, 1],
        sqrtPriceLimitX96: BigInt(encodeSqrtRatioX96(200, 1).toString()),
        recipient: sender,
        deadline: BigInt(Math.floor(Date.now() / 1000) + 1000),
      },
    ]);

    // 检查收到的 tokenOut 数量
    const tokenBAmount = await tokenB.read.balanceOf([sender]);
    expect(tokenBAmount).to.equal(97760848089103280585132n); // 大概是 97760 * 10 ** 18，按照 10000 的价格
  });
});
