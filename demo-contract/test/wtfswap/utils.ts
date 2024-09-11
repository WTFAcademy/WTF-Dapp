import BigNumber from "bignumber.js";

// Uniswap V3 引入了一种新的价格表示方法，即 sqrtPriceX96。它表示的实际上是价格的平方根乘以一个大的常数（即2的96次方），而不是价格本身。这种表示方法带来了几个方便的优点。
// 先让我们理解一下这个概念。sqrtPriceX96 的 "sqrt" 是指 "square root"，也就是平方根；"X96" 是指结果被左移（或乘）了 96 位。因此，如果你有一个价格（即 token0 价格对 token1），你可以通过取其平方根，然后把结果左移 96 位来得到 sqrtPriceX96。
// 这样做的目的主要是为了方便在 solidity 合约中的计算，特别是在处理价格变动时。由于 solidity 不支持浮点数操作，因此开发者需要采取一些策略来模拟浮点数运算，其中一个常见的策略就是使用固定点数。这里，开发者选择把价格的平方根乘以 2 的 96 次方，这就意味着价格的平方根被表示成了一个非常大的整数。
export const getSqrtPriceX96 = (price: number): bigint => {
  // Uniswap uses a price calculation with 2^96 precision
  const SCALAR = new BigNumber(2).exponentiatedBy(96);

  // Set the decimal precision to a large number to handle the large numbers involved
  BigNumber.config({ DECIMAL_PLACES: 100 });

  // Define the price
  const PRICE = new BigNumber(price);

  // Calculate the square root
  const SQRT_PRICE = PRICE.sqrt();

  // Multiply by the scalar and round down to get an integer result
  const SQRT_PRICE_X96 = SQRT_PRICE.multipliedBy(SCALAR).integerValue(
    BigNumber.ROUND_DOWN
  );

  return BigInt(SQRT_PRICE_X96.toFixed());
};
