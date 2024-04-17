这一讲，我们会引导你快速创建一个 React 项目，并在其中展示一个 NFT 的图片。

---

该课程主要面向有一定前端开发基础的同学，帮助你从 Web2 迈向 Web3，获得 DApp（去中心化应用）的研发能力。

课程会基于 [Ant Design Web3](https://web3.ant.design/) 来进行讲解，让你可以更轻易的上手。当然，这并不会影响你对基础概念的理解，我们会在课程中对相关概念进行讲解，确保课程完成后你可以掌握 DApp 研发的基础知识。

该课程有一定的前置要求，要求你对 [React](https://react.dev/) 前端开发有基础的了解，如果你对 React 不熟悉，可以先学习 [React 官方文档](https://react.dev/learn)。

## 初始化一个 React 项目

我们将基于 [React](https://react.dev/) + [Next.js](https://nextjs.org/) + [TypeScript](https://www.typescriptlang.org/) 来初始化我们的项目。当然，如果你更熟悉 [umi](https://nextjs.org/) 等其它前端框架，也可以使用你熟悉的框架。你依然可以参考该教程，不过对于非专业的前端开发者，我们建议一步步按照我们的教程来完成，避免遇到一些框架差异导致的问题。

在开始之前，请先确保你安装了 [Node.js](https://nodejs.org/)，并且版本大于 20.0.0。教程会基于最新的 Node.js 版本来编写，如果你使用的是旧版本的 Node.js，可能也能运行，但是当你遇到问题时，可以尝试升级 Node.js 版本。

安装完成后你可以通过如下命令检查 Node.js 和它自带的 `npm` 于 `npx` 是否安装成功：

```bash
node -v # => v20.0.0+
npm -v # => 10.0.0+
npx -v # => 10.0.0+
```

接下来我们参考 [Next.js 官方文档](https://nextjs.org/docs/getting-started/installation)，来创建一个新项目：

```bash
npx create-next-app@14.0.4 # 我们指定 create-next-app 的版本为 14.0.4，避免升级带来的差异影响教程的细节
```

请按照提示创建一个新的项目，我们将其命名为 `ant-design-web3-demo`，具体的技术栈选择你可以参考下图：

![创建项目](./img/init-next.png)

我们去掉了 `Tailwind CSS` 和 `App Router` 的选择，让项目变得更简单，实际项目中你应该按照你的需求选择需要的内容。

## 安装依赖并启动项目

创建完成之后进入项目目录安装依赖：

```base
cd ant-design-web3-demo
npm i
```

安装完成后执行 `npm run dev` 启动项目，你可以在浏览器中访问 `http://localhost:3000` 来查看项目是否启动成功。

![](./img/next-init-page.png)

## 添加 Ant Design Web3

接下来，我们安装 [Ant Design](https://ant.design/) 和 [Ant Design Web3](https://web3.ant.design/) 的基础组件以及其它依赖到项目中：

```bash
npm i antd @ant-design/web3 @ant-design/web3-wagmi wagmi @tanstack/react-query --save
```

- `@ant-design/web3` 是一个 UI 组件库，它通过不同的[适配器](../guide/adapter.zh-CN.md)和不同的区块链连接。本课程中，我们主要基于的是[以太坊](https://ethereum.org/zh/)。对应的，我们也将使用[以太坊的适配器](../../packages/web3/src/wagmi/index.zh-CN.md)来实现课程的需求。

- [wagmi](https://wagmi.sh/) 是一个开源的服务以太坊的 React Hooks 库，并依赖 `@tanstack/react-query`。Ant Design Web3 的适配器 `@ant-design/web3-wagmi` 就是基于它实现的，在本课程的后面部分，如果没有特殊说明，那提到的适配器就是指 `@ant-design/web3-wagmi`。

安装完成后，因为 Next.js 当前版本[已有的一个问题](https://github.com/ant-design/ant-design/issues/46053)，你需要在 `next.config.js` 中添加如下配置：

```diff
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
+ transpilePackages: [  "@ant-design", "antd", "rc-util", "rc-pagination", "rc-picker" ],
}

module.exports = nextConfig
```

安装完成后，新建 `pages/web3.tsx` 的文件，填充内容如下：

```tsx | pure
import { Address } from "@ant-design/web3";

export default function Web3() {
  return (
    <Address format address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9" />
  );
}
```

然后访问 [http://localhost:3000/web3](http://localhost:3000/web3) 可以看到你已经在项目中成功使用 Ant Design Web3 了 🎉

![](./img/dev-success.png)

为了让页面更美观，避免上图中的横条样式，你可以在项目中的 `styles/global.css` 的第八十多行添加如下内容：

```diff
html,
body {
  max-width: 100vw;
+  min-height: 100vh;
  overflow-x: hidden;
}
```

当然，这并不是必须的。

## 配置适配器

适配器的配置直接采用 [wagmi 的官方配置](https://wagmi.sh/core/getting-started)，对于实际项目来说你通常需要配置 JSON RPC 的地址和各种钱包，在该课程中，我们会先采用最简单的配置，再逐步引导你了解你实际项目中所需要的配置。

首先，请继续编辑 `pages/web3.tsx` 文件，引入所需要的内容：

```diff
+ import { createConfig, http } from 'wagmi';
+ import { mainnet } from 'wagmi/chains';
+ import { WagmiWeb3ConfigProvider } from '@ant-design/web3-wagmi';
import { Address } from "@ant-design/web3";

export default function Web3() {
  return (
    <Address format address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9" />
  );
};
```

其中引入的内容说明如下：

- [createConfig](https://wagmi.sh/react/config)：wagmi 用来创建配置的方法。
- http：wagmi 用来创建 [HTTP JSON RPC](https://wagmi.sh/core/api/transports/http) 连接的方法，通过它你可以通过 HTTP 请求访问区块链。
- [mainnet](https://wagmi.sh/react/chains)：代表以太坊主网，除了 `mainnet` 以外还会有类似 `goerli` 的测速网和类似 `bsc` 和 `base` 的 EVM 兼容的其它公链，有的是和以太坊一样的 L1 公链，有的是 L2 公链，这里先暂不展开。
- [WagmiWeb3ConfigProvider](https://web3.ant.design/zh-CN/components/wagmi#wagmiweb3configproviderprops)：Ant Design Web3 用来接收 wagmi 配置的 Provider。

接着创建配置：

```diff
import { createConfig, http } from "wagmi";
import { mainnet } from "wagmi/chains";
import { WagmiWeb3ConfigProvider } from "@ant-design/web3-wagmi";
import { Address } from "@ant-design/web3";

+ const config = createConfig({
+   chains: [mainnet],
+   transports: {
+     [mainnet.id]: http(),
+   },
+ });

export default function Web3() {
  return (
+     <WagmiWeb3ConfigProvider config={config}>
        <Address format address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9" />
+    </WagmiWeb3ConfigProvider>
  );
};

```

这样，我们就完成了 wagmi 的基础配置，接下来我们就可以通过 Ant Design Web3 的组件来获取链上的数据了。

我们试一试使用 [NFTCard](../../packages/web3/src/nft-card/index.zh-CN.md) 组件：

```diff
import { createConfig, http } from "wagmi";
import { mainnet } from "wagmi/chains";
import { WagmiWeb3ConfigProvider } from "@ant-design/web3-wagmi";
- import { Address } from "@ant-design/web3";
+ import { Address, NFTCard } from "@ant-design/web3";

const config = createConfig({
  chains: [mainnet],
  transports: {
    [mainnet.id]: http(),
  },
});

export default function Web3() {
  return (
    <WagmiWeb3ConfigProvider config={config}>
      <Address format address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9" />
+     <NFTCard address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9" tokenId={641} />
    </WagmiWeb3ConfigProvider>
  );
};
```

`NFTCard` 组件会从 [0xEcd0D12E21805803f70de03B72B1C162dB0898d9](https://etherscan.io/address/0xEcd0D12E21805803f70de03B72B1C162dB0898d9) NFT 合约中获取 tokenId 为 641 的 NFT 信息，然后展示在页面上。

效果如下：

![](./img/nft-card.png)

如果没有显示出来，那么请检查你的网络是否正常。如果能够正常渲染出 NFT 图片，那么恭喜你，这一讲我们就完成了！
