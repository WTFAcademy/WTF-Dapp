这一讲开始将会开发前端调用合约相关逻辑，我们首先从支持添加交易对开始。

---

首先，参考[《使用 Wagmi CLI 调试本地合约》](../15_WagmiCli/readme.md)的说明，你需要在 `demo` 目录下运行下面命令：

```sh
npx wagmi generate
```

它会按照我们的配置更新 `utils/contracts.ts` 文件，然后生成代码来调用我们在之前课程中实现的合约。比如在这一讲中可以用 `useReadPoolManagerGetAllPools` 查看交易池和 `useWritePoolManagerCreateAndInitializePoolIfNecessary` 创建交易池。

> 课程编写中......
