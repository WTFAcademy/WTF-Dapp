这一讲我们将会搭建一个流动性池合约，该合约可以接受用户的流动性，并在特定价格区间内进行交易。

---

# Pool 合约

Wtfswap 的 Pool 合约池子合约是用于管理两个代币交易的智能合约, 主要存储了一下数据：

- 代币地址: 两个交易代币的地址，需要被设置为 immutable，仅设置一次并且保持不变。
- 流动性仓位: 一个 mapping，其中键代表流动性仓位，值包含该仓位的相关信息。
- Tick: 一个 mapping，其中键代表 Tick 索引，值包含该 Tick 的相关信息。
- 池子流动性: 池子中总的流动性数量，用 L 表示。
- 当前价格和 Tick: 当前价格和对应的 Tick 存储在同一个槽中，以节省 gas 费。

```solidity
// src/lib/Tick.sol
library Tick {
    struct Info {
        bool initialized;
        uint128 liquidity;
    }
    ...
}

// src/lib/Position.sol
library Position {
    struct Info {
        uint128 liquidity;
    }
    ...
}

// src/Pool.sol
contract Pool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    // 池子代币（ immutable ）
    address public immutable token0;
    address public immutable token1;

    // 当前价格和对应的 Tick 存储在同一个槽中，以节省 gas 费。
    struct Slot0 {
        // 当前价格
        uint160 sqrtPriceX96;
        // 当前 tick
        int24 tick;
        bool unlocked;
    }
    Slot0 public slot0;

    // 流动性
    uint128 public liquidity;

    // Ticks 信息
    mapping(int24 => Tick.Info) public ticks;
    // Positions 信息
    mapping(bytes32 => Position.Info) public positions;

    ...
```

接下来，初始化其中一些变量：不可变的 token 地址、当前的价格和对应的 tick。

```solidity
constructor(
    address _token0,
    address _token1,
    uint24 _fee,
    int24 _tickSpacing
) {
    require(_token0 != address(0), "token 0 = zero address");
    require(_token0 < _token1, "token 0 >= token 1");

    token0 = _token0;
    token1 = _token1;
    fee = _fee;
    tickSpacing = _tickSpacing;
    maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(
        _tickSpacing
    );
}


function initialize(uint160 sqrtPriceX96) external {
    require(slot0.sqrtPriceX96 == 0, "already initialized");
    int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    // 初始化零插槽
    slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick, unlocked: true});
}
```

## TickBitmap 库合约

在添加流动性之前，我们需要创建一个 TickBitmap 合约。

由于流动性分布在不同的价格区间，我们需要根据每个区间的流动性情况进行检索。因此，我们需要对于所有拥有流动性的 tick 建立一个索引，之后使用这个索引来寻找 tick 直到“填满”当前交易所需的流动性。

合约使用 Bitmap 数据结构，每个元素可以是 0 或者 1，可以被看做是一个 flag：当 flag 设置为(1)，对应的 tick 有流动性；当 flag 设置为(0)，对应的 tick 没有被初始化，即没有流动性。

在 Pool 合约中，tick 索引存储为一个状态变量：

```solidity
contract Pool is Pool{
    using TickBitmap for mapping(int16 => uint256);
    mapping(int16 => uint256) public tickBitmap;
    ...
}
```

这里的存储方式是 mapping，key 的类型是 int16，value 的类型是 uint256。

![tick_bitmap.png](./img/tick_bitmap.png)

数组中每个元素都对应一个 tick， 数组按照 wordPos 的大小划分：每个子数组为 256 位。使用 position 函数找到数组中某个 tick 的位置：

```solidity
function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
    wordPos = int16(tick >> 8);
    bitPos = uint8(uint24(tick % 256));
}
```

我们首先找到对应的 wordPos 所在的位置，然后再找到 wordPos 中的 bitPos 的位置。>>8 即除以 256。除以 256 的商为 wordPos 的位置，余数为 bitPos 的位置。

如下所示计算某个 tick 的位置：

```solidity
tick = 85176
word_pos = tick >> 8 # or tick // 2**8
bit_pos = tick % 256
print(f"Word {word_pos}, bit {bit_pos}")
# Word 332, bit 184

```

**翻转 flag**
当在池子中添加流动性时，我们通过 flipTick 方法设置 tick 的 flag：

```solidity
function flipTick(
    mapping(int16 => uint256) storage self,
    int24 tick,
    int24 tickSpacing
) internal {
    require(tick % tickSpacing == 0);
    (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
    uint256 mask = 1 << bitPos;
    self[wordPos] ^= mask;
}

```

找到对应的 tick 后，我们需要创建一个 mask。它是一个仅有某一位（tick 对应的位）为 1 的数字。mask 的计算方法是 $2**bit_pos$ (等于 1 << bit_pos)：

```solidity
mask = 2**bit_pos # or 1 << bit_pos
print(bin(mask))
#0b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

```

翻转一个 flag，是与对应的 word 进行异或运算，可以看到第 184 位被翻转成了 0：

```solidity
word = (2**256) - 1 # set word to all ones
print(bin(word ^ mask))
#0b11111111111111111111111111111111111111111111111111111111111111111111111->0<-1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
```

**找到下一个 tick**
接下来是通过 bitmap 索引来寻找带有流动性的 tick, 这个函数在 swap 中应用。

在 swap 过程中，我们需要使用 TickMath.nextInitializedTickWithinOneWord 方法找到现在 tick 左边或者右边的下一个有流动性的 tick。在这个函数中，需要实现两个场景：

