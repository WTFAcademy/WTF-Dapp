import React from "react";
import { MetaMask, WagmiWeb3ConfigProvider } from "@ant-design/web3-wagmi";
import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { mainnet } from "wagmi/chains";
import SignDemo from "../../components/SignDemo";

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
const Demo: React.FC = () => {
  return (
    <WagmiWeb3ConfigProvider eip6963 config={config} wallets={[MetaMask()]}>
      <SignDemo />
    </WagmiWeb3ConfigProvider>
  );
};
export default Demo;
