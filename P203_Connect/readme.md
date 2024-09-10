本节作者：[@愚指导](https://x.com/yudao1024)

这一讲我们将支持通过钱包链接区块链，你也可以参考之前基础课程中的[连接钱包](../03_ConnectWallet/)学习。

---

## 初始化 Provider

我们基于 [Ant Design Web3 的以太坊适配](https://web3.ant.design/components/ethereum-cn)，来给整个 DApp 的组件提供连接链的支持，我们需要在 DApp 的最外层包裹 `WagmiWeb3ConfigProvider`，这样就可以在 DApp 的组件中获取链上数据或者调用合约了。

在基础课程部分我们已经安装了相关依赖，如果你是基于新创建的项目学习，你也可以参考 Ant Design Web3 的[快速开始](https://web3.ant.design/guide/quick-start-cn)文档安装相关依赖：

```sh
npm install antd @ant-design/web3 @ant-design/web3-wagmi wagmi viem @tanstack/react-query --save
```

接下来我们在参考 Ant Design Web3 的[推荐配置](https://web3.ant.design/components/ethereum-cn#%E6%8E%A8%E8%8D%90%E9%85%8D%E7%BD%AE) `components/WtfLayout/index.tsx` 中做如下修改：

```diff
import React from "react";
import Header from "./Header";
+ import {
+   MetaMask,
+   OkxWallet,
+   TokenPocket,
+   WagmiWeb3ConfigProvider,
+   WalletConnect,
+   Hardhat,
+   Mainnet,
+ } from "@ant-design/web3-wagmi";
+ import { QueryClient } from "@tanstack/react-query";
+ import { createConfig, http } from "wagmi";
+ import { mainnet, hardhat } from "wagmi/chains";
+ import { walletConnect } from "wagmi/connectors";

+ const queryClient = new QueryClient();

+ const config = createConfig({
+   chains: [mainnet, hardhat],
+   transports: {
+     [mainnet.id]: http(),
+     [hardhat.id]: http("http://127.0.0.1:8545/"),
+   },
+   connectors: [
+     walletConnect({
+       showQrModal: false,
+       projectId: "c07c0051c2055890eade3556618e38a6",
+     }),
+   ],
+ });


interface WtfLayoutProps {
  children: React.ReactNode;
}

const WtfLayout: React.FC<WtfLayoutProps> = ({ children }) => {
  return (
-     <div>
+     <WagmiWeb3ConfigProvider
+       eip6963={{
+         autoAddInjectedWallets: true,
+       }}
+       ens
+       chains={[Mainnet, Hardhat]}
+       wallets={[
+         MetaMask(),
+         WalletConnect(),
+         TokenPocket({
+           group: "Popular",
+         }),
+         OkxWallet(),
+       ]}
+       config={config}
+       queryClient={queryClient}
+     >
      <Header />
      {children}
-     </div>
+     </WagmiWeb3ConfigProvider>
  );
};

export default WtfLayout;
```

在这个配置中我们支持了 [WalletConnect](../10_WalletConnect/readme.md)，支持了基于 [EIP6963](../09_EIP1193/) 自动检测钱包，支持了显示 ENS，以及默认添加了一些钱包。具体的配置说明不在这里具体展开，你可以在前面的基础课程或者 [Ant Design Web3](https://web3.ant.design/) 以及 [wagmi](https://wagmi.sh/) 的文档中学习。

另外我们还添加了 `Hardhat` 本地测试链，便于后续和本地的测试链中部署的合约联调。

## 配置 ConnectButton

配置好 Provider 之后我们还需要配置 `ConnectButton`，接下来请修改我们在上一讲课程中已经完成了样式的 `components/WtfLayout/Header.tsx` 文件：

```diff
import Link from "next/link";
import { usePathname } from "next/navigation";
- import { ConnectButton } from "@ant-design/web3";
+ import { ConnectButton, Connector } from "@ant-design/web3";
import styles from "./styles.module.css";

export default function WtfHeader() {
  const pathname = usePathname();
  const isSwapPage = pathname === "/wtfswap";

  return (
    <div className={styles.header}>
      <div className={styles.title}>WTFSwap</div>
      <div className={styles.nav}>
        <Link
          href="/wtfswap"
          className={isSwapPage ? styles.active : undefined}
        >
          Swap
        </Link>
        <Link
          href="/wtfswap/pool"
          className={!isSwapPage ? styles.active : undefined}
        >
          Pool
        </Link>
      </div>
      <div>
+        <Connector
+           modalProps={{
+             mode: "simple",
+           }}
+         >
          <ConnectButton type="text" />
+         <Connector>
      </div>
    </div>
  );
}
```

我们引入了 [Connector](https://web3.ant.design/components/connector-cn) 组件，它会读取 `WagmiWeb3ConfigProvider` 提供的相关信息，传递给 `ConnectButton`，让连接按钮不再仅仅是 UI 组件，从而具备了连接链的能力。另外 `Connector` 组件集成了 [ConnectModal](https://web3.ant.design/components/connect-modal-cn) 组件，如上面代码示例，你可以通过 `modalProps` 来修改相关配置，我们修改了 `mode` 为 `simple` 让弹窗更简洁，你也可以尝试自己做修改调整样式。