- 当卖出 token x 时，找到在同一个 word 内当前 tick 的右边下一个有流动性的 tick。
- 当卖出 token y 时，找到在同一个 word 内当前 tick 的左边下一个有流动性的 tick。

这分别对应两个方向交易时价格的移动：

![find_next_tick.png](./img/find_next_tick.png)

需要注意的是，在代码实现中，方向是相反的：购买 token x 是搜寻左边的流动性 tick；卖出 token x 是搜寻右边的 tick。

如果当前 word 内不存在有流动性的 tick，则在在相邻的 word 中继续寻找。

```solidity
function nextInitializedTickWithinOneWord(
    mapping(int16 => uint256) storage self,
    int24 tick,
    int24 tickSpacing,
    bool lte
) internal view returns (int24 next, bool initialized) {
    int24 compressed = tick / tickSpacing;
    ...

```

- self 就是 tickBitmap；
- tick 代表要操作的 tick；
- tickSpaceing 是 tick 的间隔；
- lte 是一个设置方向的 flag。为 true 时，是卖出 token
  x，在右边寻找下一个 tick；false 则相反。

```solidity
if (lte) {
    (int16 wordPos, uint8 bitPos) = position(compressed);
    uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
    uint256 masked = self[wordPos] & mask;
    ...

```

卖出 token x 时需要：

- 获得当前 tick 的对应位置
- 求出一个 mask，当前位及所有右边的位为 1
- 将 mask 与当前 word 做与运算，得出右边的所有位

接下来，masked 不为 0 表示右边至少有一个 tick 对应的位为 1。如果有这样的 tick，那右边就有流动性；否则就没有（在当前 word 中）。

```solidity

    ...
} else {
    (int16 wordPos, uint8 bitPos) = position(compressed + 1);
    uint256 mask = ~((1 << bitPos) - 1);
    uint256 masked = self[wordPos] & mask;
    ...

```

同理，卖出 y 时：

- 获取当前 tick 的位置；
- 求出一个不同的 mask，当前位置所有左边的位为 1；
- 同样，如果当前 word 左边没有有流动性的 tick，返回上一个 word 的最右边一位：

```solidity

    ...
    initialized = masked != 0;
    // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
    next = initialized
        ? (compressed + 1 + int24(uint24((BitMath.leastSignificantBit(masked) - bitPos)))) * tickSpacing
        : (compressed + 1 + int24(uint24((type(uint8).max - bitPos)))) * tickSpacing;
}

```

## 添加流动性（Mint）

在 Pool 合约中，提供流动性被称作铸造(mint)，包含以下参数：

- 代币所有者地址: 用于识别提供流动性的用户。
- Tick 上限和下限: 定义流动性将生效的价格范围。
- 期望流动性数量: 用户希望贡献的流动性数量。

mint 函数主要包括：

- 用户指定价格区间和流动性的数量；
- 合约更新 ticks 和 positions 的 mapping；
- 合约计算出用户需要提供的 token 数量；
- 合约从用户处获得 token，并且验证数量是否正确。

检查 tick：

```solidity

function checkTicks(int24 tickLower, int24 tickUpper) pure {
    require(tickLower < tickUpper);
    require(tickLower >= TickMath.MIN_TICK);
    require(tickUpper <= TickMath.MAX_TICK);
}
```

接下来，更新 tick 和 position 的信息：

```solidity
flippedLower = ticks.update(
    tickLower,
    tick,
    liquidityDelta,
    _feeGrowthGlobal0X128,
    _feeGrowthGlobal1X128,
    false,
    maxLiquidityPerTick
);

flippedUpper = ticks.update(
    tickUpper,
    tick,
    liquidityDelta,
    _feeGrowthGlobal0X128,
    _feeGrowthGlobal1X128,
    true,
    maxLiquidityPerTick
);

Position.Info storage position = positions.get(
    owner,
    lowerTick,
    upperTick
);

position.update(
    liquidityDelta,
    feeGrowthInside0X128,
    feeGrowthInside1X128
);

```

ticks.update 函数如下所示：

```solidity
// src/lib/Tick.sol
function update(
    mapping(int24 => Info) storage self,
    int24 tick,
    uint128 liquidityDelta
) internal returns (bool flipped) {
    Info storage info = self[tick];

    uint128 liquidityGrossBefore = info.liquidityGross;
    uint128 liquidityGrossAfter = liquidityDelta < 0
        ? liquidityGrossBefore - uint128(-liquidityDelta)
        : liquidityGrossBefore + uint128(liquidityDelta);

    require(liquidityGrossAfter <= maxLiquidity, "liquidity > max");

    flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

    if (liquidityGrossBefore == 0) {
        // 4.2 update
        // f_{out,i} = f_g - f_{out, i}
        if (tick <= tickCurrent) {
            info.feeGrowthOutside0X128 = feeGrowthGlobalOX128;
            info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
        }
        info.initialized = true;
    }
}

现在，它会返回一个 flipped flag，当流动性被添加到一个空的 tick 或整个 tick 的流动性被耗尽时为 true。

```

它初始化一个流动性为 0 的 tick，并且在上面添加新的流动性。我们会在下界 tick 和上界 tick 处均调用此函数，流动性在两边都有添加。

```solidity
// src/libs/Position.sol
function update(Info storage self, uint128 liquidityDelta) internal {
    uint128 liquidityBefore = self.liquidity;
    uint128 liquidityAfter = liquidityBefore + liquidityDelta;

    self.liquidity = liquidityAfter;
}

```

