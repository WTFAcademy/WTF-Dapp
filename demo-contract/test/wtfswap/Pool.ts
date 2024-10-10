import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { TickMath, encodeSqrtRatioX96 } from "@uniswap/v3-sdk";

describe("Pool", function () {
  async function deployFixture() {
    // 初始化一个池子，价格上限是 40000，下限是 1，初始化价格是 10000，费率是 0.3%
    const factory = await hre.viem.deployContract("Factory");
    const token0 = await hre.viem.deployContract("TestToken");
    const token1 = await hre.viem.deployContract("TestToken");
    const tickLower = TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(1, 1));
    const tickUpper = TickMath.getTickAtSqrtRatio(encodeSqrtRatioX96(40000, 1));
    // 以 1,000,000 为基底的手续费费率，Uniswap v3 前端界面支持四种手续费费率（0.01%，0.05%、0.30%、1.00%），对于一般的交易对推荐 0.30%，fee 取值即 3000；
    const fee = 3000;
    const publicClient = await hre.viem.getPublicClient();
    await factory.write.createPool([
      token0.address,
      token1.address,
      tickLower,
      tickUpper,
      fee,
    ]);
    const createEvents = await factory.getEvents.PoolCreated();
    const poolAddress: `0x${string}` = createEvents[0].args.pool || "0x";
    const pool = await hre.viem.getContractAt("Pool" as string, poolAddress);

    // 计算一个初始化的价格，按照 1 个 token0 换 10000 个 token1 来算，其实就是 10000
    const sqrtPriceX96 = encodeSqrtRatioX96(10000, 1);
    await pool.write.initialize([sqrtPriceX96]);

    return {
      token0,
      token1,
      factory,
      pool,
      publicClient,
      tickLower,
      tickUpper,
      fee,
      sqrtPriceX96: BigInt(sqrtPriceX96.toString()),
    };
  }

  it("pool info", async function () {
    const { pool, token0, token1, tickLower, tickUpper, fee, sqrtPriceX96 } =
      await loadFixture(deployFixture);

    expect(((await pool.read.token0()) as string).toLocaleLowerCase()).to.equal(
      token0.address
    );
    expect(((await pool.read.token1()) as string).toLocaleLowerCase()).to.equal(
      token1.address
    );
    expect(await pool.read.tickLower()).to.equal(tickLower);
    expect(await pool.read.tickUpper()).to.equal(tickUpper);
    expect(await pool.read.fee()).to.equal(fee);
    expect(await pool.read.sqrtPriceX96()).to.equal(sqrtPriceX96);
  });

  it("mint and burn and collect", async function () {
    const { pool, token0, token1 } = await loadFixture(deployFixture);
    const testLP = await hre.viem.deployContract("TestLP");

    const initBalanceValue = 1000n * 10n ** 18n;
    await token0.write.mint([testLP.address, initBalanceValue]);
    await token1.write.mint([testLP.address, initBalanceValue]);

    // mint 20000000 份流动性
    await testLP.write.mint([
      testLP.address,
      20000000n,
      pool.address,
      token0.address,
      token1.address,
    ]);

    expect(await token0.read.balanceOf([pool.address])).to.equal(
      initBalanceValue - (await token0.read.balanceOf([testLP.address]))
    );
    expect(await token1.read.balanceOf([pool.address])).to.equal(
      initBalanceValue - (await token1.read.balanceOf([testLP.address]))
    );

    const position = await pool.read.positions([testLP.address]);
    expect(position).to.deep.equal([20000000n, 0n, 0n, 0n, 0n]);
    expect(await pool.read.liquidity()).to.equal(20000000n);

    // 继续 mint 50000
    await testLP.write.mint([
      testLP.address,
      50000n,
      pool.address,
      token0.address,
      token1.address,
    ]);
    expect(await pool.read.liquidity()).to.equal(20050000n);
    expect(await token0.read.balanceOf([pool.address])).to.equal(
      initBalanceValue - (await token0.read.balanceOf([testLP.address]))
    );
    expect(await token1.read.balanceOf([pool.address])).to.equal(
      initBalanceValue - (await token1.read.balanceOf([testLP.address]))
    );

    // burn 10000
    await testLP.write.burn([10000n, pool.address]);
    expect(await pool.read.liquidity()).to.equal(20040000n);

    // create new LP
    const testLP2 = await hre.viem.deployContract("TestLP");
    await token0.write.mint([testLP2.address, initBalanceValue]);
    await token1.write.mint([testLP2.address, initBalanceValue]);
    await testLP2.write.mint([
      testLP2.address,
      3000n,
      pool.address,
      token0.address,
      token1.address,
    ]);
    expect(await pool.read.liquidity()).to.equal(20043000n);

    const totalToken0 =
      initBalanceValue -
      (await token0.read.balanceOf([testLP.address])) +
      (initBalanceValue - (await token0.read.balanceOf([testLP2.address])));
    // 判断池子里面的 token0 是否等于 LP1 和 LP2 减少的 token0 之和
    expect(await token0.read.balanceOf([pool.address])).to.equal(totalToken0);

    // burn all liquidity for LP
    await testLP.write.burn([20040000n, pool.address]);
    expect(await pool.read.liquidity()).to.equal(3000n);

    // 判断池子里面的 token0 是否等于 LP1 和 LP2 减少的 token0 之和，burn 只是把流动性返回给 LP，不会把 token 返回给 LP
    expect(await token0.read.balanceOf([pool.address])).to.equal(totalToken0);
    // collect, all balance return to testLP
    await testLP.write.collect([testLP.address, pool.address]);

    // 因为取整的原因，提取流动性之后获得的 token 可能会比之前少一点
    expect(
      Number(initBalanceValue - (await token0.read.balanceOf([testLP.address])))
    ).to.lessThan(10);
    expect(
      Number(initBalanceValue - (await token1.read.balanceOf([testLP.address])))
    ).to.lessThan(10);
  });

  it("swap", async function () {
    const { pool, token0, token1, sqrtPriceX96 } = await loadFixture(
      deployFixture
    );
    const testLP = await hre.viem.deployContract("TestLP");

    const initBalanceValue = 100000000000n * 10n ** 18n;
    await token0.write.mint([testLP.address, initBalanceValue]);
    await token1.write.mint([testLP.address, initBalanceValue]);

    // mint 多一些流动性
    await testLP.write.mint([
      testLP.address,
      100000000000000000000000000n,
      pool.address,
      token0.address,
      token1.address,
    ]);

    // 通过 TestSwap 合约交易
    const testSwap = await hre.viem.deployContract("TestSwap");
    const minPrice = 1000;
    const minSqrtPriceX96: bigint = BigInt(
      encodeSqrtRatioX96(minPrice, 1).toString()
    );

    // 给 testSwap 合约中打入 token0 用于交易
    await token0.write.mint([testSwap.address, 300n * 10n ** 18n]);

    expect(await token0.read.balanceOf([testSwap.address])).to.equal(
      300n * 10n ** 18n
    );
    expect(await token1.read.balanceOf([testSwap.address])).to.equal(0n);
    await testSwap.write.testSwap([
      testSwap.address,
      minSqrtPriceX96,
      100000n * 10n ** 18n,
      pool.address,
      token0.address,
      token1.address,
    ]);
    expect(await token1.read.balanceOf([testSwap.address])).not.to.equal(0n);
  });
});
