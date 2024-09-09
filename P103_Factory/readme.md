这一讲我们将引导大家完成 `Factory.sol` 合约的开发。

---

## 合约简介

在我们的课程设计中 `PoolManager` 合约继承了 `Factory` 合约，在 Solidity 智能合约的开发中，这样的继承更多只是为了代码的组织，最终合约发布到链上后只会有一个合约。理论上来说，我们在开发的时候也可以把 `Factory` 合约和 `PoolManager` 写到一个 `.sol` 文件中，但是为了代码的可读性和可维护性，我们还是选择了继承的方式。

另外 `Factory` 合约主要参考了 [UniswapV3Factory.sol](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Factory.sol) 的设计，它是必须的。而 `PoolManager` 合约中的逻辑只是为了给 DApp 提供获取所有交易池信息的接口，这样的接口可以通过服务端来提供，它并不是必须的。

入下图所示：

![Factory](./img/Factory.png)

`Factory` 合约的主要功能是创建交易池（`Pool`），WTFSwap 部署后会得到一个 `Factory` 合约（也是 `PoolManager` 合约，它继承了 `Factory`），而不同的交易对包括相同交易对只要价格上下限和手续费不同就会创建一个新的交易池。而 `Factory` 合约则是主要用来创建 `Pool` 合约的。通过这一讲课程，你可以学习到如何通过合约创建合约，以及接触到我们之前基础课程中简单学习过的合约事件的开发，以及其他 Solidity 中的一些新的语法。

## 合约开发

### 1. 创建交易池

在之前的[课程](../P102_InitContracts/readme.md)中，我们已经创建了一个 `mapping`，（如果你还没有创建，那可以现在在 `Pool.sol` 中加入这一行）：

```solidity
  mapping(address => mapping(address => address[])) public pools;
```

接下来我们完善 `createPool` 方法，创建一个合约并将它的地址填充到 `pools` 中：

```solidity
function sortToken(
    address tokenA,
    address tokenB
) private pure returns (address, address) {
    return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
}

function createPool(
    address tokenA,
    address tokenB,
    int24 tickLower,
    int24 tickUpper,
    uint24 fee
) external override returns (address pool) {
    // validate token's individuality
    require(tokenA != tokenB, "IDENTICAL_ADDRESSES");

    // Declare token0 and token1
    address token0;
    address token1;

    // sort token, avoid the mistake of the order
    (token0, token1) = sortToken(tokenA, tokenB);

    // save pool info
    parameters = Parameters(
        address(this),
        tokenA,
        tokenB,
        tickLower,
        tickUpper,
        fee
    );

    // generate create2 salt
    bytes32 salt = keccak256(
        abi.encode(token0, token1, tickLower, tickUpper, fee)
    );

    // create pool
    pool = address(new Pool{salt: salt}());

    // save created pool
    pools[token0][token1].push(pool);

    // delete pool info
    delete parameters;
}
```

需要注意的是，你需要在头部引入 `Pool` 合约：

```solidity
import "./Pool.sol";
```

你可以看到，我们通过 `pool = address(new Pool{salt: salt}());` 这一行代码创建了一个新的 `Pool` 合约，并通过 `pools[token0][token1].push(pool);` 将它的地址保存到 `pools` 中。

