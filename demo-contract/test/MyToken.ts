import { describe, it } from "node:test";
import { expect } from "chai";
import { network } from "hardhat";

const { viem, networkHelpers } = await network.create();

describe("MyToken", function () {
  async function deployFixture() {
    const token = await viem.deployContract("MyToken");
    return {
      token,
    };
  }

  describe("ERC721", function () {
    describe("name", function () {
      it("Get NFT name", async function () {
        const { token } = await networkHelpers.loadFixture(deployFixture);
        expect(await token.read.name()).to.equal("MyToken");
      });
    });
  });
});
