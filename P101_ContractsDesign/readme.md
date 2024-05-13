这一讲我们会设计好所有的合约，定义好它们的接口，在具体的实现之前做好整体的架构设计。

---

## 概要

结合上一讲的内容，我们仅保留核心的功能，让课程更简单。我们会参考 Uniswap 的整体架构，但是不会将合约在分开在两个项目中。我们将实现如下合约：

- `SwapRouter.sol`：交易，对应 [SwapRouter.sol](https://github.com/Uniswap/v3-periphery/blob/main/contracts/SwapRouter.sol)。
- `LiquidityManagement.sol`：管理流动性，对应 [LiquidityManagement.sol](https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/LiquidityManagement.sol)。
- core
  - `WtfswapPool.sol`：交易池，对应 [UniswapV3Pool.sol](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol)。
  - `WtfswapPoolFactory`：交易池的工厂合约，对应 [UniswapV3Factory.sol](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Factory.sol)。

其中 `SwapRouter.sol` 是普通用户交易时需要调用的合约，该合约会找到对应的交易池交易。`LiquidityManagement.sol` 是 LP 管理流动性时需要调用的合约。这两者都依赖 core 下面的两个交易池相关合约。接下来我们继续设计这些合约具体的接口。

## 接口设计

### SwapRouter.sol

TODO

### LiquidityManagement.sol

TODO

### WtfswapPool.sol

TODO

### WtfswapPoolFactory

TODO

## 初始化合约

我们参考之前的课程[合约本地开发和测试环境](./LocalDev/readme.md)来初始化合约工程，并结合上面的设计初始化合约的接口。
