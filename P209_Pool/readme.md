这一讲开始将会开发前端调用合约相关逻辑，我们首先从支持添加交易对开始。

---

## 准备工作

首先，我们需要在本地运行一个测试用的链节点，在 `demo-contracts` 目录下运行：

```sh
npx hardhat node # 启动一个本地链开发调试节点
npx hardhat ignition deploy ./ignition/modules/Wtfswap.ts --network localhost # 新开一个终端，部署合约到本地调试节点
```

具体细节可以参考[《合约本地开发和测试环境》](../14_LocalDev/readme.md) 和 [《初始化合约和开发环境》](../P102_InitContracts/readme.md)。

然后进入到 `demo` 目录下更新合约最新的接口：

```sh
npx wagmi generate
```

它会按照我们的配置更新 `utils/contracts.ts` 文件，然后生成代码来调用我们在之前课程中实现的合约。比如在这一讲中可以用 `useReadPoolManagerGetAllPools` 查看交易池和 `useWritePoolManagerCreateAndInitializePoolIfNecessary` 创建交易池。具体可以参考[《使用 Wagmi CLI 调试本地合约》](../15_WagmiCli/readme.md)的说明。

## 获取交易池列表

> 课程编写中......