这里需要注意的是，我们通过添加了 `salt` 来使用 [CREATE2](https://github.com/AmazingAng/WTF-Solidity/blob/main/25_Create2/readme.md) 的方式来创建合约，这样的好处是创建出来的合约地址是可预测的，地址生成的逻辑是 `新地址 = hash("0xFF",创建者地址, salt, initcode)`。

而在我们的代码中 `salt` 是通过 `abi.encode(token0, token1, tickLower, tickUpper, fee)` 计算出来的，这样的好处是只要我们知道了 `token0` 和 `token1` 的地址，以及 `tickLower`、`tickUpper` 和 `fee` 这三个参数，我们就可以预测出来新合约的地址。在我们的教程设计中，这样似乎并没有什么用。但是在实际的 DeFi 场景中，这样会带来很多好处。比如其他合约可以直接计算出我们 `Pool` 合约的地址，这样可以开发出和 `Pool` 合约交互的更多的功能。

当然，这样也会带来一个问题，这样会使得我们不能通过合约的构造函数传参来传递 `Pool` 合约的初始化参数，因为那样会导致上面新地址计算中的 `initcode` 发生变化。所以我们在代码中引入了 `parameters` 这个变量来保存 `Pool` 合约的初始化参数，这样我们就可以在 `Pool` 合约中通过 `parameters` 来获取到初始化参数。这一点我们会在后面的 `Pool` 合约课程中更具体的展开。

### 2. 创建前先检查交易池是否已经存在

我们在 `createPool` 中补充一段代码，用来检查交易池是否已经存在，你可以通过 `IPool` 接口来通过交易池的合约地址来获取交易池的信息：

```solidity

// get current all pools
address[] memory existingPools = pools[token0][token1];

// check if the pool already exists
for (uint256 i = 0; i < existingPools.length; i++) {
    IPool currentPool = IPool(existingPools[i]);

    if (
        currentPool.tickLower() == tickLower &&
        currentPool.tickUpper() == tickUpper &&
        currentPool.fee() == fee
    ) {
        return existingPools[i];
    }
}

```

在 [Uniswap V3](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Factory.sol#L45C9-L45C61) 的代码中是通过 `require(getPool[token0][token1][fee] == address(0));` 检查的，但是因为我们的课程设计中，每个交易对都有一个价格上下限，所以我们需要用一个数组来存放一个交易对下的所有可能有的交易池，然后通过循环来检查是否已经存在。

当然，**在智能合约的开发中，你应该尽量的避免类似这样的循环存在**，因为这样会使得合约的 gas 费用增加。那针对这个需求，是不是有更好的方案呢？你可以做一下思考，我们会在后续的合约优化的章节中展开。需要注意的是，在合约的开发过程中，合约的优化应该是开发人员应该有的意识，要让你的合约可以更高效，更安全的运行在链上。本课程因为是教学性质，加上作者水平有限，难免有所疏漏，代码请勿直接用在生产环境。如果你有任何更好的建议，也欢迎通过提交 ISSUE 或者 Pull Request 告诉我们，一起完善课程。

### 3. 事件

最后我们补充一个事件，用来通知 DApp 交易池已经创建：

```solidity
emit PoolCreated(
    token0,
    token1,
    uint32(existingPools.length),
    tickLower,
    tickUpper,
    fee,
    pool
);
```

另外需要注意的是，虽然我们在 `createPool` 函数中返回了 `pool` 的地址，但是涉及到合约写操作的方法，只有在交易被打包到区块中后才算真正的创建成功，所以在 DApp 中你需要通过事件来监听交易池的创建，而无法通过读取返回值来判断是否创建成功。返回值通常只是在模拟交易的时候可能会用到。

### 4. 获取交易池

最后我们再补充一下 `getPool` 方法，该方法未来会在 `SwapRouter` 合约中被用到：

```solidity
function getPool(
    address tokenA,
    address tokenB,
    uint32 index
) external view override returns (address) {
    require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
    require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");

    // Declare token0 and token1
    address token0;
    address token1;

    (token0, token1) = sortToken(tokenA, tokenB);

    return pools[tokenA][tokenB][index];
}
```

## 合约测试

在做端到端的测试前，我们应该尽量的通过尽可能完善的单元测试来保证合约的逻辑正确，合约的安全是非常重要的，因为合约一旦发布就无法更改逻辑，任何编码上的错误都可能带来灾难性的后果。

Hardhat 内置了单元测试的方案，我们在 `test` 目录下新建 `wtfswap/Factory.ts` 文件：

```ts
import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("Factory", function () {
  async function deployFixture() {
    const factory = await hre.viem.deployContract("Factory");
    const publicClient = await hre.viem.getPublicClient();
    return {
      factory,
      publicClient,
    };
  }

  it("createPool", async function () {
    const { factory, publicClient } = await loadFixture(deployFixture);
    const tokenA: `0x${string}` = "0xEcd0D12E21805803f70de03B72B1C162dB0898d9";
    const tokenB: `0x${string}` = "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984";

    const hash = await factory.write.createPool([
      tokenA,
      tokenB,
      1,
      100000,
      3000,
    ]);
    await publicClient.waitForTransactionReceipt({ hash });
    const createEvents = await factory.getEvents.PoolCreated();
    expect(createEvents).to.have.lengthOf(1);
    expect(createEvents[0].args.pool).to.match(/^0x[a-fA-F0-9]{40}$/);
    expect(createEvents[0].args.token0).to.equal(tokenB);
    expect(createEvents[0].args.token1).to.equal(tokenA);
    expect(createEvents[0].args.tickLower).to.equal(1);
    expect(createEvents[0].args.tickUpper).to.equal(100000);
    expect(createEvents[0].args.fee).to.equal(3000);
  });
});
```

在这个测试中，我们调用了 `createPool` 方法，然后通过 `getEvents` 来获取事件，来判断是否创建成功。

在上面我们提到，函数返回值只有在交易被打包到区块中后才算真正的创建成功，所以在测试中我们通过 `waitForTransactionReceipt` 来等待交易被打包到区块中。你也可以通过 `factory.simulate.createPool` 方法来做模拟交易，用来校验函数的返回值：

```ts
// simulate for test return address
const poolAddress = await factory.simulate.createPool([
  tokenA,
  tokenB,
  1,
  100000,
  3000,
]);
expect(poolAddress.result).to.match(/^0x[a-fA-F0-9]{40}$/);
expect(poolAddress.result).to.equal(createEvents[0].args.pool);
```

再补充一个异常状态的测试样例：

```ts
it("createPool with same token", async function () {
  const { factory } = await loadFixture(deployFixture);
  const tokenA: `0x${string}` = "0xEcd0D12E21805803f70de03B72B1C162dB0898d9";
  const tokenB: `0x${string}` = "0xEcd0D12E21805803f70de03B72B1C162dB0898d9";
  await expect(
    factory.write.createPool([tokenA, tokenB, 1, 100000, 3000])
  ).to.be.rejectedWith("IDENTICAL_ADDRESSES");

  await expect(factory.read.getPool([tokenA, tokenB, 3])).to.be.rejectedWith(
    "IDENTICAL_ADDRESSES"
  );
});
```

完整的单测代码在 [test/wtfswap/Factory.ts](../demo-contract/test/wtfswap/Factory.ts) 中，在实际项目中，你的单测应该覆盖到所有的逻辑分支，以保证合约的安全。