Position 合约的 get 函数如下：

```solidity
// src/libs/Position.sol
...
function get(
    mapping(bytes32 => Info) storage self,
    address owner,
    int24 tickLower,
    int24 tickUpper
) internal view returns (Info storage position) {
    position = self[
        keccak256(abi.encodePacked(owner, tickLower, tickUpper))
    ];
}
...

```

**初始化 tick 与更新**

接下来，在 mint 函数中，我们更新 bitmap 索引：

```solidity
// src/Pool.sol
...

if (flippedLower) {
    tickBitmap.flipTick(tickLower, tickSpacing);
}

if (flippedUpper) {
    tickBitmap.flipTick(tickUpper, tickSpacing);
}
...

```

然后，使用 Math 库合约来计算 token 数量：

```solidity
// src/Pool.sol
function mint(...) {
    ...
    amount0 = uint256(amount0Int);
    amount1 = uint256(amount1Int);

    if (amount0 > 0) {
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
    }
    if (amount1 > 0) {
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
    }
    ...
}

```

## 移除流动性

**移除流动性**
与 mint 相对应，我们把移除流动性叫做 burn。burn 函数允许 LP 移除 position 中部分或者全部的流动性， 并计算 LP 应该得到的利润收入。实际的 token 转账会在 collect 函数中实现。

**燃烧流动性**
为了实现 burn，我们需要重构代码，把 position 相关的代码（更新 tick 和 position，以及 token 数量的计算）移动到 `_modifyPosition` 函数中，这个函数会被 mint 和 burn 使用。

```solidity
function burn(
    int24 tickLower,
    int24 tickUpper,
    uint128 amount
) external lock returns (uint256 amount0, uint256 amount1) {
    (Position.Info storage position, int256 amount0Int, int256 amount1Int) = _modifyPosition(
        ModifyPositionParams({
            owner: msg.sender,
            tickLower: tickLower,
            tickUpper: tickUpper,
            // 使用 SafeCast 进行的转化(移除流动性， 所以是负数)
            liquidityDelta: -int256(uint256(amount)).toInt128()
        })
    );

    amount0 = uint256(-amount0Int);
    amount1 = uint256(-amount1Int);

    if (amount0 > 0 || amount1 > 0) {
        // 更新的代币 0 和 1 的仓位（collect函数要使用的， 转账后再减去相应的添加的 amount0, amount1）
        (position.tokensOwed0, position.tokensOwed1) = (
            position.tokensOwed0 + uint128(amount0),
            position.tokensOwed1 + uint128(amount1)
        );
    }
}
```

burn 函数移除的是 msg.sender 的流动性头寸。其有三个入参，tickLower 和 tickUpper 用来指定要移动哪个头寸，amount 指定要移除的流动性数额。

然后和 mint 一样，第一步核心操作也是先 `_modifyPosition`, 并从中移除一定数量的流动性, 所以传入的 liquidityDelta 参数转为负数。而返回的 amount0Int 和 amount1Int 也会是负数，所以转为 uint256 类型的 amount0 和 amount1 时，又需要加上负号将负数再转为正数。之后，将 amount0 和 amount1 分别累加到了头寸的 tokensOwed0 和 tokensOwed1。

UniswapV3 的处理方式并不是移除流动性时直接把两种 token 资产转给用户，而是先累加到 tokensOwed0 和 tokensOwed1，代表这是欠用户的资产，其中也包括该头寸已赚取到的手续费。之后，用户其实是要通过 collect 函数来提取 tokensOwed0 和 tokensOwed1 里的资产。

```solidity
function collect(
    address recipient,
    int24 tickLower,
    int24 tickUpper,
    uint128 amount0Requested,
    uint128 amount1Requested
) external lock returns (uint128 amount0, uint128 amount1) {
    // amount0 和 amount1 是返回 requested 和 owed 中较小的
    Position.Info storage position = positions.get(
        msg.sender,
        tickLower,
        tickUpper
    );
    amount0 = amount0Requested > position.tokensOwed0
        ? position.tokensOwed0
        : amount0Requested;

    amount1 = amount1Requested > position.tokensOwed1
        ? position.tokensOwed1
        : amount1Requested;

    if (amount0 > 0) {
        position.tokensOwed0 -= amount0;
        IERC20(token0).transfer(recipient, amount0);
    }

    if (amount1 > 0) {
        position.tokensOwed1 -= amount1;
        IERC20(token1).transfer(recipient, amount1);
    }
}

```

函数的 5 个入参：`recipient` 是接收 token 的地址，`tickLower` 和 `tickUpper` 指定头寸的区间，`amount0Requested` 和 `amount1Requested` 是用户希望提取的数额。返回值 `amount0` 和 `amount1` 是实际提取的数额。实现逻辑如下：首先，通过 `msg.sender`、`tickLower` 和 `tickUpper` 读取用户的头寸；然后判断用户希望提取的数额和头寸中的 `tokensOwed0`、`tokensOwed1` 哪个值小，就实际提取哪个数额；接着从头寸的 `tokensOwed` 中减去提取的数额并转账给接收地址；最后发送 `Collect` 事件。这个函数仅从池子中转出 token，并确保只能转出有效的数量（不能超过燃烧和小费收入的数量）。这种方式允许在不燃烧流动性的情况下提取费用收入：将燃烧的流动性数量设置为 0，然后调用 `collect`。在燃烧过程中，头寸会被更新，应得的 token 数量也会更新。

## 交易（Swap）

现在我们已经有了流动性，我们可以进行 swap 交易了：

