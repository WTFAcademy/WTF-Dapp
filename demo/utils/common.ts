import { encodeSqrtRatioX96 } from "@uniswap/v3-sdk";

export const parsePriceToSqrtPriceX96 = (price: number): BigInt => {
  return BigInt(encodeSqrtRatioX96(price * 1000000, 1000000).toString());
};
