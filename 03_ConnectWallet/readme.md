连接钱包是 DApp 中最重要的交互，这一讲我们会引导你通过 [wagmi](https://wagmi.sh) 和 [Ant Design Web3](https://web3.ant.design) 来实现连接钱包的功能。

## DApp 如何连接钱包

在 DApp 中，我们需要连接钱包来获取用户的钱包地址，以及进行一些需要用户签名的操作，比如发送交易、签名消息等。连接钱包有多种方式，通常在以太坊中有如下三种方式：

- 通过浏览器插件建立连接。
- 通过在钱包 App 中访问 DApp 建立连接。
- 通过 WalletConnect 协议建立连接。

其中前面两种对于 DApp 来说都是通过钱包注入到浏览器运行环境中的接口来实现的，而 WalletConnect 则是通过服务端中转的方式来实现的。而钱包注入接口也有两种方式，一种是通过 [EIP-1193](https://eips.ethereum.org/EIPS/eip-1193) 来实现的，另一种是通过 [EIP-6963](https://eips.ethereum.org/EIPS/eip-696) 来实现的。EIP-1193 是一个早期的协议，也比较简单，接下来我们先尝试用这种方式来和钱包建立连接。

## 配置钱包

我们以 [MetaMask](https://metamask.io/) 为例，看一下如何和 MetaMask 钱包建立连接。

```diff

import { createConfig, http } from "wagmi";
import { mainnet } from "wagmi/chains";
- import { WagmiWeb3ConfigProvider } from "@ant-design/web3-wagmi";
+ import { WagmiWeb3ConfigProvider, MetaMask } from "@ant-design/web3-wagmi";
- import { Address, NFTCard } from "@ant-design/web3";
+ import { Address, NFTCard, Connector, ConnectButton } from "@ant-design/web3";
+ import { injected } from "wagmi/connectors";

const config = createConfig({
  chains: [mainnet],
  transports: {
    [mainnet.id]: http(),
  },
+   connectors: [
+     injected({
+       target: "metaMask",
+     }),
+   ],
});

export default function Web3() {
  return (
-   <WagmiWeb3ConfigProvider config={config}>
+    <WagmiWeb3ConfigProvider config={config} wallets={[MetaMask()]}>
      <Address format address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9" />
      <NFTCard
        address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9"
        tokenId={641}
      />
+       <Connector>
+         <ConnectButton />
+       </Connector>
    </WagmiWeb3ConfigProvider>
  );
};


```

可以得到如下的效果：

![](./img/connect.png)
