import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { getSqrtPriceX96 } from './utils';

describe("Pool", function () {
  async function deployFixture() {
    const factory = await hre.viem.deployContract("Factory");
    const token0 = await hre.viem.deployContract("TestToken");
    const token1 = await hre.viem.deployContract("TestToken");
    const tickLower = -100000;
    const tickUpper = 100000;
    const fee = 3000;
    const publicClient = await hre.viem.getPublicClient();
    await factory.write.createPool([token0.address, token1.address, tickLower, tickUpper, fee]);
    const createEvents = await factory.getEvents.PoolCreated();
    const poolAddress: `0x${string}` = createEvents[0].args.pool || "0x";
    const pool = await hre.viem.getContractAt("Pool" as string, poolAddress);

    const price = 2000;
    const sqrtPriceX96: bigint = getSqrtPriceX96(price); // => 3961408125713216879677197516800n

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
      sqrtPriceX96,
      price,
    };
  }

  it("pool info", async function () {
    const { pool, token0, token1, tickLower, tickUpper, fee, sqrtPriceX96 } =
      await loadFixture(deployFixture);

    expect((await pool.read.token0() as string).toLocaleLowerCase()).to.equal(token0.address);
    expect((await pool.read.token1() as string).toLocaleLowerCase()).to.equal(token1.address);
    expect(await pool.read.tickLower()).to.equal(tickLower);
    expect(await pool.read.tickUpper()).to.equal(tickUpper);
    expect(await pool.read.fee()).to.equal(fee);
    expect(await pool.read.sqrtPriceX96()).to.equal(sqrtPriceX96);
  });

  it("mint and burn and collect", async function () {
    const { pool, token0, token1, price } = await loadFixture(deployFixture);
    const testLP = await hre.viem.deployContract("TestLP");

    const initBalanceValue = 1000n * 10n ** 18n;
    await token0.write.mint([testLP.address, initBalanceValue]);
    await token1.write.mint([testLP.address, initBalanceValue]);

    // mint 20000000 份流动性
    console.log('sqrtPriceX96', await pool.read.sqrtPriceX96());
    const data = await testLP.simulate.mint([testLP.address, 20000000n, pool.address, token0.address, token1.address]);
    console.log('mint amount', data.result);


    await testLP.write.mint([testLP.address, 20000000n, pool.address, token0.address, token1.address]);

    expect(await token0.read.balanceOf([pool.address])).to.equal(initBalanceValue - await token0.read.balanceOf([testLP.address]));
    expect(await token1.read.balanceOf([pool.address])).to.equal(initBalanceValue - await token1.read.balanceOf([testLP.address]));

    const position = await pool.read.positions([testLP.address]);
    expect(position).to.deep.equal([ 20000000n, 0n, 0n ]);
    expect(await pool.read.liquidity()).to.equal(20000000n);

    // 继续 mint 50000
    await testLP.write.mint([testLP.address, 50000n, pool.address, token0.address, token1.address]);
    expect(await pool.read.liquidity()).to.equal(20050000n);
    expect(await token0.read.balanceOf([pool.address])).to.equal(initBalanceValue - await token0.read.balanceOf([testLP.address]));
    expect(await token1.read.balanceOf([pool.address])).to.equal(initBalanceValue - await token1.read.balanceOf([testLP.address]));

    // burn 10000
    await testLP.write.burn([10000n, pool.address]);
    expect(await pool.read.liquidity()).to.equal(20040000n);

    // create new LP
    const testLP2 = await hre.viem.deployContract("TestLP");
    await token0.write.mint([testLP2.address, initBalanceValue]);
    await token1.write.mint([testLP2.address, initBalanceValue]);
    await testLP2.write.mint([testLP2.address, 3000n, pool.address, token0.address, token1.address]);
    expect(await pool.read.liquidity()).to.equal(20043000n);

    const totalToken0 = (initBalanceValue - await token0.read.balanceOf([testLP.address])) + (initBalanceValue - await token0.read.balanceOf([testLP2.address]));
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
    expect(Number(initBalanceValue - await token0.read.balanceOf([testLP.address]))).to.lessThan(10)
    expect(Number(initBalanceValue - await token1.read.balanceOf([testLP.address]))).to.lessThan(10)
  });
});
