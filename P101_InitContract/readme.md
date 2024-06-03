这一讲将会设计整体合约的结构，定义各个合约的接口，并做初步的技术分析。

---

## 合约需求描述

wtfswap 设计 token 价格在一个合理范围内，当脱离范围时会触发单向费率机制，把价格拉回合理范围
1. 任何人都可以创建池子，创建池子可以指定当前价格、价格范围： [a, b] 和 费率 f；相同交易对和费率的池子不能重复创建；不能删除和修改池子；
2. 任何人都可以添加流动性，添加流动性可以选择三个范围： （0，a)、 [a, b] 和 (b, +∞)；
3. 流动性提供者可以减少全部添加的流动性，并提取减少流动性对应的两种代币；
4. 流动性提供者可以在任何人 swap 过程收取手续费，规则如下：
	a. 当价格在 [a, b]，买卖手续费都是 f，按流动性贡献加权平分给 [a, b] 流动性提供者；
	b. 当价格在 （0，a)，买手续费 0.5f，卖手续费 2f，按流动性贡献加权平分给 (0，a) 流动性提供者；
	c. 当价格在  (b, +∞)，买手续费 2f，卖手续费 0.5f，按流动性贡献加权平分给  (b, +∞) 流动性提供者。
5. 任何人都可以 swap，swap 需要指定某个池子，swap 可以指定输入（最大化输出）或者指定输出（最小化输入）。

以上手续费的收取方式和 Uniswap 有所差异，做了简化，会在后续手续费实现的章节继续展开说明。

## 合约结构

以简单为原则，我们不按照 Uniswap V3 将合约分为 `periphery` 和 `core` 两个独立仓库，而是自顶向下分为以下四个合约。

- `PoolManager.sol`: 顶层合约，对应 Pool 页面，负责 Pool 的创建和管理；
- `PositionManager.sol`: 顶层合约，对应 Position 页面，负责 LP 头寸和流动性的管理；
- `SwapRouter.sol`: 顶层合约，对应 Swap 页面，负责预估价格和交易；
- `Factory.sol`: 底层合约，Pool 的工厂合约；
- `Pool.sol`: 最底层合约，对应一个交易池，记录了当前价格、头寸、流动性等信息。                       

## 合约接口设计

因为我们是自顶向下设计合约，因此我们首先分析前端页面（Pool 页面、Position 页面和 Swap 页面）需要哪些功能，并为此设计出顶层合约，再进一步分析细节，设计出底层合约。

#### PoolManager

`PoolManager.sol` 对应 Pool 页面，我们首先来看 Pool 页面有哪些功能

首先是展示所有的 pool ，对应前端页面如下：

![pool](../P003_OverallDesign/img/pool.png)

由于相同交易对和费率的池子不能重复创建，我们可以先定义一个 `PoolKey` 的结构，并定义出返回所有 pool 的方法 `getPools`，接口定义如下：

```solidity
struct PoolKey {
    address token0;
    address token1;
    uint24 fee;
}

function getPools() external view returns (PoolKey[] memory pools);
```

每个 pool 的信息包括：

- token 对的符号以及数量；
- 费率；
- 价格范围；
- 当前价格；
- 三个区间的总流动性（TODO: 图中没有）。

我们可以根据以上信息定义出 `PoolInfo`，以及获取 `PoolInfo` 的方法 `getPoolInfo`，接口定义如下：

```solidity
struct PoolInfo {
    // the current protocol fee as a percentage of the swap fee taken on withdrawal
    // represented as an integer denominator (1/x)%
    uint8 feeProtocol;
    // tick range
    int24 tickLower;
    int24 tickUpper;
    // the current tick
    int24 tick;
    // the current price
    uint160 sqrtPriceX96;
}

function getPoolInfo(
    address token0,
    address token1,
    uint24 fee
) external view returns (PoolInfo memory poolInfo);
```

此外还有一个添加池子的操作（TODO: 池子不能 remove），点击弹出以下页面：

![add](../P003_OverallDesign/img/add.png)

参数包括：

- token0 的地址和数量；
- token1 的地址和数量；
- 费率（百分比）；
- 价格范围；
- 当前价格。

token0 的数量不为 0 或 token1 的数量不为 0 意味着添加初始流动性。

接口定义如下：

```solidity
struct CreateAndInitializeParams {
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint160 sqrtPriceX96;
}

function createAndInitializePoolIfNecessary(
    CreateAndInitializeParams calldata params
) external payable returns (address pool);
```

