在前面的课程中，我们基于 Remix 尝试了通过 CloudIDE 进行合约开发。在本地开发环境中，我们可以使用更多的工具来提高开发效率，比如使用 Git 来进行版本管理。这一讲将会引导大家在本地开发和调试合约，以及编写单元测试来验证智能合约的逻辑。

---

## 初始化项目

以太坊的生态有着丰富的开发工具，比如 [Hardhat](https://hardhat.org/)、[Foundry](https://getfoundry.sh/) 等。这里我们将使用 Hardhat 来搭建本地开发环境，将本课程之前开发的合约迁移到本地环境中。

我们参考 [hardhat 的快速开始文档](https://hardhat.org/hardhat-runner/docs/getting-started) 执行如下命令快速初始化一个项目：

```bash
mkdir demo-contract
cd demo-contract
npx hardhat@2.22.3 init
```

和[第一章](../01_QuickStart/readme.md)初始化 NextJS 项目类似，`npx` 是安装完成 NodeJS 后自带的命令，如上命令会自动下载 [hardhat npm 包](https://www.npmjs.com/package/hardhat) 并执行 `init` 命令。使用 `2.22.3` 版本是因为它是本课程编写时的最新版本，这样可以保证你的环境和本课程一致。当然你也可以去掉版本号使用最新版。

我们选择第三项，使用 Typescript + viem，和我们之前课程的技术栈保持一致。

![hardhat](./img/hardhat.png)

创建完成后你会得到如下的目录结构：

![initfiles](./img/initfiles.png)
