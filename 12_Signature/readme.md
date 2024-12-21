本节作者：[@LiKang](https://x.com/banlideli)

签名和验签是重要的功能，这一讲会介绍如何在客户端实现签名，并在服务端验证它。

---

## 签名是用来干什么的？

在 DApp 中，通常是基于区块链地址来构建用户体系的，一个区块链地址代表一个用户。传统的应用我们通常用密码、手机验证码等方式来验证用户。那么在 DApp 中，我们如何来验证操作者确实是某个区块链地址的所有者呢？

我们在前面的课程中实现了通过唤起用户的钱包来连接某个区块链地址，这样在 DApp 中就可以获取这个地址信息了。这样可以证明用户拥有这个地址吗？我们可以在连接上用户地址后就允许用户操作 DApp 中的相关资产吗？

如果资产是在区块链上，那或许是可以的，因为智能合约的调用都需要地址对应的私钥签名认证。但是并非所有的资产都是在链上，如果你的 DApp 需要操作传统数据库中的用户资产，那么必须要确保当前操作的用户拥有相关权限。

然而只是连接上钱包获得地址就认为用户拥有该账号是不可靠的，因为调用钱包获取到地址的接口可能会被客户端伪造。所以我们需要让用户通过签名来验证身份，用户通过他的私钥对某一条消息进行签名，DApp 的服务端通过公钥对签名结果进行验证，这样才能确保用户的操作权限。

这一讲，就让我们来实现一个这样的简单的示例，在连接钱包后可以签名以验证身份：

![demo](./img/demo.png)

### 实现前端签名

我们先来实现前端部分逻辑，我们基于之前的课程先快速实现[连接钱包](../03_ConnectWallet/readme.md)。

新建一个 `pages/sign/index.tsx` 文件，复制之前的代码，然后做下修改，新建一个 `components/SignDemo` 的组件：

```diff
import React from 'react';
- import { Address, ConnectButton, Connector, NFTCard } from "@ant-design/web3";
import { MetaMask, WagmiWeb3ConfigProvider } from "@ant-design/web3-wagmi";
import { createConfig, http } from 'wagmi';
import { injected } from "wagmi/connectors";
import { mainnet } from 'wagmi/chains';
+ import SignDemo from '../../components/SignDemo';


const config = createConfig({
  chains: [mainnet],
  transports: {
    [mainnet.id]: http(),
  },
  connectors: [
    injected({
      target: "metaMask",
    }),
  ],
});
const Demo:React.FC = () => {
  return (
    <WagmiWeb3ConfigProvider eip6963 config={config} wallets={[MetaMask()]}>
+       <SignDemo />
-           <Address format address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9" />
-           <NFTCard
-             address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9"
-             tokenId={641}
-           />
-           <Connector>
-         <ConnectButton />
-      </Connector>
    </WagmiWeb3ConfigProvider>
  );
}
export default Demo;

```

然后在 `SignDemo` 组件内写一个基础的链接钱包按钮，代码如下：

```tsx
import React from "react";
import { ConnectButton, Connector } from "@ant-design/web3";

const SignDemo: React.FC = () => {
  return (
    <Connector>
      <ConnectButton />
    </Connector>
  );
};
export default SignDemo;
```

这样我们就实现了基本的连接逻辑。

然后补充签名部分逻辑，首先引入 `wagmi` 的 `useSignMessage` 和 Ant Design Web3 的 `useAccount` hooks，实现 `doSignature`：

```diff
import React from "react";
- import { ConnectButton, Connector } from "@ant-design/web3";
+ import { ConnectButton, Connector, useAccount } from "@ant-design/web3";
+ import { useSignMessage } from "wagmi";
+ import { message } from "antd";

const SignDemo: React.FC = () => {
+  const { signMessageAsync } = useSignMessage();
+  const { account } = useAccount();

+  const doSignature = async () => {
+    try {
+      const signature = await signMessageAsync({
+        message: "test message for WTF-DApp demo",
+      });
+    } catch (error: any) {
+      message.error(`Signature failed: ${error.message}`);
+    }
+  };

  return (
    <Connector>
      <ConnectButton />
    </Connector>
  );
};
export default SignDemo;
```

我们来添加一个按钮，点击按钮后调用 `doSignature` 方法，我们设置了 `disabled` 属性，只有当已经连接成功后才可以调用签名：

```diff
import React from "react";
import { ConnectButton, Connector, useAccount } from "@ant-design/web3";
import { useSignMessage } from "wagmi";
- import { message } from "antd";
+ import { message, Space, Button } from "antd";

const SignDemo: React.FC = () => {

// ...

  return (
+    <Space>
      <Connector>
        <ConnectButton />
      </Connector>
+      <Button
+        disabled={!account?.address}
+        onClick={doSignature}
+      >
+        Sign message
+      </Button>
+    </Space>
  );
};
export default SignDemo;
```

这样我们就实现了前端签名的逻辑，但是正如前面所说，签名需要发送到服务端才验证，所以我们需要先实现服务端验签接口。

## 实现服务端验签

关于后端的验签，一般依赖 `viem` 或者 `ethers` 等库。你可以直接新建 `/pages/api/signatureCheck.ts` 文件，Next.js 会自动将 `/api` 下的文件作为后端运行的 [Vercel Function](https://vercel.com/docs/functions/quickstart) 处理。

我们基于 `viem` 实现：

```ts
// /pages/api/signatureCheck.ts
import type { NextApiRequest, NextApiResponse } from "next";
import { createPublicClient, http } from "viem";
import { mainnet } from "viem/chains";

export const publicClient = createPublicClient({
  chain: mainnet,
  transport: http(),
});

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    const body = req.body;
    const valid = await publicClient.verifyMessage({
      address: body.address,
      message: "test message for WTF-DApp demo",
      signature: body.signature,
    });
    res.status(200).json({ data: valid });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
}
```

如果更擅长 `ethers` 可以换成以下代码实现：

```tsx
const verifyMessage = async (signerAddress, signature) => {
  const recoveredAddress = ethers.utils.verifyMessage(
    "test message for WTF-DApp demo",
    signature
  );
  return recoveredAddress === signerAddress;
};
```

## 前端调用接口验签

最后我们来补充前端调用接口的逻辑。你可以直接将下面代码复制到 `SignDemo` 组件中：

```tsx
const checkSignature = async (params: {
  address?: string;
  signature: string;
}) => {
  try {
    const response = await fetch("/api/signatureCheck", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(params),
    });
    const result = await response.json();
    if (result.data) {
      message.success("Signature success");
    } else {
      message.error("Signature failed");
    }
  } catch (error) {
    message.error("An error occurred");
  }
};
```

然后我们在 `doSignature` 方法中调用这个方法，并添加一个 Loading 状态：

```diff
import React from "react";
import { ConnectButton, Connector, useAccount } from "@ant-design/web3";
import { useSignMessage } from "wagmi";
import { message, Space, Button } from "antd";

const SignDemo: React.FC = () => {
  const { signMessageAsync } = useSignMessage();
  const { account } = useAccount();
+  const [signLoading, setSignLoading] = React.useState(false);

  const doSignature = async () => {
+    setSignLoading(true);
    try {
      const signature = await signMessageAsync({
        message: "test message for WTF-DApp demo",
      });
+      await checkSignature({
+        address: account?.address,
+        signature,
+      });
    } catch (error: any) {
      message.error(`Signature failed: ${error.message}`);
    }
+    setSignLoading(false);
  };

// checkSignature here

  return (
    <Space>
      <Connector>
        <ConnectButton />
      </Connector>
      <Button
+        loading={signLoading}
        disabled={!account?.address}
        onClick={doSignature}
      >
        Sign message
      </Button>
    </Space>
  );
};
export default SignDemo;
```

完整的代码你可以在 [sign 目录](../demo/pages/sign)中找到。
