import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("Factory", function () {
  async function deployFixture() {
    const factory = await hre.viem.deployContract("Factory");
    const publicClient = await hre.viem.getPublicClient();
    return {
      factory,
      publicClient,
    };
  }

  it("createPool", async function () {
    const { factory, publicClient } = await loadFixture(deployFixture);
    const tokenA: `0x${string}` = "0xEcd0D12E21805803f70de03B72B1C162dB0898d9";
    const tokenB: `0x${string}` = "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984";

    const hash = await factory.write.createPool([
      tokenA,
      tokenB,
      1,
      100000,
      3000,
    ]);
    await publicClient.waitForTransactionReceipt({ hash });
    const createEvents = await factory.getEvents.PoolCreated();
    expect(createEvents).to.have.lengthOf(1);
    expect(createEvents[0].args.pool).to.match(/^0x[a-fA-F0-9]{40}$/);
    expect(createEvents[0].args.token0).to.equal(tokenB);
    expect(createEvents[0].args.token1).to.equal(tokenA);
    expect(createEvents[0].args.tickLower).to.equal(1);
    expect(createEvents[0].args.tickUpper).to.equal(100000);
    expect(createEvents[0].args.fee).to.equal(3000);

    // simulate for test return address
    const poolAddress = await factory.simulate.createPool([
      tokenA,
      tokenB,
      1,
      100000,
      3000,
    ]);
    expect(poolAddress.result).to.match(/^0x[a-fA-F0-9]{40}$/);
    expect(poolAddress.result).to.equal(createEvents[0].args.pool);
  });

  it("createPool with same token", async function () {
    const { factory } = await loadFixture(deployFixture);
    const tokenA: `0x${string}` = "0xEcd0D12E21805803f70de03B72B1C162dB0898d9";
    const tokenB: `0x${string}` = "0xEcd0D12E21805803f70de03B72B1C162dB0898d9";
    await expect(
      factory.write.createPool([tokenA, tokenB, 1, 100000, 3000])
    ).to.be.rejectedWith("IDENTICAL_ADDRESSES");

    await expect(factory.read.getPool([tokenA, tokenB, 3])).to.be.rejectedWith(
      "IDENTICAL_ADDRESSES"
    );
  });
});