完整的接口在 [IPoolManager](./code/interfaces/IPoolManager.sol) 中。

#### PositionManager

`PositionManager.sol` 对应 Position 页面，我们首先来看 Position 页面有哪些功能

首先是展示当前地址创建的头寸，对应前端页面如下：

TODO: 图片

可以通过用户地址返回所有其创建的头寸，定义 `getPositions` 方法，接口定义如下：

```solidity
function getPositions(
    address owner
) external view returns (uint256[] memory positionIds);
```

每个头寸的信息包括：

- token 对的符号以及数量（这里的数量是头寸拥有的两种代币数量）；
- 费率；
- 价格范围；
- 添加的流动性；
- 收取的两种代币的手续费。

我们可以根据以上信息定义出 `PositionInfo`，以及获取 `PositionInfo` 的方法 `getPositionInfo`，接口定义如下：

```solidity
struct PositionInfo {
    // address owner;
    address token0;
    address token1;
    uint24 fee;
    int128 liquidity;
    // tick range
    int24 tickLower;
    int24 tickUpper;
    uint256 tokensOwed0;
    uint256 tokensOwed1;
}

function getPositionInfo(
    uint256 positionId
) external view returns (PositionInfo memory positionInfo);
```

右上角有一个添加头寸的操作，点击弹出以下页面：

TODO: 图片

跟添加池子非常类似，只是不能填价格范围和当前价格，参数包括：

- token0 的地址和数量；
- token1 的地址和数量；
- 费率（百分比）。

定义 `mint` 方法，由于添加流动性只能选择低于价格范围下限、在价格范围内、超出价格范围上限三种情况，我们用 int8 类型的参数 `positionType`，分别取 -1, 0, 1 来表示上面三种情况。接口定义如下：

```solidity
struct MintParams {
    address token0;
    address token1;
    uint24 fee;
    int8 positionType; // lower:-1; medium:0; upper:1
    uint256 amount0Desired;
    uint256 amount1Desired;
    address recipient;
    uint256 deadline;
}

function mint(
    MintParams calldata params
)
    external
    payable
    returns (
        uint256 positionId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
```

值得注意的是，选定 token0 和 token1 是两个下拉框，费率会自动显示。要想实现这个逻辑，我们需要进一步完善 `PoolManager.sol`，新增两个方法：

- `getTokens`: 获取所有的 tokens，用于用户第一个下拉框选择；
- `getTokenPools`：参数是一个 token 地址，返回所有的池子，用于用户第二个下拉框选择。

接口定义如下：

```solidity
function getTokens() external view returns (address[] memory tokens);

function getTokenPools(
    address token
) external view returns (PoolKey[] memory pools);
```

每行头寸的信息还有两个按钮，分别是 `burn` 和 `collect`，分别代表销毁头寸的流动性，以及提取全部手续费。

接口定义如下：

```solidity
function burn(
    uint256 positionId
) external returns (uint256 amount0, uint256 amount1);

function collect(
    uint256 positionId,
    address recipient
) external returns (uint256 amount0, uint256 amount1);
```

完整的接口在 [IPositionManager](./code/interfaces/IPositionManager.sol) 中。

#### SwapRouter

`SwapRouter.sol` 对应 Swap 页面，我们首先来看 Swap 页面有哪些功能

对应前端页面如下：

![swap](../P003_OverallDesign/img/swap.png)

首先选定 token0 和 token1 也是两个下拉框，实现和 添加头寸 页面一致，只是不会展示费率，因此用户选择完交易对后可能从合约中获取一个或多个池子。

然后就是估算逻辑了，有以下两种方法：
- `quoteExactInput`：用户输入框输入 token0 的数量，输出框自动展示 token1 的数量；
- `quoteExactOutput`:用户输出框输入 token1 的数量，输入框自动展示 token0 的数量；

接口定义如下：

```solidity
struct QuoteExactInputParams {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint160 sqrtPriceLimitX96;
}

function quoteExactInput(
    QuoteExactInputParams memory params
) external returns (uint256 amountOut);

struct QuoteExactOutputParams {
    address tokenIn;
    address tokenOut;
    uint256 amount;
    uint160 sqrtPriceLimitX96;
}

function quoteExactOutput(
    QuoteExactOutputParams memory params
) external returns (uint256 amountIn);
```

