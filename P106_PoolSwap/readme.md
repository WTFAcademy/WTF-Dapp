本节作者：[@愚指导](https://x.com/yudao1024)

这一讲将会实现 `Pool` 合约中的 `swap` 交易方法。

---

## 合约简介

在上一讲中，我们实现了 `Pool` 合约的流动性添加和管理的相关方法，流动性添加本质上就是 LP 将代币注入到 `Pool` 合约中，这样用户就可以利用 LP 注入的代币来进行交易了。比如我们设置了初始化的价格为 10000，LP 往池子里面注入 100 个 Token0，以及 1000000 个 Token1，用户可以通过 `swap` 方法来交换 Token0 和 Token1。如果用户通过 10 个 token0 按照价格 10000 换走 100000 个 token1，那么池子里将会剩余 110 个 token0 和 990000 个 token1。对应的就体现为 token1 的价格上涨了，这样我们就实现了去中心化交易所的 AMM（自动化做市商）。

当然，实际的交易中上面的例子中价格并不是以 10000 成交的，在 Uniswap 中，价格是根据池子中代币数量来计算的，价格是动态变化的，当用户交易的时候，价格会随着交易的发生而变化。在这一讲的实现中我们就会参考 [Uniswap V3 的代码](https://github.com/Uniswap/v3-core)来实现这一逻辑。`swap` 方法接收的参数并不是一个指定的价格，而是指定了价格的上限或者下限以及要获得或者要支付的代币数量。

好的，那接下来就让我们来实现 `swap` 方法吧。

## 合约开发

首先我们在 `Pool.sol` 中对入参做一下简单的验证：

```solidity
function swap(
    address recipient,
    bool zeroForOne,
    int256 amountSpecified,
    uint160 sqrtPriceLimitX96,
    bytes calldata data
) external override returns (int256 amount0, int256 amount1) {
    require(amountSpecified != 0, "AS");

    // zeroForOne: 如果从 token0 交换 token1 则为 true，从 token1 交换 token0 则为 false
    // 判断当前价格是否满足交易的条件
    require(
        zeroForOne
            ? sqrtPriceLimitX96 < sqrtPriceX96 &&
                sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE
            : sqrtPriceLimitX96 > sqrtPriceX96 &&
                sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE,
        "SPL"
    );
}
```

在上面的代码中，我们首先验证 `amountSpecified` 必须不为 0，`amountSpecified` 大于 0 代表我们指定了要支付的 token0 的数量，`amountSpecified` 小于 0 则代表我们指定了要获取的 token1 的数量。`zeroForOne` 为 `true` 代表了是 token0 换 token1，反之则相反。如果是 token0 换 token1，那么交易会导致池子的 token0 变多，价格下跌，我们需要验证 `sqrtPriceLimitX96` 必须小于当前的价格，也就是指 `sqrtPriceLimitX96` 是交易的一个价格下限。另外价格也需要大于可用的最小价格和小于可用的最大价格。

这里的实现也基本是参考了 [Uniswap V3 中的代码](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol#L608)。

然后我们需要计算在用户指定的价格和数量情况下该池子可以提供交易的 token0 和 token1 的数量，在这里我们直接调用了 `SwapMath.computeSwapStep` 方法，该方法是直接复制的 [Uniswap V4 的代码](https://github.com/Uniswap/v4-core/blob/main/src/libraries/SwapMath.sol#L51)。为什么不用 V3 的代码？之前我们提到过，因为课程使用的是 solidity 0.8.0+，而 Uniswap V3 的代码是使用 0.7.6 的，所以不兼容 0.8.0 的库，所以我们需要使用一部分 Uniswap V4 的代码，不过代码逻辑上来说它和 Uniswap V3 基本一致。

`SwapMath.computeSwapStep` 方法需要传入当前价格、限制价格、流动性数量、交易量和手续费，然后会返回可以交易的数量，以及手续的手续费和交易后新的价格。在这个计算中，价格、流动性都是一个很大的数，这其实是为了避免出现精度问题。具体计算的公式如下：

$$\sqrt{P_{target}}-\sqrt{P_{current}}=\Delta{y}/L$$

$$\sqrt{1/P_{target}}-\sqrt{1/P_{current}}=\Delta{x}/L$$

公式的具体说明你可以参考之前的课程[《Uniswap 代码解析》](https://github.com/WTFAcademy/WTF-Dapp/blob/main/P002_WhatIsUniswap/readme.md#swap-1)中的说明即可。如果你只是想要学习 DApp 应用开发，你可以忽略这一部分的细节，直接使用该方法即可。你需要知道的是，在 DApp 开发中，我们需要谨慎的考虑数字的计算问题，考虑计算中的溢出和精度问题。还要考虑 Solidity 0.7 和 0.8 在一些计算逻辑上处理的差异。

接下来，我们补充具体的实现。

首先我们定义一个 `SwapState` 结构体，用于存储交易中需要临时存储的变量：

```solidity
// 交易中需要临时存储的变量
struct SwapState {
    // the amount remaining to be swapped in/out of the input/output asset
    int256 amountSpecifiedRemaining;
    // the amount already swapped out/in of the output/input asset
    int256 amountCalculated;
    // current sqrt(price)
    uint160 sqrtPriceX96;
    // the global fee growth of the input token
    uint256 feeGrowthGlobalX128;
    // 该交易中用户转入的 token0 的数量
    uint256 amountIn;
    // 该交易中用户转出的 token1 的数量
    uint256 amountOut;
    // 该交易中的手续费，如果 zeroForOne 是 ture，则是用户转入 token0，单位是 token0 的数量，反正是 token1 的数量
    uint256 feeAmount;
}
```

然后我们在 `swap` 方法中计算交易的具体数值：

```solidity
// amountSpecified 大于 0 代表用户指定了 token0 的数量，小于 0 代表用户指定了 token1 的数量
bool exactInput = amountSpecified > 0;

SwapState memory state = SwapState({
    amountSpecifiedRemaining: amountSpecified,
    amountCalculated: 0,
    sqrtPriceX96: sqrtPriceX96,
    feeGrowthGlobalX128: zeroForOne
        ? feeGrowthGlobal0X128
        : feeGrowthGlobal1X128,
    amountIn: 0,
    amountOut: 0,
    feeAmount: 0
});

// 计算交易的上下限，基于 tick 计算价格
uint160 sqrtPriceX96Lower = TickMath.getSqrtPriceAtTick(tickLower);
uint160 sqrtPriceX96Upper = TickMath.getSqrtPriceAtTick(tickUpper);
// 计算用户交易价格的限制，如果是 zeroForOne 是 true，说明用户会换入 token0，会压低 token0 的价格（也就是池子的价格），所以要限制最低价格不能超过 sqrtPriceX96Lower
uint160 sqrtPriceX96PoolLimit = zeroForOne
    ? sqrtPriceX96Lower
    : sqrtPriceX96Upper;

// 计算交易的具体数值
(
    state.sqrtPriceX96,
    state.amountIn,
    state.amountOut,
    state.feeAmount
) = SwapMath.computeSwapStep(
    sqrtPriceX96,
    (
        zeroForOne
            ? sqrtPriceX96PoolLimit < sqrtPriceLimitX96
            : sqrtPriceX96PoolLimit > sqrtPriceLimitX96
    )
        ? sqrtPriceLimitX96
        : sqrtPriceX96PoolLimit,
    liquidity,
    amountSpecified,
    fee
);
```

在上面的代码中，我们还使用了 `TickMath` 中的方法来将 tick 转换为价格，如果你还没有引入 `TickMath` 的话，你需要在 `Pool.sol` 中引入 `TickMath` 后才能使用，其它库也是一样，它们也都是从 Uniswap V3 或者 V4 中复制过来的代码，我们在[上一讲课程](../P105_PoolLP/readme.md)中已经介绍过了。

```diff
+ import "./libraries/TickMath.sol";
+ import "./libraries/SwapMath.sol";
```

计算完成后，我们要更新一下池子的状态，以及调用回调方法（交易用户应该在回调中转入要卖出的 token），并且将换出的 token 转给用户。需要注意的是，手续费的计算和更新我们会在后面的课程中完成，在这里可以先忽略。

```solidity

// 更新新的价格
sqrtPriceX96 = state.sqrtPriceX96;
tick = TickMath.getTickAtSqrtPrice(state.sqrtPriceX96);

// 计算交易后用户手里的 token0 和 token1 的数量
if (exactInput) {
    state.amountSpecifiedRemaining -= (state.amountIn + state.feeAmount)
        .toInt256();
    state.amountCalculated = state.amountCalculated.sub(
        state.amountOut.toInt256()
    );
} else {
    state.amountSpecifiedRemaining += state.amountOut.toInt256();
    state.amountCalculated = state.amountCalculated.add(
        (state.amountIn + state.feeAmount).toInt256()
    );
}

(amount0, amount1) = zeroForOne == exactInput
    ? (
        amountSpecified - state.amountSpecifiedRemaining,
        state.amountCalculated
    )
    : (
        state.amountCalculated,
        amountSpecified - state.amountSpecifiedRemaining
    );

// 转 Token 给用户
if (zeroForOne) {
    if (amount1 < 0)
        TransferHelper.safeTransfer(
            token1,
            recipient,
            uint256(-amount1)
        );

    uint256 balance0Before = balance0();
    ISwapCallback(msg.sender).swapCallback(amount0, amount1, data);
    require(balance0Before.add(uint256(amount0)) <= balance0(), "IIA");
} else {
    if (amount0 < 0)
        TransferHelper.safeTransfer(
            token0,
            recipient,
            uint256(-amount0)
        );

    uint256 balance1Before = balance1();
    ISwapCallback(msg.sender).swapCallback(amount0, amount1, data);
    require(balance1Before.add(uint256(amount1)) <= balance1(), "IIA");
}

emit Swap(
    msg.sender,
    recipient,
    amount0,
    amount1,
    sqrtPriceX96,
    liquidity,
    tick
);
```

在上面的代码中，我们还用到了 `./libraries/SafeCast.sol` 中提供的 `toInt256` 方法。对应的你需要在 `Pool.sol` 中引入 `SafeCast` 后才能使用。

```diff
contract Pool is IPool {
+    using SafeCast for uint256;
```

以上的代码我们都参考了 [Uniswap V3 的实现](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol#L596)，但是整体要简单得多。在 Uniswap V3 中，一个池子本身没有价格上下限，而是池子中的每个头寸都有自己的上下限。所以在交易的时候需要去循环在不同的头寸中移动来找到合适的头寸来交易。而在我们的实现中，我们限制了池子的价格上下限，池子中的每个头寸都是同样的价格范围，所以我们不需要通过一个 `while` 在不同的头寸中移动交易，而是直接一个计算即可。如果你感兴趣，可以对照 [Uniswap V3 的代码](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol#L641)来学习。

至此，我们就完成了基础的交易的逻辑开发，下一讲我们会补充手续费收取的逻辑。

## 合约测试

接下来让我们编写 `swap` 的测试样例，首先我们需要创建一个用于测试的合约（涉及到回调函数调用，只有合约可以调用），我们新建 `contracts/wtfswap/test-contracts/TestSwap.sol`：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "../interfaces/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestSwap is ISwapCallback {
    function testSwap(
        address recipient,
        int256 amount,
        uint160 sqrtPriceLimitX96,
        address pool,
        address token0,
        address token1
    ) external returns (int256 amount0, int256 amount1) {
        (amount0, amount1) = IPool(pool).swap(
            recipient,
            true,
            amount,
            sqrtPriceLimitX96,
            abi.encode(token0, token1)
        );
    }

    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        // transfer token
        (address token0, address token1) = abi.decode(data, (address, address));
        if (amount0Delta > 0) {
            IERC20(token0).transfer(msg.sender, uint(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(token1).transfer(msg.sender, uint(amount1Delta));
        }
    }
}
```

在这个合约中我们定义了回调函数 `swapCallback`，它会被 `Pool` 合约调用。另外我们定义了一个 `testSwap` 方法，可以在测试样例中调用。

接下来，我们在 `test/wtfswap/Pool.ts` 中添加 `swap` 的测试样例：

```solidity
it("swap", async function () {
  const { pool, token0, token1, sqrtPriceX96 } = await loadFixture(
    deployFixture
  );
  const testLP = await hre.viem.deployContract("TestLP");

  const initBalanceValue = 100000000000n * 10n ** 18n;
  await token0.write.mint([testLP.address, initBalanceValue]);
  await token1.write.mint([testLP.address, initBalanceValue]);

  // mint 多一些流动性，确保交易可以完全完成
  const liquidityDelta = 1000000000000000000000000000n;
  // mint 多一些流动性，确保交易可以完全完成
  await testLP.write.mint([
    testLP.address,
    liquidityDelta,
    pool.address,
    token0.address,
    token1.address,
  ]);

  const lptoken0 = await token0.read.balanceOf([testLP.address]);
  expect(lptoken0).to.equal(99995000161384542080378486215n);

  const lptoken1 = await token1.read.balanceOf([testLP.address]);
  expect(lptoken1).to.equal(1000000000000000000000000000n);

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
  const result = await testSwap.simulate.testSwap([
    testSwap.address,
    100n * 10n ** 18n, // 卖出 100 个 token0
    minSqrtPriceX96,
    pool.address,
    token0.address,
    token1.address,
  ]);
  expect(result.result[0]).to.equal(100000000000000000000n); // 需要 100个 token0
  expect(result.result[1]).to.equal(-996990060009101709255958n); // 大概需要 100 * 10000 个 token1

  await testSwap.write.testSwap([
    testSwap.address,
    100n * 10n ** 18n,
    minSqrtPriceX96,
    pool.address,
    token0.address,
    token1.address,
  ]);
  const costToken0 =
    300n * 10n ** 18n - (await token0.read.balanceOf([testSwap.address]));
  const receivedToken1 = await token1.read.balanceOf([testSwap.address]);
  const newPrice = (await pool.read.sqrtPriceX96()) as bigint;
  const liquidity = await pool.read.liquidity();
  expect(newPrice).to.equal(7922737261735934252089901697281n);
  expect(sqrtPriceX96 - newPrice).to.equal(78989690499507264493336319n); // 价格下跌
  expect(liquidity).to.equal(liquidityDelta); // 流动性不变

  // 用户消耗了 100 个 token0
  expect(costToken0).to.equal(100n * 10n ** 18n);
  // 用户获得了大约 100 * 10000 个 token1
  expect(receivedToken1).to.equal(996990060009101709255958n);
});
```

在上面的样例中，我们注入了流动性，并且完成了一次交易，验证了交易的具体数值。具体的测试逻辑不再做过多的解释，你可以参考上面的代码来学习。

需要注意的是，我们在测试样例中也使用了 `@uniswap/v3-sdk` 提供的放，我们在上一讲中已经引入了，如果你还没有引入，你需要在测试文件上引入它：

```diff
+ import { TickMath, encodeSqrtRatioX96 } from "@uniswap/v3-sdk";
```

完整的合约代码在 [contracts/wtfswap/Pool.sol](../demo-contract/contracts/wtfswap/Pool.sol) 查看，完整的测试代码在 [test/wtfswap/Pool.ts](../demo-contract/test/wtfswap/Pool.ts) 查看。
