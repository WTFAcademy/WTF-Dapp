import { expect } from 'chai';
import { viem } from 'hardhat';
import { Contract, Signer } from 'ethers';
import { encodeSqrtRatioX96, TickMath } from '@uniswap/v3-sdk';

describe('SwapRouter', function () {
  async function deployFixture() {
    // 部署两个测试代币
    const tokenA = await viem.deployContract('TestToken');
    const tokenB = await viem.deployContract('TestToken');

    // 部署一个 PoolManager 合约
    const poolManager = await viem.deployContract('PoolManager');

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
    const swapRouter = await viem.deployContract('SwapRouter', [
      poolManager.address,
    ]);

    return {
      swapRouter,
      tokenA,
      tokenB,
    };
  }

  it('exactInput 测试', async function () {
    const { swapRouter, tokenA, tokenB } = await deployFixture();
  });
});
