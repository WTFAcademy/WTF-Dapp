import { encodeSqrtRatioX96 } from "@uniswap/v3-sdk";
import type { Token } from "@ant-design/web3";
import { Hardhat, Sepolia } from "@ant-design/web3-wagmi";
import { TickMath } from "@uniswap/v3-sdk";
import { maxBy, minBy } from "lodash-es";

export const parsePriceToSqrtPriceX96 = (price: number): BigInt => {
  return BigInt(encodeSqrtRatioX96(price * 1000000, 1000000).toString());
};

export const getContractAddress = (
  contract:
    | "PoolManager"
    | "PositionManager"
    | "SwapRouter"
    | "DebugTokenA"
    | "DebugTokenB"
    | "DebugTokenC"
): `0x${string}` => {
  const isProd = process.env.NODE_ENV === "production";
  if (contract === "PoolManager") {
    return isProd
      ? "0xF35DE8597A617cfA23de794BCBB4c2f8fc9bC896"
      : "0x5FbDB2315678afecb367f032d93F642f64180aa3";
  }
  if (contract === "PositionManager") {
    return isProd
      ? "0x59ebEa058E193B64f0E091220d5Db98288EFec57"
      : "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
  }
  if (contract === "SwapRouter") {
    return isProd
      ? "0xA8b9Fa84A4Df935e768d3cC211E3d679027d0B31"
      : "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";
  }
  if (contract === "DebugTokenA") {
    return isProd
      ? "0x5AAB2806D12E380c24C640a8Cd94906d7fA59b16"
      : "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9";
  }
  if (contract === "DebugTokenB") {
    return isProd
      ? "0x00E6EC12a0Fc35d7064cD0d551Ac74A02bA8a5A5"
      : "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9";
  }
  if (contract === "DebugTokenC") {
    return isProd
      ? "0x1D46AD43cc80BFb66C1D574d2B0E4abab191d1E0"
      : "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707";
  }
  throw new Error("Invalid contract");
};

const builtInTokens: Record<string, Token> = {
  "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9": {
    icon: null,
    symbol: "DTA",
    decimal: 18,
    name: "DebugTokenA",
    availableChains: [
      {
        chain: Hardhat,
        contract: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
      },
    ],
  },
  "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9": {
    icon: null,
    symbol: "DTB",
    decimal: 18,
    name: "DebugTokenB",
    availableChains: [
      {
        chain: Hardhat,
        contract: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
      },
    ],
  },
  "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707": {
    icon: null,
    symbol: "DTC",
    decimal: 18,
    name: "DebugTokenC",
    availableChains: [
      {
        chain: Hardhat,
        contract: "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",
      },
    ],
  },
  "0x5AAB2806D12E380c24C640a8Cd94906d7fA59b16": {
    icon: null,
    symbol: "DTA",
    decimal: 18,
    name: "DebugTokenA",
    availableChains: [
      {
        chain: Sepolia,
        contract: "0x5AAB2806D12E380c24C640a8Cd94906d7fA59b16",
      },
    ],
  },
  "0x00E6EC12a0Fc35d7064cD0d551Ac74A02bA8a5A5": {
    icon: null,
    symbol: "DTB",
    decimal: 18,
    name: "DebugTokenB",
    availableChains: [
      {
        chain: Sepolia,
        contract: "0x00E6EC12a0Fc35d7064cD0d551Ac74A02bA8a5A5",
      },
    ],
  },
  "0x1D46AD43cc80BFb66C1D574d2B0E4abab191d1E0": {
    icon: null,
    symbol: "DTC",
    decimal: 18,
    name: "DebugTokenC",
    availableChains: [
      {
        chain: Sepolia,
        contract: "0x1D46AD43cc80BFb66C1D574d2B0E4abab191d1E0",
      },
    ],
  },
};

export const getTokenInfo = (address: string): Token => {
  if (builtInTokens[address]) {
    return builtInTokens[address];
  }
  return {
    icon: null,
    symbol: address.slice(-3).toUpperCase(),
    decimal: 18,
    name: address,
    availableChains: [
      {
        chain: Hardhat,
        contract: address,
      },
      {
        chain: Sepolia,
        contract: address,
      },
    ],
  };
};

// 把数字转化为大整数，支持 4 位小数
export const parseAmountToBigInt = (amount: number, token?: Token): bigint => {
  return (
    BigInt(Math.floor(amount * 10000)) *
    BigInt(10 ** ((token?.decimal || 18) - 4))
  );
};

// 把大整数转化为数字，支持 4 位小数
export const parseBigIntToAmount = (amount: bigint, token?: Token): number => {
  return (
    Number((amount / BigInt(10 ** ((token?.decimal || 18) - 4))).toString()) /
    10000
  );
};

export const computeSqrtPriceLimitX96 = (
  pools: {
    pool: `0x${string}`;
    token0: `0x${string}`;
    token1: `0x${string}`;
    index: number;
    fee: number;
    feeProtocol: number;
    tickLower: number;
    tickUpper: number;
    tick: number;
    sqrtPriceX96: bigint;
  }[],
  zeroForOne: boolean
): bigint => {
  if (zeroForOne) {
    // 如果是 token0 交换 token1，那么交易完成后价格 token0 变多，价格下降下限
    // 先找到交易池的最小 tick
    const minTick =
      minBy(pools, (pool) => pool.tick)?.tick ?? TickMath.MIN_TICK;
    // 价格限制为最小 tick - 10000，避免价格过低，在实际项目中应该按照用户设置的滑点来调整
    const limitTick = Math.max(minTick - 10000, TickMath.MIN_TICK);
    return BigInt(TickMath.getSqrtRatioAtTick(limitTick).toString());
  } else {
    // 反之，设置一个最大的价格
    // 先找到交易池的最大 tick
    const maxTick =
      maxBy(pools, (pool) => pool.tick)?.tick ?? TickMath.MAX_TICK;
    // 价格限制为最大 tick + 10000，避免价格过高，在实际项目中应该按照用户设置的滑点来调整
    const limitTick = Math.min(maxTick + 10000, TickMath.MAX_TICK);
    return BigInt(TickMath.getSqrtRatioAtTick(limitTick).toString());
  }
};