最后，当用户点击 Swap 按钮，有两种估算逻辑对应的方法 `exactInput` 和 `exactOutput`。

接口定义如下：

```solidity
struct ExactInputParams {
    address tokenIn;
    address tokenOut;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}

function exactInput(
    ExactInputParams calldata params
) external payable returns (uint256 amountOut);

struct ExactOutputParams {
    address tokenIn;
    address tokenOut;
    address recipient;
    uint256 deadline;
    uint256 amountOut;
    uint256 amountInMaximum;
    uint160 sqrtPriceLimitX96;
}

function exactOutput(
    ExactOutputParams calldata params
) external payable returns (uint256 amountIn);
```

完整的接口在 [ISwapRouter](./code/interfaces/ISwapRouter.sol) 中。

#### Factory

`Factory.sol` 是 Pool 的工厂合约，比较简单，定义了 `getPool` 和 `createPool` 的方法，以及 `PoolCreated` 事件。

接口定义如下：

```solidity
event PoolCreated(
    address indexed token0,
    address indexed token1,
    uint24 indexed fee,
    address pool
);

function getPool(
    address tokenA,
    address tokenB,
    uint24 fee
) external view returns (address pool);

function createPool(
    address tokenA,
    address tokenB,
    uint24 fee
) external returns (address pool);
```

特别的，参照 Uniswap，工厂合约也设计成临时存储交易池合约初始化参数 parameters ，从而完成参数的传递。新增如下方法定义：

```solidity
function parameters()
    external
    view
    returns (address factory, address token0, address token1, uint24 fee);
```

完整的接口在 [IFactory](./code/interfaces/IFactory.sol) 中。

#### Pool

`Pool.sol` 是最底层的合约，实现了 `WTFSwap` 的核心逻辑。

首先是一些不可变量的读方法，如下：

```solidity
function factory() external view returns (address);

function token0() external view returns (address);

function token1() external view returns (address);

function fee() external view returns (uint24);

function tickLower() external view returns (int24);

function tickUpper() external view returns (int24);
```

然后是当前状态变量的读方法，即当前价格、tick、流动性，以及不同头寸位置的流动性和代币数量，如下：

```solidity
function sqrtPriceX96() external view returns (uint160);

function tick() external view returns (int24);

function liquidity() external view returns (uint128);

function positions(
    int8 positionType
)
    external
    view
    returns (uint128 _liquidity, uint128 tokensOwed0, uint128 tokensOwed1);
```

我们还要定义初始化方法，相比于 Uniswap，我们初始化时指定了价格范围，如下：

```solidity
function initialize(
    uint160 sqrtPriceX96,
    int24 tickLower,
    int24 tickUpper
) external;
```

最后是上层合约的底层实现，分别是 `mint`、`collect`、 `burn`、 `swap` 方法以及事件。

接口定义如下：

``` solidity
event Mint(
    address sender,
    address indexed owner,
    int8 indexed positionType,
    uint128 amount,
    uint256 amount0,
    uint256 amount1
);

function mint(
    address recipient,
    int8 positionType,
    uint128 amount,
    bytes calldata data
) external returns (uint256 amount0, uint256 amount1);

event Collect(
    address indexed owner,
    address recipient,
    int8 indexed positionType,
    uint128 amount0,
    uint128 amount1
);

function collect(
    address recipient,
    int8 positionType
) external returns (uint128 amount0, uint128 amount1);

event Burn(
    address indexed owner,
    int8 indexed positionType,
    uint128 amount,
    uint256 amount0,
    uint256 amount1
);

function burn(
    int8 positionType
) external returns (uint256 amount0, uint256 amount1);

event Swap(
    address indexed sender,
    address indexed recipient,
    int256 amount0,
    int256 amount1,
    uint160 sqrtPriceX96,
    uint128 liquidity,
    int24 tick
);

function swap(
    address recipient,
    bool zeroForOne,
    int256 amountSpecified,
    uint160 sqrtPriceLimitX96,
    bytes calldata data
) external returns (int256 amount0, int256 amount1);
```

特别的，还需要定义两个回调接口，分别用于 pool 合约 `mint` 和 `swap` 的回调。接口定义如下：

```solidity
interface IMintCallback {
    function mintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}

interface ISwapCallback {
    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}
```

完整的接口在 [IPool.sol](./code/interfaces/IPool.sol) 中。
