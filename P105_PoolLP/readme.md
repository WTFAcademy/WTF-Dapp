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

首先，我们参考 [Uniswap V3 的代码](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol#L466)来写一个 `_modifyPosition` 的方法，这是一个 `priviate` 的函数，只有合约内部可以调用，在该方法中修改交易池整体的流动性 `liquidity` 并计算返回 `amount0` 和 `amount1`。

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

在代码中，我们引入了 Uniswap V3 代码中的 [TransferHelper](https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TransferHelper.sol) 库来做转账，将 token 发送给传入的 `recipient` 地址。至此，基础的逻辑就实现完成了。

## 合约测试

接下来，我们补充一些单元测试。因为创建 `Pool` 需要对应一个交易对，所以我们先创建一个满足 `ERC20` 规范的代币合约。关于 `ERC20` 规范，你可以参考[这篇文章](https://github.com/AmazingAng/WTF-Solidity/blob/main/31_ERC20/readme.md)。

我们在 `demo-contract/contracts/wtfswap` 中新建一个 `test-contracts/TestToken.sol` 的文件，内容如下：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    uint256 private _nextTokenId = 0;

    constructor() ERC20("TestToken", "TK") {}

    function mint(address recipient, uint256 quantity) public payable {
        _mint(recipient, quantity);
    }
}
```

具体的合约代码你可以参考[这里](../demo-contract/contracts/wtfswap/test-contracts/TestToken.sol)，这个合约我们实现了一个可以随意 mint 的代币合约，用于测试。

接着，我们新建 `demo-contract/test/wtfswap/Pool.test.js` 文件，编写测试代码：

```ts
import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { getSqrtPriceX96 } from "./utils";

describe("Pool", function () {
  async function deployFixture() {
    const factory = await hre.viem.deployContract("Factory");
    const token0 = await hre.viem.deployContract("TestToken");
    const token1 = await hre.viem.deployContract("TestToken");
    const tickLower = -100000;
    const tickUpper = 100000;
    const fee = 3000;
    const publicClient = await hre.viem.getPublicClient();
    await factory.write.createPool([
      token0.address,
      token1.address,
      tickLower,
      tickUpper,
      fee,
    ]);
    const createEvents = await factory.getEvents.PoolCreated();
    const poolAddress: `0x${string}` = createEvents[0].args.pool || "0x";
    const pool = await hre.viem.getContractAt("Pool" as string, poolAddress);

    const price = 2000;
    const sqrtPriceX96: bigint = getSqrtPriceX96(price); // => 3961408125713216879677197516800n

    await pool.write.initialize([sqrtPriceX96]);

    return {
      token0,
      token1,
      factory,
      pool,
      publicClient,
      tickLower,
      tickUpper,
      fee,
      sqrtPriceX96,
      price,
    };
  }

  it("pool info", async function () {
    const { pool, token0, token1, tickLower, tickUpper, fee, sqrtPriceX96 } =
      await loadFixture(deployFixture);

    expect(((await pool.read.token0()) as string).toLocaleLowerCase()).to.equal(
      token0.address
    );
    expect(((await pool.read.token1()) as string).toLocaleLowerCase()).to.equal(
      token1.address
    );
    expect(await pool.read.tickLower()).to.equal(tickLower);
    expect(await pool.read.tickUpper()).to.equal(tickUpper);
    expect(await pool.read.fee()).to.equal(fee);
    expect(await pool.read.sqrtPriceX96()).to.equal(sqrtPriceX96);
  });
});
```

我们部署了一个 `Factory` 和两个 `TestToken` 代币合约，然后创建了一个 `Pool` 合约，初始化了价格，然后测试了一下 `Pool` 合约的基本信息。另外我们新建了一个 `utils.ts` 文件，用来计算 `sqrtPriceX96`，代码如下：

```ts
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
```

你还需要在项目中使用 `npm install bignumber.js` 安装需要的 `bignumber.js` 依赖。

接下来我们可以继续编写更多的测试样例，比如我们添加下面的样例测试 mint 流动性，然后检查代币的转移是否正确。

```ts
it("mint and burn and collect", async function () {
  const { pool, token0, token1, price } = await loadFixture(deployFixture);
  const testLP = await hre.viem.deployContract("TestLP");

  const initBalanceValue = 1000n * 10n ** 18n;
  await token0.write.mint([testLP.address, initBalanceValue]);
  await token1.write.mint([testLP.address, initBalanceValue]);

  await testLP.write.mint([
    testLP.address,
    20000000n,
    pool.address,
    token0.address,
    token1.address,
  ]);

  expect(await token0.read.balanceOf([pool.address])).to.equal(
    initBalanceValue - (await token0.read.balanceOf([testLP.address]))
  );
  expect(await token1.read.balanceOf([pool.address])).to.equal(
    initBalanceValue - (await token1.read.balanceOf([testLP.address]))
  );

  const position = await pool.read.positions([testLP.address]);
  expect(position).to.deep.equal([20000000n, 0n, 0n]);
  expect(await pool.read.liquidity()).to.equal(20000000n);
});
```

因为 `Pool` 的合约需要通过回调函数来处理代币的转移，所以我们需要新增一个测试 `TestLP` 合约，这个合约需要实现 `IMintCallback` 接口，具体代码如下：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "../interfaces/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestLP is IMintCallback {
    function mint(
        address recipient,
        uint128 amount,
        address pool,
        address token0,
        address token1
    ) external returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = IPool(pool).mint(
            recipient,
            amount,
            abi.encode(token0, token1)
        );
    }

    function burn(
        uint128 amount,
        address pool
    ) external returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = IPool(pool).burn(amount);
    }

    function collect(
        address recipient,
        address pool
    ) external returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = IPool(pool).collect(recipient);
    }

    function mintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        // transfer token
        (address token0, address token1) = abi.decode(data, (address, address));
        if (amount0Owed > 0) {
            IERC20(token0).transfer(msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            IERC20(token1).transfer(msg.sender, amount1Owed);
        }
    }
}
```

你还需要注意的是，因为流动性到代币的计算基于一个相对复杂的公式，中间还涉及到计算时取整的问题。在我们的单测中只是简单的测试了一些基础的逻辑，实际上你需要更多的测试用例来覆盖更多的情况，以及测试具体的数学运算的逻辑是否正确。

更多的测试代码你可以在 [demo-contract/test/wtfswap/Pool.ts](../demo-contract/test/wtfswap/Pool.ts) 找到。至此，我们就完成了 `Pool` 合约中的 `LP` 相关接口开发，在下一讲中我们将会补充 `swap` 接口，并添加手续费相关逻辑，完成整个 `Pool` 合约的开发。
