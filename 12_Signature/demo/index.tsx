import React from 'react';
import { MetaMask, WagmiWeb3ConfigProvider } from '@ant-design/web3-wagmi';
import { createConfig, http } from 'wagmi';
import { mainnet } from 'wagmi/chains';
import DemoInner from './DemoInner';

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
    <WagmiWeb3ConfigProvider config={config} wallets={[MetaMask()]}>
      <DemoInner />
    </WagmiWeb3ConfigProvider>
  );
}
export default Demo;
