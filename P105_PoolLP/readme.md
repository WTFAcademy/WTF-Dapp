本节作者：[@愚指导](https://x.com/yudao1024)

这一讲将会实现 `Pool` 合约中涉及到 LP（流动性提供者）相关的接口，包括添加流动性、移除流动性、提取代币等。

---

## 合约简介

`Pool` 合约是教程中最复杂的一个合约，它由 `Factory` 合约创建，可能会有多个 `Pool` 合约。在我们的课程设计中，每个代币对可能有多个 `Pool` 合约，每个 `Pool` 合约就是一个交易池，每个交易池都有自己的价格上下限和手续费。

这和 Uniswap V2 以及 Uniswap V3 都不一样，Uniswap 的交易池只有交易对+手续费属性，而我们的交易池还有价格上下限属性。我们的代码更多是参考了 Uniswap V3，所以这其实是让我们的开发更简单了，因为我们只需要考虑这个固定范围内的流动性管理和交易即可，而在 Uniswap V3 中，你需要在一个交易池里面去管理在不同价格区间内的流动性。在后面的实现中，你会发现我们大量参考了 Uniswap V3 的代码，但是实际上我们只是采用了它的很少一部分逻辑，这让我们的课程更容易学习。

Uniswap V3 的交易池合约代码在 [UniswapV3Pool.sol](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol)，你可以参考这个代码来更好地理解我们的代码，或者说是参考我们的课程来学习 Uniswap V3 的代码。当然，Uniswap V2 的代码 [UniswapV2Pair.sol](https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol) 你也可以参考。

在这一讲中，我们先实现 LP 相关接口，交易接口会放到下一讲中实现。

## 合约开发

> 完整的代码在 [demo-contract/contracts/wtfswap/Pool.sol](../demo-contract/contracts/wtfswap/Pool.sol) 中。

### 1. 添加流动性

添加流动性是调用 `mint` 方法，在我们的设计中，`mint` 方法定义如下：

```solidity
function mint(
    address recipient,
    uint128 amount,
    bytes calldata data
) external returns (uint256 amount0, uint256 amount1);
```

我们传入要添加流动性 `amount`，以及 `data`，这个 `data` 是用来在回调函数中传递参数的，后面会再讲。`recipient` 可以指定讲流动性的权益赋予谁。这里需要注意的是 `amount` 是流动性，而不是要 mint 的代币，至于流动性如何计算，我们在 `PositionManager` 的章节中讲解，这一讲中先不具体展开。但是在我们这一讲的实现中，我们需要基于传入的 `amount` 计算出 `amount0` 和 `amount1`，并返回这两个值。`amount0` 和 `amount1` 分别是两个代币的数量，另外还需要在 `mint` 方法中调用我们定义的回调函数 `mintCallback`，以及修改 `Pool` 合约中的一些状态。

首先，我们参考 [Uniswap V3 的代码](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol#L466)来写一个 `_modifyPosition` 的方法，在该方法中修改交易池整体的流动性 `liquidity` 并计算返回 `amount0` 和 `amount1`。

```solidity
function _modifyPosition(
    ModifyPositionParams memory params
) private returns (int256 amount0, int256 amount1) {
    // 通过新增的流动性计算 amount0 和 amount1
    // 参考 UniswapV3 的代码
    amount0 = SqrtPriceMath.getAmount0Delta(
        sqrtPriceX96,
        TickMath.getSqrtRatioAtTick(tickUpper),
        params.liquidityDelta
    );
    amount1 = SqrtPriceMath.getAmount1Delta(
        TickMath.getSqrtRatioAtTick(tickLower),
        sqrtPriceX96,
        params.liquidityDelta
    );

    // 修改 liquidity
    uint128 liquidityBefore = liquidity;
    liquidity = LiquidityMath.addDelta(
        liquidityBefore,
        params.liquidityDelta
    );
}


function mint(
    address recipient,
    uint128 amount,
    bytes calldata data
) external override returns (uint256 amount0, uint256 amount1) {
    require(amount > 0, "Mint amount must be greater than 0");
    // 基于 amount 计算出当前需要多少 amount0 和 amount1
    (int256 amount0Int, int256 amount1Int) = _modifyPosition(
        ModifyPositionParams({
            owner: recipient,
            liquidityDelta: int128(amount)
        })
    );
}
```

相比 Uniswap V3 的 [\_modifyPosition](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol#L306)，我们的代码要简单许多。整个交易池都固定在一个价格区间内，mint 也只能在这个价格区间内 mint。所以我们只需要取 Uniswap V3 中的部分代码即可，在 Uniswap V3 中，计算流动性时的上下限是参数动态传入的 `params.tickLower` 和 `params.tickUpper`，而我们的代码中是固定的 `tickLower` 和 `tickUpper`。

另外计算过程中会用到 [SqrtPriceMath](https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/SqrtPriceMath.sol) 库，这个库是 Uniswap V3 中的一个工具库，也需要你在我们的合约代码中引入，改库还依赖了其它几个库，也需要一并引入，有部分库因为依赖于 solidity `<0.8.0;` 版本，但是我们课程用的是 `0.8.0+`，所以有几个点需要你修改，不然编译会报错：

- `FullMath.sol` 的 `uint256 twos = -denominator & denominator;` 修改为 `uint256 twos = denominator ^ (denominator - 1);`
- `TickMath.sol` 的 `require(absTick <= uint256(MAX_TICK), 'T');` 修改为 `require(absTick <= uint256(int256(MAX_TICK)), "T");`
- 上面两个文件的 `solidity <0.8.0` 的限制去掉了（也是导致上面两个地方报错需要修改的原因）。0.8 版本的 solidity 在一些运算上和 0.7 有一些差异。

当然你也可以直接复制课程提供的[代码](../demo-contract/contracts/wtfswap/libraries/)，不用自己去修改，我们的代码中已经做了这些修改。你可以直接引入下面代码：

```solidity
import "./libraries/SqrtPriceMath.sol";
import "./libraries/TickMath.sol";
import "./libraries/LiquidityMath.sol";
import "./libraries/LowGasSafeMath.sol";
import "./libraries/TransferHelper.sol";
```

其中 `LowGasSafeMath` 是下面我们会用到的一个库，它是为了避免在计算过程中出现溢出导致的错误（实际上，在 Solidity 0.8 以后，会默认开启溢出与下溢检查，这并不是必须的，你可以查看[这篇文章](https://github.com/AmazingAng/WTF-Solidity/blob/main/S05_Overflow/readme.md)了解更多），你需要在合约中加上如下内容使用它：

```diff
contract Pool is IPool {
+  using LowGasSafeMath for uint256;
```

关于 `using` 的关键词语法，你可以查看[《库合约》](https://github.com/AmazingAng/WTF-Solidity/blob/main/17_Library/readme.md) 这篇文章了解更多。

`amount0` 和 `amount1` 计算完成后需要调用 `mintCallback` 回调方法，LP 需要在这个回调方法中将对应的代币转入到 `Pool` 合约中，所以调用 `Pool` 合约 `mint` 方法的也需要是一个合约，并且在合约中定义好 `mintCallback` 方法，我们未来会在 `PositionManager` 合约中实现相关逻辑。

完整的 `mint` 方法代码如下：

```solidity
function mint(
    address recipient,
    uint128 amount,
    bytes calldata data
) external override returns (uint256 amount0, uint256 amount1) {
    require(amount > 0, "Mint amount must be greater than 0");
    // 基于 amount 计算出当前需要多少 amount0 和 amount1
    (int256 amount0Int, int256 amount1Int) = _modifyPosition(
        ModifyPositionParams({
            owner: recipient,
            liquidityDelta: int128(amount)
        })
    );
    amount0 = uint256(amount0Int);
    amount1 = uint256(amount1Int);
    // 把流动性记录到对应的 position 中
    positions[recipient].liquidity += amount;

    uint256 balance0Before;
    uint256 balance1Before;
    if (amount0 > 0) balance0Before = balance0();
    if (amount1 > 0) balance1Before = balance1();
    // 回调 mintCallback
    IMintCallback(msg.sender).mintCallback(amount0, amount1, data);

    if (amount0 > 0)
        require(balance0Before.add(amount0) <= balance0(), "M0");
    if (amount1 > 0)
        require(balance1Before.add(amount1) <= balance1(), "M1");

    emit Mint(msg.sender, recipient, amount, amount0, amount1);
}
```

我们将不同的 LP 的流动性记录在 `positions` 中，另外需要在最后检查一下对应的 token 是否到账，确认后触发一个 `Mint` 事件。

这里需要注意的是，我们还需要添加 `balance0` 和 `balance1` 两个方法，它们也是参考了 [Uniswap V3 的代码](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol#L140)，不过我们做了一点小的调整，把 V3 中定义的 `IERC20Minimal` 改为使用 `@openzeppelin/contracts/token/ERC20/IERC20.sol`，当然，真实的项目中使用 `IERC20Minimal` 会一定程度上降低合约的大小，但是我们课程中直接使用 `@openzeppelin` 下的合约会更简单，也让大家可以借此来了解 [OpenZeppelin](https://www.openzeppelin.com/solidity-contracts) 相关的库。

具体代码如下：

```solidity
/// @dev Get the pool's balance of token0
/// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
/// check
function balance0() private view returns (uint256) {
    (bool success, bytes memory data) = token0.staticcall(
        abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
    );
    require(success && data.length >= 32);
    return abi.decode(data, (uint256));
}

/// @dev Get the pool's balance of token1
/// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
/// check
function balance1() private view returns (uint256) {
    (bool success, bytes memory data) = token1.staticcall(
        abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
    );
    require(success && data.length >= 32);
    return abi.decode(data, (uint256));
}
```

这样，我们的 `mint` 方法就完成了。

### 2. 移除流动性

接下来，让我们继续实现我们之前定义好的 `burn` 方法：

```solidity
function burn(
    uint128 amount
) external returns (uint256 amount0, uint256 amount1);
```

和 `mint` 类似，它也需要传入一个 `amount`，只是它不需要有回调，另外提取代币是放到 `collect` 中操作的。在 `burn` 方法中，我们只是把流动性移除，并计算出要退回给 LP 的 `amount0` 和 `amount1`，记录在合约状态中。

完整的代码如下，我们还是会继续用到上面的 `_modifyPosition` 方法，只不过参数中的 `liquidityDelta` 变成了负数：

```solidity
function burn(
    uint128 amount
) external override returns (uint256 amount0, uint256 amount1) {
    require(amount > 0, "Burn amount must be greater than 0");
    require(
        amount <= positions[msg.sender].liquidity,
        "Burn amount exceeds liquidity"
    );
    // 修改 positions 中的信息
    (int256 amount0Int, int256 amount1Int) = _modifyPosition(
        ModifyPositionParams({
            owner: msg.sender,
            liquidityDelta: -int128(amount)
        })
    );
    // 获取燃烧后的 amount0 和 amount1
    amount0 = uint256(-amount0Int);
    amount1 = uint256(-amount1Int);

    if (amount0 > 0 || amount1 > 0) {
        (
            positions[msg.sender].tokensOwed0,
            positions[msg.sender].tokensOwed1
        ) = (
            positions[msg.sender].tokensOwed0 + uint128(amount0),
            positions[msg.sender].tokensOwed1 + uint128(amount1)
        );
    }

    emit Burn(msg.sender, amount, amount0, amount1);
}
```

我们在 `Position` 中定义了 `tokensOwed0` 和 `tokensOwed1`，用来记录 LP 可以提取的代币数量，这个代币数量是在 `collect` 中提取的，接下来就让我们继续实现 `collect` 方法。

### 3. 提取代币

提取代币是调用 `collect` 方法，我们定义如下：

```solidity
function collect(
    address recipient
) external returns (uint128 amount0, uint128 amount1);
```

和 Uniswap V3 的[代码](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol#L490)不同，我们简化是实现，只支持全部提取。完整的代码如下：

```solidity
function collect(
    address recipient
) external override returns (uint128 amount0, uint128 amount1) {
    // 获取当前用户的 position
    Position storage position = positions[msg.sender];
    // 把钱退给用户 recipient，只支持全部退还
    amount0 = position.tokensOwed0;
    amount1 = position.tokensOwed1;

    if (amount0 > 0) {
        position.tokensOwed0 -= amount0;
        TransferHelper.safeTransfer(token0, recipient, amount0);
    }
    if (amount1 > 0) {
        position.tokensOwed1 -= amount1;
        TransferHelper.safeTransfer(token1, recipient, amount1);
    }

    emit Collect(msg.sender, recipient, amount0, amount1);
}
```

在代码中，我们引入了 Uniswap V3 代码中的 `TransferHelper` 库来做转账，将 token 发送给传入的 `recipient` 地址。至此，基础的逻辑就实现完成了。
