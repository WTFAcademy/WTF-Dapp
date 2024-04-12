import React from "react";
import { MetaMask, WagmiWeb3ConfigProvider} from "@ant-design/web3-wagmi";
import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { mainnet, sepolia } from "wagmi/chains";
import { ConnectButton, Connector } from '@ant-design/web3';
import { SendEth } from "../../components/SendEth";


const config = createConfig({
  chains: [mainnet, sepolia],
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(),
  },
  connectors: [
    injected({
      target: "metaMask",
    }),
  ],
});
const TransactionDemo: React.FC = () => {

  return (
    <WagmiWeb3ConfigProvider
      config={config}
      eip6963={{
        autoAddInjectedWallets: true,
      }}
      wallets={[MetaMask()]}
    >
      <Connector>
        <ConnectButton />
      </Connector>
      <SendEth />
    </WagmiWeb3ConfigProvider>
  );
};
export default TransactionDemo;