将指定数量的某一种代币发送到指定的接收地址，并从调用者处接收相应数量的另一种代币。

**当前价格区间内完成交易**

在 swap 函数中，我们新增了两个参数：zeroForOne 和 amountSpecified。zeroForOne 是用来控制交易方向的 flag：当设置为 true，是用 token0 兑换 token1；false 则相反。例如，如果 token0 是 ETH，token1 是 USDC，将 zeroForOne 设置为 true 意味着用 ETH 购买 USDC。amountSpecified 是用户希望卖出的 token 数量。

```solidity
function swap(
    address recipient,
    bool zeroForOne,
    int256 amountSpecified,
    uint160 sqrtPriceLimitX96
) external lock returns (int256 amount0, int256 amount1) {
    ...
```

定义两个新的结构体：

- SwapState 当前 swap 的状态。amoutSpecifiedRemaining 跟踪了还需要从池子中获取的 token 数量：当这个数量为 0 时，这笔订单就被填满了。amountCalculated 是由合约计算出的输出数量。sqrtPriceX96 和 tick 是交易结束后的价格和 tick。

- StepComputations 计算当前交易“下一步”的状态。这个结构体跟踪“填满订单”过程中一个循环的状态。sqrtPriceStartX96 跟踪循环开始时的价格。tickNext 是能够为交易提供流动性的下一个已初始化的 tick，sqrtPriceNextX96 是下一个 tick 的价格。amountIn 和 amountOut 是当前循环中流动性能够提供的数量。

```solidity

struct SwapState {
    uint256 amountSpecifiedRemaining;
    uint256 amountCalculated;
    uint160 sqrtPriceX96;
    int24 tick;
}

struct StepComputations {
    uint160 sqrtPriceStartX96;
    int24 tickNext;
    bool initialized;
    uint160 sqrtPriceNextX96;
    uint256 amountIn;
    uint256 amountOut;
    uint256 feeAmount;
}

```

```solidity
// src/Pool.sol

function swap(...) {
    Slot0 memory slot0_ = slot0;

    SwapState memory state = SwapState({
        amountSpecifiedRemaining: amountSpecified,
        amountCalculated: 0,
        sqrtPriceX96: slot0_.sqrtPriceX96,
        tick: slot0_.tick
    });
    ...
```

在填满一个订单之前，我们首先初始化 SwapState 的实例。循环直到 amoutSpecifiedRemaining 变成 0，也即池子拥有足够的流动性来买用户的 amountSpecified 数量的 token。

```solidity
...
while (
    state.amountSpecifiedRemaining != 0 &&
    state.sqrtPriceX96 != sqrtPriceLimitX96
) {
    StepComputations memory step;

    step.sqrtPriceStartX96 = state.sqrtPriceX96;

    (step.tickNext, step.initialized) = tickBitmap
        .nextInitializedTickWithinOneWord(
            state.tick,
            tickSpacing,
            zeroForOne
        );

    step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

```

在循环中，设置一个价格区间为这笔交易提供流动性的价格区间。这个区间是从 state.sqrtPriceX96 到 step.sqrtPriceNextX96，后者是下一个初始化的 tick 对应的价格（从 nextInitializedTickWithinOneWord 中获取）。

```solidity
(
    state.sqrtPriceX96,
    step.amountIn,
    step.amountOut,
    step.feeAmount
) = SwapMath.computeSwapStep(
    state.sqrtPriceX96,
    (
        zeroForOne
            ? step.sqrtPriceNextX96 < sqrtPriceLimitX96
            : step.sqrtPriceNextX96 > sqrtPriceLimitX96
    )
        ? sqrtPriceLimitX96
        : step.sqrtPriceNextX96,
    state.liquidity,
    state.amountSpecifiedRemaining,
    fee
);

```

接下来，计算当前价格区间能够提供的流动性的数量，以及交易达到的目标价格。

```solidity
if (exactInput) {
    // 减少到 0
    state.amountSpecifiedRemaining -= (step.amountIn +
        step.feeAmount).toInt256();
    state.amountCalculated -= step.amountOut.toInt256();
} else {
    // 增加到 0
    state.amountSpecifiedRemaining += step.amountOut.toInt256();
    state.amountCalculated += (step.amountIn + step.feeAmount)
        .toInt256();
}

```

循环中的最后一步就是更新 SwapState。step.amountIn 是这个价格区间可以从用户手中买走的 token 数量了；step.amountOut 是相应的池子卖给用户的数量。state.sqrtPriceX96 是交易结束后的现价（因为交易会改变价格）。

**SwapMath 合约**
接下来，让我们更深入研究一下 SwapMath.computeSwapStep：

```solidity

// src/lib/SwapMath.sol
function computeSwapStep(
    uint160 sqrtPriceCurrentX96,
    uint160 sqrtPriceTargetX96,
    uint128 liquidity,
    uint256 amountRemaining,
    uint24 feePips
)
    internal
    pure
    returns (
        uint160 sqrtPriceNextX96,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeAmount
    )
{
    ...
```

computeSwapStep 函数是整个 swap 的核心逻辑所在。该函数计算了一个价格区间内部的交易数量以及对应的流动性。它的返回值是：新的现价、输入 token 数量、输出 token 数量。尽管输入 token 数量是由用户提供的，仍然需要进行计算在对于 computeSwapStep 的一次调用中可以处理多少用户提供的 token。

```solidity
bool zeroForOne = sqrtPriceCurrentX96 >= sqrtPriceTargetX96;

sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
    sqrtRatioCurrentX96,
    liquidity,
    amountRemainingLessFee,
    zeroForOne
);

```

