本节作者：[@愚指导](https://x.com/yudao1024)

这一讲将会实现 `Pool` 合约中的手续费收取的逻辑。

---

## 简介

手续费收取除了需要考虑从用户手中扣除手续费外，还要考虑如何按照 LP 贡献的流动性来分配手续费收益。

首先我们需要在 `Pool` 合约中定义两个变量：

```solidity
/// @inheritdoc IPool
uint256 public override feeGrowthGlobal0X128;
/// @inheritdoc IPool
uint256 public override feeGrowthGlobal1X128;
```

它们代表了从池子创建以来累计收取到的手续费（具体是每个流动性可以提取的手续费乘以 2 的 96 次方），为什么需要记录这两个值呢？因为 LP 是可以随时提取手续费的，而且每个 LP 提取的时间不一样，所以 LP 提取手续费时我们需要计算出他历史累计的手续费收益。

其中 `feeGrowthGlobal0X128` 和 `feeGrowthGlobal1X128` 是通过手续费乘以 `FixedPoint128.Q128`（2 的 96 次方），然后除以流动性数量得到的，和上面交易类似，乘以 `FixedPoint128.Q128` 是为了避免精度问题。

## 开发

如上所说，在 `Pool.sol` 中需要添加如下定义：

```solidity
/// @inheritdoc IPool
uint256 public override feeGrowthGlobal0X128;
/// @inheritdoc IPool
uint256 public override feeGrowthGlobal1X128;
```

我们在 `Position` 中也需要添加 `feeGrowthInside0LastX128` 和 `feeGrowthInside1LastX128`，它代表了 LP 上次提取手续费时的全局手续费收益，这样当 LP 提取手续费时我们就可以和池子累计的手续费收益来做计算算出他可以提取的收益了。

```solidity
struct Position {
    // 该 Position 拥有的流动性
    uint128 liquidity;
    // 可提取的 token0 数量
    uint128 tokensOwed0;
    // 可提取的 token1 数量
    uint128 tokensOwed1;
    // 上次提取手续费时的 feeGrowthGlobal0X128
    uint256 feeGrowthInside0LastX128;
    // 上次提取手续费是的 feeGrowthGlobal1X128
    uint256 feeGrowthInside1LastX128;
}
```

比如如果池子的 `feeGrowthGlobal0X128` 是 100，LP 提取手续费时的 `Position` 中 `feeGrowthInside0LastX128` 也是 100，那么说明 LP 没有新的可以提取的手续费。

接下来让我们实现具体的逻辑，首先我们在 `swap` 方法中更新每次交易后的手续费数值：

```solidity
// 计算手续费
state.feeGrowthGlobalX128 += FullMath.mulDiv(
    state.feeAmount,
    FixedPoint128.Q128,
    liquidity
);

// 更新手续费相关信息
if (zeroForOne) {
    feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
} else {
    feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
}
```

其中 `FullMath.mulDiv` 方法接收三个参数，结果返回第一个参数和第二个参数的乘积再除以第三个参数。

然后在 `_modifyPosition` 中补充相关逻辑，每次 LP 调用 `mint` 或者 `burn` 方法时更新头寸（`Position`）中的 `tokensOwed0` 和 `tokensOwed1`。

```solidity
Position memory position = positions[params.owner];

// 提取手续费，计算从上一次提取到当前的手续费
uint128 tokensOwed0 = uint128(
    FullMath.mulDiv(
        feeGrowthGlobal0X128 - position.feeGrowthInside0LastX128,
        position.liquidity,
        FixedPoint128.Q128
    )
);
uint128 tokensOwed1 = uint128(
    FullMath.mulDiv(
        feeGrowthGlobal1X128 - position.feeGrowthInside1LastX128,
        position.liquidity,
        FixedPoint128.Q128
    )
);

// 更新提取手续费的记录，同步到当前最新的 feeGrowthGlobal0X128，代表都提取完了
position.feeGrowthInside0LastX128 = feeGrowthGlobal0X128;
position.feeGrowthInside1LastX128 = feeGrowthGlobal1X128;
// 把可以提取的手续费记录到 tokensOwed0 和 tokensOwed1 中
// LP 可以通过 collect 来最终提取到用户自己账户上
if (tokensOwed0 > 0 || tokensOwed1 > 0) {
    position.tokensOwed0 += tokensOwed0;
    position.tokensOwed1 += tokensOwed1;
}
```

在上面代码中，我们通过 `FullMath.mulDiv` 计算最终可以提取的手续费，因为计算的时候乘了 `FixedPoint128.Q128`，所以在这里需要除 `FixedPoint128.Q128`。

这样，当 LP 调用 `collect` 方法时，就可以将 `Position` 中的 `tokensOwed0` 和 `tokensOwed1` 转给用户了。

## 合约测试

TODO
