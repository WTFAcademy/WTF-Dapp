本节作者：[@mocha.wiz](https://x.com/mocha_wizard) [@愚指导](https://x.com/yudao1024)

这一讲我们将引导大家完成 `SwapRouter.sol` 合约的开发。

---

## 合约简介

`SwapRouter` 合约用于将多个交易池 `Pool` 合约的交易组合为一个交易。每个代币对可能会有多个交易池，因为交易池的流动性、手续费、价格上下限不一样，所以用户的一次交易需求可能会发生在多个交易池中。在 Uniswap 中，还支持跨交易对交易。比如只有 A/B 和 B/C 两个交易对，用户可以通过 A/B 和 B/C 两个交易对完成 A/C 的交易。但是我们课程相对来说会比较简单，只需要支持同一个交易对的不同交易池的交易即可，但是整体上我们也会参考 Uniswap 的 [SwapRouter.sol](https://github.com/Uniswap/v3-periphery/blob/main/contracts/SwapRouter.sol) 代码。

在该合约中，我们主要提供 `exactInput` 和 `exactOutput` 方法，分别用于换入多少 Token 确定的情况和换出多少 Token 的情况的交易。在它们的入参中需要指定要在哪些交易池中交易（数组 `indexPath` 指定），所以在哪些交易池中交易的选择需要在后续前端的课程中实现，综合流动性和手续费等来选择具体的交易池，合约中则只需要实现按照指定的交易池顺序交易即可。

另外，还需要实现 `quoteExactInput` 和 `quoteExactOutput` 方法，用于模拟交易，提供前端相关信息（用户需要在交易前知道需要或者获得的 Token）。这两个方法会参考 Uniswap 的 [Quoter.sol](https://github.com/Uniswap/v3-periphery/blob/main/contracts/lens/Quoter.sol) 实现，`Quoter` 就是“报价”的意思。

## 合约开发

> 完整的代码在 [demo-contract/contracts/wtfswap/SwapRouter.sol](../demo-contract/contracts/wtfswap/SwapRouter.sol) 中。

### 1. 实现交易接口

我们首先实现 `exactInput`，逻辑也很简单，就是遍历 `indexPath`，然后获取到对应的交易池的地址，接着调用交易池的 `swap` 接口，如果中途交易完成了就提前退出遍历即可。

具体代码如下：

```solidity
function exactInput(
    ExactInputParams calldata params
) external payable override returns (uint256 amountOut) {
    // 记录确定的输入 token 的 amount
    uint256 amountIn = params.amountIn;

    // 根据 tokenIn 和 tokenOut 的大小关系，确定是从 token0 到 token1 还是从 token1 到 token0
    bool zeroForOne = params.tokenIn < params.tokenOut;

    // 遍历指定的每一个 pool
    for (uint256 i = 0; i < params.indexPath.length; i++) {
        address poolAddress = poolManager.getPool(
            params.tokenIn,
            params.tokenOut,
            params.indexPath[i]
        );

        // 如果 pool 不存在，则抛出错误
        require(poolAddress != address(0), "Pool not found");

        // 获取 pool 实例
        IPool pool = IPool(poolAddress);

        // 构造 swapCallback 函数需要的参数
        bytes memory data = abi.encode(
            params.tokenIn,
            params.tokenOut,
            params.indexPath[i],
            params.recipient == address(0) ? address(0) : msg.sender,
            true
        );

        // 调用 pool 的 swap 函数，进行交换，并拿到返回的 token0 和 token1 的数量
        (int256 amount0, int256 amount1) = pool.swap(
            params.recipient,
            zeroForOne,
            int256(amountIn),
            params.sqrtPriceLimitX96,
            data
        );

        // 更新 amountIn 和 amountOut
        amountIn -= uint256(zeroForOne ? amount0 : amount1);
        amountOut += uint256(zeroForOne ? -amount1 : -amount0);

        // 如果 amountIn 为 0，表示交换完成，跳出循环
        if (amountIn == 0) {
            break;
        }
    }

    // 如果交换到的 amountOut 小于指定的最少数量 amountOutMinimum，则抛出错误
    require(amountOut >= params.amountOutMinimum, "Slippage exceeded");

    // 发送 Swap 事件
    emit Swap(msg.sender, zeroForOne, params.amountIn, amountIn, amountOut);

    // 返回 amountOut
    return amountOut;
}
```

其中我们调用 `swap` 函数时构造了一个 `data`，它会在 `Pool` 合约回调的时候传回来，我们需要在回调函数中通过相关信息来继续执行交易。

接下来我们继续实现回调函数 `swapCallback`，代码如下：

```solidity
function swapCallback(
    int256 amount0Delta,
    int256 amount1Delta,
    bytes calldata data
) external override {
    // transfer token
    (
        address tokenIn,
        address tokenOut,
        uint32 index,
        address payer,
        bool isExactInput
    ) = abi.decode(data, (address, address, uint32, address, bool));
    address _pool = poolManager.getPool(tokenIn, tokenOut, index);

    // 检查 callback 的合约地址是否是 Pool
    require(_pool == msg.sender, "Invalid callback caller");

    (uint256 amountToPay, uint256 amountReceived) = amount0Delta > 0
        ? (uint256(amount0Delta), uint256(-amount1Delta))
        : (uint256(amount1Delta), uint256(-amount0Delta));
    // payer 是 address(0)，这是一个用于预估 token 的请求（quoteExactInput or quoteExactOutput）
    // 参考代码 https://github.com/Uniswap/v3-periphery/blob/main/contracts/lens/Quoter.sol#L38
    if (payer == address(0)) {
        if (isExactInput) {
            // 指定输入情况下，抛出可以接收多少 token
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountReceived)
                revert(ptr, 32)
            }
        } else {
            // 指定输出情况下，抛出需要转入多少 token
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountToPay)
                revert(ptr, 32)
            }
        }
    }

    // 正常交易，转账给交易池
    if (amountToPay > 0) {
        IERC20(tokenIn).transferFrom(payer, _pool, amountToPay);
    }
}
```

如上面代码所示，在回调函数中我们解析出在 `exactInput` 方法中传入的 `data`，另外结合 `amount0Delta` 和 `amount1Delta` 完成如下逻辑：

- 通过 `tokenIn` 和 `tokenOut` 以及 `index` 获取到对应的 `Pool` 合约地址，然后和 `msg.sender` 比较，确保调用是来自于 `Pool` 合约（避免被攻击）。
- 通过 `payer` 判断是否是报价（`quoteExactInput` 或者 `quoteExactOutput`）的请求，如果是则抛出错误，抛出的错误中带上需要转入或者接收的 token 数量，后面我们再实现报价接口时需要用到。
- 如果不是报价请求，则正常转账给交易池。我们需要通过 `amount0Delta` 和 `amount1Delta` 来判断转入或者转出的 token 数量。

和 `exactInput` 类似，`exactOutput` 方法也差不多，只是一个是按照 `amountIn` 来确定交易是否结束，一个是按照 `amountOut` 来确定交易是否结束。具体代码就不张贴在此了，大家可以参考 [demo-contract/contracts/wtfswap/SwapRouter.sol](../demo-contract/contracts/wtfswap/SwapRouter.sol) 查看具体代码内容。

### 2. 实现报价接口

报价接口我们参考了 Uniswap 的 [Quoter.sol](https://github.com/Uniswap/v3-periphery/blob/main/contracts/lens/Quoter.sol) 实现，它用了一个小技巧。就是用 `try catch` 的包住 `swap` 接口，然后从抛出的错误这种解析出需要转入或者接收的 token 数量。

这个是为啥呢？因为我们需要模拟 `swap` 方法来预估交易需要的 Token，但是因为预估的时候并不会实际产生 Token 的交换，所以会报错。通过主动抛出一个特殊的错误，然后捕获这个错误，从错误信息中解析出需要的信息。

具体的代码如下：

```solidity
// 报价，指定 tokenIn 的数量和 tokenOut 的最小值，返回 tokenOut 的实际数量
function quoteExactInput(
    QuoteExactInputParams calldata params
) external override returns (uint256 amountOut) {
    // 因为没有实际 approve，所以这里交易会报错，我们捕获错误信息，解析需要多少 token
    try
        this.exactInput(
            ExactInputParams({
                tokenIn: params.tokenIn,
                tokenOut: params.tokenOut,
                indexPath: params.indexPath,
                recipient: address(0),
                deadline: block.timestamp + 1 hours,
                amountIn: params.amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: params.sqrtPriceLimitX96
            })
        )
    {} catch (bytes memory reason) {
        return parseRevertReason(reason);
    }
}
```

解析错误的代码我们也参考 [Uniswap 的代码](https://github.com/Uniswap/v3-periphery/blob/main/contracts/lens/Quoter.sol#L69)引入下面的方法：

```solidity
/// @dev Parses a revert reason that should contain the numeric quote
function parseRevertReason(
    bytes memory reason
) private pure returns (uint256) {
    if (reason.length != 32) {
        if (reason.length < 68) revert("Unexpected error");
        assembly {
            reason := add(reason, 0x04)
        }
        revert(abi.decode(reason, (string)));
    }
    return abi.decode(reason, (uint256));
}
```

看上去挺 Hack 的，但是也很实用。这样就不需要针对预估交易的需求去改造 swap 方法了，逻辑也更简单。

## 合约测试

最后我们来补充下相关的测试代码，在笔者写测试代码的过程中就发现了好几处不易察觉的 Bug，在智能合约的编写过程中，测试代码是非常重要的，可以帮助我们发现一些不易察觉的问题。

完整的测试代码就不贴出了，你可以在 [demo-contract/test/wtfswap/SwapRouter.ts](../demo-contract/test/wtfswap/SwapRouter.ts) 中查看。

这里贴出下面一小段作为说明：

```ts
it("quoteExactInput", async function () {
  const { swapRouter, token0, token1 } = await deployFixture();

  const data = await swapRouter.simulate.quoteExactInput([
    {
      tokenIn: token0.address,
      tokenOut: token1.address,
      amountIn: 10n * 10n ** 18n,
      indexPath: [0, 1],
      sqrtPriceLimitX96: BigInt(encodeSqrtRatioX96(100, 1).toString()),
    },
  ]);
  expect(data.result).to.equal(97750848089103280585132n); // 10 个 token0 按照 10000 的价格大概可以换 97750 token1
});
```

在调用 `quoteExactInput` 方法的时候我们通过 `simulate` 的方式调用，因为 `quoteExactInput` 方法是写方法，但是实际上我们做的是预估，所以我们通过 `simulate` 的方式来调用，这样就不会真的执行交易。

后续我们在前端的课程中也是如此，会通过这个接口来预估用户的交易，所以前端的代码也可以参考我们的测试代码来实现。

支持，恭喜你就完成了所有合约部分的课程学习和代码开发，接下来就让我们继续进入前端部分的学习吧。🚀
