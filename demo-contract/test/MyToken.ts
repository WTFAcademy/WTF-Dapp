import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("MyToken", function () {
  async function deployFixture() {
    const token = await hre.viem.deployContract("MyToken");
    return {
      token,
    };
  }

  describe("ERC721", function () {
    describe("name", function () {
      it("Get NFT name", async function () {
        const { token } = await loadFixture(deployFixture);
        expect(await token.read.name()).to.equal("MyToken");
      });
    });
  });
});
