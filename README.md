# WTF-Dapp

👉 WTF Dapp 是一个围绕 DApp 全栈开发的入门课程，帮助开发者入门去中心应用开发 🚀。

目前设计中包含三个部分：

- 🐝 新手入门：极简入门教程，从零开始帮助有简单开发经验的开发者快速上手去中心化应用开发。包括简单的前端页面和一个基础的 NFT 合约的开发。
- 🏃 DEX 开发实战：围绕一个课程设计的简单的去中心化交易所（DEX）的开发实战课程。通过这个课程，开发者可以了解到 DEX 的基本原理和实现，以及在实战中学习一些更加复杂的 DApp 开发知识。
- 📝 经验手册：一些关于 DApp 开发的经验总结，包括合约的权限管理、多合约的部署等 DApp 开发过程中可能会遇到的常见问题和解决方案的分享。

📬 课程完全开源，欢迎对 DApp 开发感兴趣的开发者参与贡献。第一部分新手入门已经完成，你可以帮忙校对、提出修改意见。第二部分 DEX 开发实战完成设计正在开发中，你可以直接提交 [PR](https://github.com/WTFAcademy/WTF-Dapp/pulls) 参与开发。第三部分经验手册则开放收集合适的优秀文章，欢迎提交 PR。另外参与讨论和反馈问题也是对课程很重要的贡献，你可以在 [Issues](https://github.com/WTFAcademy/WTF-Dapp/issues) 中讨论或者反馈问题。贡献者可以添加你的 Twitter 到文章头部。

📔 课程中包含合约开发和前端开发的内容，你可以按照你的需求选择学习其中某一个部分。但是我们更加建议你学习全部课程，这样可以更好的理解 DApp 的开发，每一部分我们都提供了完整的代码供参考。

👉 你的 Star 是对我们最好的鼓励，如果对我们的课程感兴趣，欢迎给一个 Star 吧 ⭐

## 赞助商

<a href="https://zan.top?chInfo=wtf"><image src="https://mdn.alipayobjects.com/huamei_hsbbrh/afts/img/A*ybcRSrUPqhsAAAAAAAAAAAAADiOMAQ/original" /></a>

感谢 ZAN 对 WTF Dapp 课程的赞助 ❤️

🔊 [ZAN](https://zan.top?chInfo=wtf) 是一家 Web3 技术服务提供商，提供[节点服务](https://zan.top/home/node-service?chInfo=wtf)、[测试网水龙头](https://zan.top/faucet?chInfo=wtf)、[智能合约审计](https://zan.top/home/ai-scan?chInfo=wtf)、[Web3 安全](https://zan.top/home/know-your-transaction?chInfo=wtf)等服务，为 DApp 开发者提供技术服务支持。

## 新手入门

**第 1 讲：快速开始（三分钟展示 NFT）**：[教程](./01_QuickStart/readme.md) | [代码](./01_QuickStart/web3.tsx)

**第 2 讲：节点服务和水龙头**：[教程](./02_NodeService/readme.md) | [代码](./02_NodeService/web3.tsx)

**第 3 讲：连接钱包**：[教程](./03_ConnectWallet/readme.md) | [代码](./03_ConnectWallet/web3.tsx)

**第 4 讲：调用合约**：[教程](./04_CallContract/readme.md) | [代码](./04_CallContract/web3.tsx)

**第 5 讲：监听事件**：[教程](./05_Events/readme.md) | [代码](./05_Events/web3.tsx)

**第 6 讲：Next.js 部署**：[教程](./06_NextJS/readme.md)

**第 7 讲：合约开发和测试**：[教程](./07_ContractDev/readme.md) | [代码](./07_ContractDev/MyToken.sol)

**第 8 讲：合约部署**：[教程](./08_ContractDeploy/readme.md) | [代码](./08_ContractDeploy/demo/dapp.tsx)

**第 9 讲：EIP1193 和 EIP6963**：[教程](./09_EIP1193/readme.md) | [代码](./09_EIP1193/web3.tsx)

**第 10 讲：通过 WalletConnect 连接移动端钱包**：[教程](./10_WalletConnect/readme.md) | [代码](./10_WalletConnect/web3.tsx)

**第 11 讲：支持多链**：[教程](./11_MultipleChain/readme.md) | [代码](./11_MultipleChain/web3.tsx)

**第 12 讲：签名和验签**：[教程](./12_Signature/readme.md) | [代码](./demo/pages/sign/index.tsx)

**第 13 讲：转账和收款**：[教程](./13_Payment/readme.md) | [代码](./demo/pages/transaction/index.tsx)

**第 14 讲：合约本地开发和测试环境**：[教程](./14_LocalDev/readme.md) | [代码](./demo-contract)

**第 15 讲：使用 Wagmi CLI 调试本地合约**：[教程](./15_WagmiCli/readme.md) | [代码](./demo/wagmi.config.ts)

## DEX 开发实战（开发中）

**第 P000 讲：为什么要做这个实战课程**：[教程](./P000_WhyDEX/readme.md)

**第 P001 讲：什么是去中心化交易所（DEX）**：[教程](./P001_WhatIsDEX/readme.md)

**第 P002 讲：Uniswap 代码解析**：[教程](./P002_WhatIsUniswap/readme.md)

**第 P003 讲：Wtfswap 整体设计**：[教程](./P003_OverallDesign/readme.md)

**第 P101 讲：Wtfswap 合约设计**：[教程](./P101_ContractsDesign/readme.md) | [代码](./demo-contract/contracts/wtfswap/interfaces/)

**第 P102 讲：初始化合约和开发环境**：[教程](./P102_InitContracts/readme.md) | [代码](./P102_InitContracts/code/)

**第 P103 讲：Factory 合约开发**：[教程](./P103_Factory/readme.md) | [代码](./demo-contract/contracts/wtfswap/Factory.sol)

**第 P104 讲：PoolManager 合约开发**：[教程](./P104_PoolManager/readme.md) | [代码](./demo-contract/contracts/wtfswap/PoolManager.sol)

**第 P105 讲：Pool 合约 LP 相关接口开发**：[教程](./P105_PoolLP/readme.md) | [代码](./demo-contract/contracts/wtfswap/Pool.sol)

**第 P106 讲：Pool 合约 swap 接口开发**：[教程](./P106_PoolSwap/readme.md) | [代码](./demo-contract/contracts/wtfswap/Pool.sol)

**第 P107 讲：Pool 合约交易手续费逻辑开发**：[教程](./P107_PoolFee/readme.md) | [代码](./demo-contract/contracts/wtfswap/Pool.sol)

**第 P108 讲：PositionManager 合约开发**

**第 P109 讲：SwapRouter 合约开发**

**第 P201 讲：初始化前端代码和技术分析**：[教程](./P201_InitFrontend/readme.md) | [代码](./P201_InitFrontend/code/)

**第 P202 讲：头部 UI 开发**：[教程](./P202_HeadUI/readme.md) | [代码](./P202_HeadUI/code/)

**第 P203 讲：支持连接链**：[教程](./P203_Connect/) | [代码](./P203_Connect/code/)

**第 P204 讲：Swap 页面 UI 开发**

**第 P206 讲：Pool 页面 UI 开发**

**第 P207 讲：添加流动性弹窗 UI 开发**

**第 P208 讲：支持添加流动性**

**第 P209 讲：支持查看流动性**

**第 P210 讲：支持提取流动性**

**第 P211 讲：支持 Swap**

**第 P301 讲：合约的优化和安全**

**第 P302 讲：Wtfswap 部署**

## 经验手册（PR Welcome）

**第 T001 篇：合约的权限如何管理**：[文章](./T001_ContractAuth/readme.md)

**第 T002 篇：部署 Uniswap V3 源码**