通过检查价格大小来确认交易的方向。知道交易方向后，就可以计算交易 amountRemaining 数量 token 之后的价格。

找到新的价格后，根据之前已有的函数能够计算出输入和输出的数量：

```solidity

amountIn = zeroForOne
    ? SqrtPriceMath.getAmount0Delta(
        sqrtRatioTargetX96,
        sqrtRatioCurrentX96,
        liquidity,
        true
    )
    : SqrtPriceMath.getAmount1Delta(
        sqrtRatioCurrentX96,
        sqrtRatioTargetX96,
        liquidity,
        true
    );
amountOut = zeroForOne
    ? SqrtPriceMath.getAmount1Delta(
        sqrtRatioTargetX96,
        sqrtRatioCurrentX96,
        liquidity,
        false
    )
    : SqrtPriceMath.getAmount0Delta(
        sqrtRatioCurrentX96,
        sqrtRatioTargetX96,
        liquidity,
        false
    );

```

到目前为止，已经能够沿着下一个初始化过的 tick 进行循环、填满用户指定的 amoutSpecified、计算输入和输出数量，并且找到新的价格和 tick。现在只需要去更新合约状态、将 token 发送给用户，并从用户处获得 token。

首先，我们设置新的价格和 tick。仅会在新的 tick 不同的时候进行更新，来节省 gas。

```solidity

(amount0, amount1) = zeroForOne == exactInput
    ? (
        amountSpecified - state.amountSpecifiedRemaining,
        state.amountCalculated
    )
    : (
        state.amountCalculated,
        amountSpecified - state.amountSpecifiedRemaining
    );

```

接下来，我们根据交易的方向来获得循环中计算出的对应数量。

```solidity

if (zeroForOne) {
    if (amount1 < 0) {
        IERC20(token1).transfer(recipient, uint256(-amount1));
        IERC20(token0).transferFrom(
            msg.sender,
            address(this),
            uint256(amount0)
        );
    }
} else {
    if (amount0 < 0) {
        IERC20(token0).transfer(recipient, uint256(-amount0));
        IERC20(token1).transferFrom(
            msg.sender,
            address(this),
            uint256(amount1)
        );
    }
}

```

**跨 tick 交易**

swap 函数会沿着已初始化的 tick（有流动性的 tick）循环，直到用户需求的数量被满足。在每次循环中，都会：

- 使用 tickBitmap.nextInitializedTickWithinOneWord 来找到下一个已初始化的 tick；
- 在现价和下一个已初始化的 tick 之间进行交易（使用 SwapMath.computeSwapStep）；
- 总是假设当前流动性足够满足这笔交易（也即交易后的价格总在现价与下一个 tick 对应的价格之间）

为了改进 SwapMath.computeSwapStep 函数，需要考虑以下几个场景：

- 当现价和下一个 tick 之间的流动性足够填满 amoutRemaining；
- 当这个区间不能填满 amoutRemaining。

在第一种情况中，交易会在当前区间中全部完成——这是已经实现的部分。在第二个场景中，我们会消耗掉当前区间所有流动性，并且移动到下一个区间（如果存在的话）。考虑到这点，我们来重新实现 computeSwapStep：

```solidity
// src/lib/SwapMath.sol
function computeSwapStep(...) {
    ...
    amountIn = zeroForOne
        ? SqrtPriceMath.getAmount0Delta(
            sqrtRatioTargetX96,
            sqrtRatioCurrentX96,
            liquidity,
            true
        )
        : SqrtPriceMath.getAmount1Delta(
            sqrtRatioCurrentX96,
            sqrtRatioTargetX96,
            liquidity,
            true
        );

    if (amountRemainingLessFee >= amountIn) {
        sqrtRatioNextX96 = sqrtRatioTargetX96;
    } else {
        sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
            sqrtRatioCurrentX96,
            liquidity,
            amountRemainingLessFee,
            zeroForOne
        );
    }

```

首先，计算 amountIn——当前区间可以满足的输入数量。如果它比 amountRemaining 要小，我们会说现在的区间不能满足整个交易，因此下一个 $\sqrt p$ 就会是当前区间的上界/下界（换句话说，我们使用了整个区间的流动性）。如果 amountIn 大于 amountRemaining，我们计算 sqrtPriceNextX96——一个仍然在现在区间内的价格。

现在，在 swap 函数中，我们会处理我们在前一部分中提到的场景：当价格移动到了当前区间的边界处。此时，我们希望使得我们离开的当前区间休眠，并激活下一个区间。并且我们会开始下一个循环并且寻找下一个有流动性的 tick。

我们会在循环的尾部加这些：

```solidity

    if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
        if (step.initialized) {

            int128 liquidityNet = ticks.cross(
                step.tickNext,
                zeroForOne
                    ? state.feeGrowthGlobalX128
                    : feeGrowthGlobal0X128,
                zeroForOne
                    ? feeGrowthGlobal1X128
                    : state.feeGrowthGlobalX128

            );


            if (zeroForOne) {
                liquidityNet = -liquidityNet;
            }

            state.liquidity = liquidityNet < 0
                ? state.liquidity - uint128(-liquidityNet)
                : state.liquidity + uint128(liquidityNet);
        }

        state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
    } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {

        state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
    }

```

第二个分支是之前实现的——处理了交易仍然停留在当前区间的情况。所以主要关注第一个分支。

