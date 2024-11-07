# 参与 WTF-Dapp 贡献

我们欢迎一切形式的贡献，包括但不限于通过 [Issues](https://github.com/WTFAcademy/WTF-Dapp/issues) 提交建议或者问题，通过 [PR](https://github.com/WTFAcademy/WTF-Dapp/pulls) 修改错别字、语法优化、补充新的内容和章节等。对内容有较大贡献的开发者可以添加你的 Twitter 或者其他社交媒体链接，比如你新增了某个章节，或者补充了一段关键的内容，都可以在提交 PR 的同时将你的链接添加到文章头部。

## 注意事项

这里列出一些内容的规范，帮助你更好的参与贡献：

- 中文和数字以及英文直接添加空格，比如 `访问 ZAN 的网站`，而不是 `访问ZAN的网站`，具体的排版指南参考[《中文文案排版指北》](https://github.com/sparanoid/chinese-copywriting-guidelines)。
- 内容更新需要保证完整性，包括课程的 Markdown 文档和 `demo` 以及 `demo-contract` 和课程中对应 `code` 中相关代码的更新。
- 合约代码的提交需要保证通过合约的单元测试，确保代码的正确性。
- 文章的头部统一用 `---` 分割，上部分是文章的作者和简介。下部分是文章的内容，通过 `##` 和更小的标题分割不同的章节。
- 文章要求简单易懂，除了必要的代码外要有充分的说明和解释，课程整体面向 Web3 DApp 开发的初学者，要求由浅到深渐进式地讲解。

## 如何启动前端

```bash
cd demo
npm i
npm start
```

更多内容你可以参考课程[《快速开始（三分钟展示 NFT）》](./01_QuickStart/readme.md)。

## 如何测试合约

```bash
cd demo-contract
npm i
npx hardhat test
```

更多内容你可以参考课程[《合约本地开发和测试环境》](./14_LocalDev/readme.md)。

## 如何启动本地测试区块链做端到端调试

启动前端后再通过如下方式启动本地的 Hardhat 测试区块链，并部署合约调试：

```bash
cd demo-contract
npm i
npx hardhat node
npx hardhat
npx hardhat ignition deploy ./ignition/modules/Mytoken.ts --network localhost # 部署测试 NFT
npx hardhat ignition deploy ./ignition/modules/Wtfswap.ts --network localhost # 部署 WTFSwap
```
