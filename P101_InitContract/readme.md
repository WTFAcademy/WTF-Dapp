这一讲将会设计整体合约的结构，定义各个合约的接口，并做初步的技术分析。

---

## 合约结构

以简单为原则，我们不按照 Uniswap V3 将合约分为 `periphery` 和 `core` 两个独立仓库，而是自顶向下分为以下四个合约。

- `PoolManager.sol`: 顶层合约，对应 Pool 页面，负责 Pool 的创建和管理；
- `PositionManager.sol`: 顶层合约，对应 Position 页面，负责 LP 头寸和流动性的管理；
- `SwapRouter.sol`: 顶层合约，对应 Swap 页面，负责预估价格和交易；
- `Pool.sol`: 底层合约，对应一个交易池，记录了当前价格、头寸、流动性等信息。                       

## 合约接口设计

因为我们是自顶向下设计合约，因此我们首先分析前端页面（Pool 页面和 Swap 页面）需要哪些功能，并为此设计出顶层合约，再进一步分析细节，设计出底层合约。

#### PoolManager

`PoolManager.sol` 对应 Pool 页面，我们首先来看 Pool 页面有哪些功能

首先是展示所有的 pool ，对应前端页面如下：

![pool](../P003_OverallDesign/img/pool.png)

每个 pool 的信息包括：

- token 对的符号以及数量；
- 费率；
- 价格范围；
- 当前价格；
- 三个区间的总流动性（TODO: 图中没有）。

此外还有一个添加池子的操作（TODO: 池子不能 remove），点击弹出以下页面：

![add](../P003_OverallDesign/img/add.png)

参数包括：

- token0 的地址和数量；
- token1 的地址和数量；
- 费率（百分比）；
- 价格范围；
- 当前价格。

token0 的数量不为 0 或 token1 的数量不为 0 意味着添加初始流动性。

接口如下：

```solidity
interface PoolManager {
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

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

    function getPools() public view returns (PoolKey[] memory pools);

    function getPoolInfo(
        address token0,
        address token1,
        uint24 fee
    ) public view returns (PoolInfo poolInfo);

    function createPoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint160 sqrtPriceX96,
        uint256 amount0,
        uint256 amount1
    ) external payable returns (address pool);

}
```

#### PositionManager

`PositionManager.sol` 对应 Position 页面，我们首先来看 Position 页面有哪些功能

首先是展示当前地址创建的头寸，对应前端页面如下：

TODO: 图片

每个头寸的信息包括：

- token 对的符号以及数量（这里的数量是头寸拥有的两种代币数量）；
- 费率；
- 价格范围；
- 添加的流动性；
- 收取的两种代币的手续费。

右上角有一个添加头寸的操作，点击弹出以下页面：

TODO: 图片

跟添加池子非常类似，只是不能填价格范围和当前价格，参数包括：

- token0 的地址和数量；
- token1 的地址和数量；
- 费率（百分比）。

当选定 token0 和 token1 后，如果存在当前交易对的池子，费率有个下拉框，如果没有其实跳转的是添加池子的界面。

每行头寸的信息还有两个按钮，分别是 `burn` 和 `collect`，分别代表销毁头寸的流动性，以及提取全部手续费。

接口如下：

```solidity
interface PositionManager {
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

    function getPositions(
        address owner
    ) public view returns (uint256[] memory positionIds);

    function getPositionInfo(
        uint256 positionId
    ) public view returns (PositionInfo positionInfo);

    function mint(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96,
        uint256 amount0Desired,
        uint256 amount1Desired,
        address recipient,
        uint256 deadline
    ) external payable returns (
                            uint256 positionId,
                            uint128 liquidity,
                            uint256 amount0,
                            uint256 amount1
                        );

    function burn(
        uint256 positionId
    ) external returns (
                    uint256 amount0,
                    uint256 amount1
                );

    function collect(
        uint256 positionId,
        address recipient
    ) external returns (
                    uint256 amount0,
                    uint256 amount1
                );

}
```

#### SwapRouter

`SwapRouter.sol` 对应 Swap 页面，我们首先来看 Swap 页面有哪些功能

#### Pool

`Pool.sol` 是最底层的合约，实现了 `WTFSwap` 的核心逻辑。