state.sqrtPriceX96 是新的现价，即在上一个交易过后会被设置的价格；step.sqrtNextX96 是下一个已初始化的 tick 对应的价格。如果它们相等，说明我们达到了这个区间的边界。正如之前所说，此时需要更新 L（添加或移除流动性）并且使用这个边界 tick 作为现在的 tick，继续这笔交易。

通常来说，穿过一个 tick 是指从左到右穿过。因此，穿过一个下界 tick 或增加流动性，穿过一个上界 tick 会减少流动性。然而如果 zeroForOne 被设置为 true，我们会把符号反过来：当价格下降时，上界 tick 会增加流动性，下界 tick 会减少流动性。

当更新 state.tick 时，如果价格是下降的（zeroForOne 设置为 true），需要将 tick 减一来走到下一个区间；而当价格上升时（zeroForOne 为 false），根据 TickBitmap.nextInitializedTickWithinOneWord，已经走到了下一个区间了。

另一个重要的改动是，需要在跨过 tick 时更新流动性。全局的更新是在循环之后：

```solidity

if (cache.liquidityStart != state.liquidity) {
    liquidity = state.liquidity;
}

```

在区间内，在进入/离开区间时多次更新 state.liquidity。交易后，需要更新全局的 L 来反应现价可用的流动性，同时避免多次写合约状态而消耗 gas。

**流动性跟踪以及 tick 的跨域**

首先要更改的是 Tick.Info 结构体：我需要两个变量来跟踪 tick 的流动性：

```solidity
struct Info {
    uint128 liquidityGross; // tick 的总流动性
    int128 liquidityNet; // 该 tick active 是要增加或减少的流动性
    uint256 feeGrowthOutside0X128; // fee 相关
    uint256 feeGrowthOutside1X128;
    bool initialized;
}
```

liquidityGross 跟踪一个 tick 拥有的绝对流动性数量。它用来跟踪一个 tick 是否还可用。liquidityNet，是一个有符号整数，用来跟踪当跨越 tick 时添加/移除的流动性数量。

liquidityNet 在 update 函数中设置:

```solidity
function update(
   ...
) internal returns (bool flipped) {
    ...

    info.liquidityNet = upper
        ? info.liquidityNet - liquidityDelta
        : info.liquidityNet + liquidityDelta;
}

```

cross 函数的功能也就是返回 liquidityNet：

```solidity
function cross(
    mapping(int24 => Info) storage self, // 存储 current tick 的信息
    int24 tick,
    uint256 feeGrowthGlobal0X128, // fee
    uint256 feeGrowthGlobal1X128
) internal returns (int128 liquidityNet) {
    // 返回 liquidityNet 用于更新当前 liquidity
    Info storage info = self[tick];

```

## 交易费率 （Swap Fees）

为了让费用计算更简单，Pool 跟踪一个单位的流动性产生的总费用。之后，价格区间的费用通过总费用计算出来：用总费用减去价格区间之外累计的费用。而在一个价格区间之外累积的费用是当一个 tick 被穿过时追踪的（当交易移动价格时，tick 被穿过；费用在交易中累计）。

- 用户交易 token 的时候支付费用。输入 token 中的一小部分将会被减去，并累积到池子的余额中。
- 每个池子都有 feeGrowthGlobal0X128 和 feeGrowthGlobal1X128 两个状态变量，来跟踪每单位的流动性累计的总费用（也即，总的费用除以池子流动性）。
- 注意到，此时实际的位置信息并没有更新，以便于节省 gas。
- tick 跟踪在它之外累积的费用。当添加一个新的位置并激活一个 tick 的时候（添加流动性到一个之前是空着的 tick），这个 tick 记录在它之外累计的费用（惯例来说，我们假设之前所有积累的费用都 低于这个 tick）。
- 每当一个 tick 被激活时，在这个 tick 之外积累的费用就会更新为，在这个 tick 之外积累的总费用减去上一次被穿过时这个 tick 记录的费用。
- tick 知道了在他之外累积了多少费用，就可以让我们计算出在一个 position 内部累积了多少费用（position 就是两个 tick 之间的区间）。
- 知道了一个 position 内部累积了多少费用，我们就能够计算 LP 能够分成到多少费用。如果一个 position 没有参与到交易中，它的累计费率会是 0，在这个区间提供流动性的 LP 将不会获得任何利润。

**计算 Position 累积费用**

为了计算一个 position 累计的总费用，需要考虑两种情况：当现价在这个区间内或者现价在区间外。在两种情况中，我们都会从总价中减去区间下界和上界之外累积的费用来获得结果。但是根据现价情况的不同，我们对于这些费用的计算方法也不同。

当现价在这个区间内，我们减去到目前为止，这些 tick 之外累积的费用：

![fees_inside_and_outside_price_range](./img/fees_inside_and_outside_price_range.png)

当现价在区间之外，需要在减去上下界之外的费用之前先对它们进行更新。仅仅在计算中更新它们，而不会覆盖它们，因为这些 tick 还没有被穿过。

tick 之外累计的费用更新如下：

$$
f_o(i) = f_g - f_o(i)
$$

在 tick 之外收集的费用 $(f_o(i))$ 是总费用 (f_g) 与上一次这个 tick 被穿过时累计的费用之差。约等于我们在 tick 被穿过时重置一下其计数器。

计算一个 position 内累积的费用：

$$
f_r = f_g - f_b(i_l) - f_a(i_u)
$$

从所有价格区间累积的总费用中，减去在下界之下累积的费用 $(f_b(i_l))$ 和在上界之上累计的费用 $(f_a(i_u))$。也即上面图中看到的计算方法。

