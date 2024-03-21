签名和验签是重要的功能，这一讲会介绍如何在客户端实现签名，并在服务端验证它。

---

## 签名

如果参与过以太坊 DApp 相关的开发，可能遇到过要求签名一条消息或一条数据以验证自己（以及哈希地址）

### 作用

签名的作用仅仅是验证你的身份。只知道地址并不能验证你真的是你，因为这是可以被冒充的。签名的过程只是通过私钥对一些信息进行加密，然后服务器去解密，对结果进行对比。

### 实现

通常用于实现的方式有签名一条固定的消息或者随机字符串等等，如果是随机字符串，前端通过接口获取随机字符串，然后对其随机字符串进行签名，将签名后的字符串和地址作为参数提交给后台去进行验证。下面是一般的UI效果：

![签名](./img/signature.png)

### 代码

我们通过 [Ant Design Web3](https://web3.ant.design/) 先进行 [连接钱包](../03_ConnectWallet/readme.md)

![连接](./img/connect.png)

在外层包 `WagmiWeb3ConfigProvider`

``` tsx
import React from 'react';
import {
  MetaMask,
  OkxWallet,
  TokenPocket,
  WagmiWeb3ConfigProvider,
  WalletConnect,
} from '@ant-design/web3-wagmi';
import { createConfig, http } from 'wagmi';
import { mainnet } from 'wagmi/chains';
import { walletConnect } from 'wagmi/connectors';
import DemoInner from './DemoInner';


const config = createConfig({
  chains: [mainnet],
  transports: {
    [mainnet.id]: http(),
  },
  connectors: [
    walletConnect({
      showQrModal: false,
      projectId: YOUR_WALLET_CONNET_PROJECT_ID,
    }),
  ],
});
const Demo:React.FC = () => {
  return (
    <WagmiWeb3ConfigProvider
      eip6963={{
        autoAddInjectedWallets: true,
      }}
      ens
      wallets={[
        MetaMask(),
        WalletConnect(),
        TokenPocket({
          group: 'Popular',
        }),
        OkxWallet(),
      ]}
      config={config}
    >
      <DemoInner />
    </WagmiWeb3ConfigProvider>
  );
}
export default Demo;

```

在 `DemoInner` 组件内写入方法

``` tsx
import React from 'react';
import { ConnectButton, Connector } from '@ant-design/web3';
import { useAccount, useSignMessage } from 'wagmi';


import { message } from 'antd';
import { useLatest } from 'ahooks';
const DemoInner:React.FC = () => {
  const { signMessageAsync } = useSignMessage();
  const { address } = useAccount();
  const addressRef = useLatest(address);
  const [signLoading, setSignLoading] = React.useState<boolean>(false);

  const doSignature = async () => {
    setSignLoading(true);
    try {
      const signature = await signMessageAsync({
        message: 'You are connecting your Ethereum address with zan.top',
      });
      console.log('signature:', signature);
      console.log('address:', addressRef.current);
      await runConnectEthAddress({
        chainAddress: addressRef.current,
        signature,
      });
    } catch (error: any) {
      message.error(`Signature failed: ${error.message}`);
    }

    setSignLoading(false);
  };

  const runConnectEthAddress = async (params: { chainAddress?: string; signature: string }) => {
    // do something
  }
  return (
    <div>
      <Connector
+       onConnected={doSignature}
        modalProps={{
          group: false,
          footer: (
            <>
              Powered by{' '}
              <a
                href="https://web3.ant.design/"
                target="_blank"
                rel="noreferrer"
              >
                Ant Design Web3
              </a>
            </>
          ),
        }}
      >
        <ConnectButton loading={signLoading} />
      </Connector>
    </div>
  );
}
export default DemoInner;

```
并在 `Connector` 里写入 `onConnected` 当我们连接钱包成功之后就会调起 `doSignature` 方法，在这里我们用到了 `wagmi` 的 `useSignMessage` 的hooks。当执行 `signMessageAsync` 后可以得到已经签名过的固定的消息，`signature: 0xf7960a0d29b9771e67c3070dd371444f4c37e35e11395877a1f36f93a8065117512d57148b0f4d4d56ec17383818ddf70347c76df9e414b7aaab3ed81ab955111b` 和 地址信息 `address: 0xE21E97Ad8B527acb90F0b148EfaFbA46625382cE`.

然后我们就把签名得到的结果和我们登录的地址一起通过接口在 `runConnectEthAddress` 方法里发给后端同学。

## 验签

关于后端的验签，一般依赖 `wagmi` 或者 `ethers` 等库。

如 `wagmi` 实现： 
``` tsx
import { verifyMessage } from '@wagmi/core'

const result = await verifyMessage(config, {
  address: '0xE21E97Ad8B527acb90F0b148EfaFbA46625382cE',
  message: 'You are connecting your Ethereum address with zan.top',
  signature:'0xf7960a0d29b9771e67c3070dd371444f4c37e35e11395877a1f36f93a8065117512d57148b0f4d4d56ec17383818ddf70347c76df9e414b7aaab3ed81ab955111b'
})
console.log('result', result);

```
得到结果：`result true` 

或者 `ethers` 实现：
``` tsx
const verifyMessage = async (message, signerAddress, signature) => {
  const recoveredAddress = ethers.utils.verifyMessage(message, signature);
  return recoveredAddress === signerAddress;
};
```

对于 `DApp` 或者 `Web3` 的开发，设计的用户验证通常的机制就是通过签名消息来实现。你学会了吗～