现在，当现价高于区间下界时（即区间被激活时），我们不会更新低于下界的费用累积，仅仅从下界中读取这个数据；对上界也是同理。而在另外两种情况时，我们需要考虑更新费用：

当现价低于下界 tick，并考虑低于下界累积的费用时；
当现价高于上界 tick，并考虑高于上界累积的费用时。

### 累积交易费用

费率的单位是基点的百分之一，也即一个费率单位是 0.0001%，500 是 0.05%，3000 是 0.3%。

下一步是在池子中累积交易费用。为此我们要添加两个全局费用累积的变量：

```solidity
// src/Pool.sol
contract Pool is IPool {
    ...
    uint24 public immutable fee;
    uint256 public feeGrowthGlobal0X128;
    uint256 public feeGrowthGlobal1X128;
}

```

带 0 的那个跟踪 token0 累积的费用，带 1 的跟踪 token1 累积的费用。

**收集费用**
现在需要更新 SwapMath.computeSwapStep——这是我们计算交易数量的函数，同时也是我们计算和减去交易费用的地方。在这里，我们把所有的 amountRemaining 替换为 amountRemainingLessFee：

```soldiity
uint256 amountRemainingLessFee = FullMath.mulDiv(
    uint256(amountRemaining),
    1e6 - feePips,
    1e6
```

这样，就在输入的 token 中减去了交易费用，并且用这个小一点的结果计算输出数量。

这个函数现在也会返回在这一步中累计的交易费用——它的计算方法根据是否达到了区间的上界而有所不同：

```solidity
if (exactIn && sqrtRatioNextX96 != sqrtRatioTargetX96) {
feeAmount = uint256(amountRemaining) - amountIn;
} else {
// fee 公式的推导过程
// a = amountIn
// f = feePips
// x = a + fee = a + x * f
// fee = x * f = a * f / (1- f)
feeAmount = FullMath.mulDivRoundingUp(
    amountIn,
    feePips,
    1e6 - feePips
);
}
```

如果没有达到上界，现在的价格区间有足够的流动性来填满交易，因此我们只需要返回填满交易所需数量与实际数量之间的差即可。注意到，这里没有使用 amountRemainingLessFee，因为实际上的费用已经在重新计算 amountIn 的过程中考虑过了（译者注：此处建议参考对应代码片段更清晰）。

当目标价格已经达到，我们不能从整个 amountRemaining 中减去费用，因为现在价格区间的流动性不足以完成交易。因此，在这里的费用仅考虑这个价格区间实际满足的交易数量（amountIn）。

在 SwapMath.computeSwapStep 返回值后，我们需要更新这步交易累计的费用。注意到仅仅有一个变量来跟踪数值，这是因为当关注一笔交易的时候，我们已经知道了输入 token 是 token0 还是 token1（而不会是两者均有）：

```solidity
SwapState memory state = SwapState({
    amountSpecifiedRemaining: amountSpecified,
    amountCalculated: 0,
    sqrtPriceX96: slot0Start.sqrtPriceX96, // 当前价格
    tick: slot0Start.tick,
    feeGrowthGlobalX128: zeroForOne
        ? feeGrowthGlobal0X128 // 跟踪 fee 的状态变量
        : feeGrowthGlobal1X128,
    liquidity: cache.liquidityStart
});

(...) = SwapMath.computeSwapStep(...);

state.feeGrowthGlobalX128 += FullMath.mulDiv(
    step.feeAmount,
    FixedPoint128.Q128,
    state.liquidity
);
```

这里我们用费用除以流动性的数量，为了让后面在 LP 之间分配利润更加公平。

**在 tick 中更新费用追踪器**
接下来，需要在 tick 中更新费用追踪器（当交易中穿过一个 tick 时）：

由于此时还没有更新 feeGrowthGlobal0X128/feeGrowthGlobal1X128 状态变量，我们把 state.feeGrowthGlobalX128 作为其中一个参数传入。cross 函数更新费用追踪器：

```solidity
// src/lib/Tick.sol
function cross(
    mapping(int24 => Info) storage self, // 存储 current tick 的信息
    int24 tick,
    uint256 feeGrowthGlobal0X128, // fee
    uint256 feeGrowthGlobal1X128
) internal returns (int128 liquidityNet) {
    // 返回 liquidityNet 用于更新当前 liquidity
    Info storage info = self[tick];

    // tick cross 的时候要更新 fee
    unchecked {
        info.feeGrowthOutside0X128 =
            feeGrowthGlobal0X128 -
            info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 =
            feeGrowthGlobal1X128 -
            info.feeGrowthOutside1X128;
        liquidityNet = info.liquidityNet;
    }
}
```

**更新全局费用追踪器**
最后一步，当交易完成时，需要更新全局的费用追踪：

```solidity
if (zeroForOne) {
    // tokenIn 是 token0
    feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
} else {
    // 否则 tokenIn 是 token1
    feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
}
```

同样地，在一笔交易中只有一个变量会更新，因为交易费仅从输入 token 中收取。

### Position 中的费用

当添加或移除流动性的时候，也需要初始化或者更新费用。费用在 tick 中（在 tick 之外累计的数量，feeGrowthOutside）和在 position 中（position 内部累积的费用）都需要进行跟踪。在 position 中，我们也需要跟踪和更新收集的费用数量——或者换句话说，我们把每单位流动性的费用转换成 token 数量。因为当 LP 移除流动性的时候，它们需要获得一定数量的交易费用。

我们来一步一步完成它。

**tick 中费用追踪器的初始化**
在 Tick.update 函数中，当一个 tick 被初始化时（添加流动性到一个空的 tick），我们初始化它的费用追踪器。然而，我们仅当 tick 低于现价的时候做这件事，也即当现价在现在价格区间内时：

```solidity
// src/lib/Tick.sol
function update(
mapping(int24 => Tick.Info) storage self,
int24 tick,
int24 tickCurrent,
int128 liquidityDelta,
uint256 feeGrowthGlobal0X128,
uint256 feeGrowthGlobal1X128,
bool upper，
uint128 maxLiquidity
) internal returns (bool flipped) {
...
if (liquidityGrossBefore == 0) {
    if (tick <= tickCurrent) {
        info.feeGrowthOutside0X128 = feeGrowthGlobalOX128;
        info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
    }
    info.initialized = true;
}
    ...

}
```

如果现价不在价格区间内，费用追踪器将被设置为 0，并且会在下一次这个 tick 被穿过时进行更新（参考上面写的 cross 函数）。

**更新 position 费用和 token 数量**
下一步是计算 position 累计的费用和 token 数量。由于一个 position 就是两个 tick 之间的一个区间，使用 tick 中的费用追踪器来计算这些值：

```solidity
// src/lib/Tick.sol
function getFeeGrowthInside(
    mapping(int24 => Info) storage self,
    int24 tickLower,
    int24 tickUpper,
    int24 tickCurrent,
    uint256 feeGrowthGlobal0X128,
    uint256 feeGrowthGlobal1X128
)
    internal
    view
    returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
{
    Info storage lower = self[tickLower];
    Info storage upper = self[tickUpper];

    // 计算费用增长（uniswapV3 里 fee 增长可以是负数， 所以处理 uint256 时可以溢出或下溢）
    unchecked {
        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (tickLower <= tickCurrent) {
            feeGrowthBelow0X128 = lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lower.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 =
                feeGrowthGlobal0X128 -
                lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 =
                feeGrowthGlobal1X128 -
                lower.feeGrowthOutside1X128;
        }

        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
        if (tickCurrent < tickUpper) {
            feeGrowthAbove0X128 = upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upper.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0X128 =
                feeGrowthGlobal0X128 -
                lower.feeGrowthOutside0X128;
            feeGrowthAbove1X128 =
                feeGrowthGlobal1X128 -
                lower.feeGrowthOutside1X128;
        }

        feeGrowthInside0X128 =
            feeGrowthGlobal0X128 -
            feeGrowthBelow0X128 -
            feeGrowthAbove0X128;
        feeGrowthInside1X128 =
            feeGrowthGlobal1X128 -
            feeGrowthBelow1X128 -
            feeGrowthAbove1X128;
    }
```

这里我们计算两个 tick 之间累计的费用。首先计算低于下界 tick 的费用，然后是高于上界 tick 的费用。在最后，把这些费用从全局积累的费用中减去。这正是之前看到的公式：

$$
f_r = f_g - f_b(i_l) - f_a(i_u)
$$

当计算在某个 tick 之上/之下累积的费用时，根据当前价格区间是否被激活（现价是否在价格区间内）来进行不同操作。当它处于活跃状态，只需要使用当前 tick 的费用追踪器的值；当它处于停用状态，需要使用 tick 更新后的费用——你可以在上面代码里两个 else 分支的计算中看到。

得到 position 内累积的费用后，可以更新 position 内的费用和数量追踪器了：

```solidity
// src/lib/Position.sol
function update(
    Info storage self,
    int128 liquidityDelta,
    uint256 feeGrowthInside0X128,
    uint256 feeGrowthInside1X128
) internal {
    Info memory _self = self;

    if (liquidityDelta == 0) {
        require(_self.liquidity > 0, "0 liquidity");
    }

    uint128 tokensOwed0 = uint128(
        FullMath.mulDiv(
        // latest feeGrowthInsideOX128 - previousfeeGrowthInside0X128
            feeGrowthInside0X128 - _self.feeGrowthInside0LastX128,
            _self.liquidity,
            FixedPoint128.Q128
        )
    );

    uint128 tokensOwed1 = uint128(
        FullMath.mulDiv(
            feeGrowthInside1X128 - _self.feeGrowthInside1LastX128,
            _self.liquidity,
            FixedPoint128.Q128
        )
    );

    if (liquidityDelta != 0) {
        self.liquidity = liquidityDelta < 0
            ? _self.liquidity - uint128(-liquidityDelta)
            : _self.liquidity + uint128(liquidityDelta);
    }

    // 更新 position tokens owed
    if (tokensOwed0 > 0 || tokensOwed1 > 0) {
        self.tokensOwed0 += tokensOwed0;
        self.tokensOwed1 += tokensOwed1;
    }
}
```

当计算应得的 token 时，把费用乘以区间的流动性——与在交易时所作的相反。在最后，更新费用追踪器，并把 token 数量加到之前的数量上。

现在，每当一个 position 发生变动（添加或移除流动性），计算这个区间收集的费用并且更新 position 信息：

```solidity
// src/Pool.sol
function _updatePosition(...) {
...

uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128;
uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128;

...

(uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = ticks
    .getFeeGrowthInside(
        tickLower,
        tickUpper,
        tick,
        _feeGrowthGlobal0X128,
        _feeGrowthGlobal1X128
    );

position.update(
    liquidityDelta,
    feeGrowthInside0X128,
    feeGrowthInside1X128
);
    ...

}

```

就是这样, 我们的池子实现现在已经完成了 🎉
