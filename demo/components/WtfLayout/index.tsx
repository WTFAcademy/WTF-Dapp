import React from "react";
import Header from "./Header";
import styles from "./styles.module.css";
import {
  MetaMask,
  OkxWallet,
  TokenPocket,
  WagmiWeb3ConfigProvider,
  WalletConnect,
  Hardhat,
  Mainnet,
} from "@ant-design/web3-wagmi";
import { QueryClient } from "@tanstack/react-query";
import { createConfig, http, useAccount } from "wagmi";
import { mainnet, hardhat } from "wagmi/chains";
import { walletConnect } from "wagmi/connectors";

const queryClient = new QueryClient();

const config = createConfig({
  chains: [mainnet, hardhat],
  transports: {
    [mainnet.id]: http(),
    [hardhat.id]: http("http://127.0.0.1:8545/"),
  },
  connectors: [
    walletConnect({
      showQrModal: false,
      projectId: "c07c0051c2055890eade3556618e38a6",
    }),
  ],
});

interface WtfLayoutProps {
  children: React.ReactNode;
}

const LayoutContent: React.FC<WtfLayoutProps> = ({ children }) => {
  const { address } = useAccount();
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    setLoading(false);
  }, []);

  if (loading || !address) {
    return <div className={styles.connectTip}>Please Connect First.</div>;
  }
  return children;
};

const WtfLayout: React.FC<WtfLayoutProps> = ({ children }) => {
  return (
    <WagmiWeb3ConfigProvider
      eip6963={{
        autoAddInjectedWallets: true,
      }}
      chains={[Mainnet, Hardhat]}
      ens
      wallets={[
        MetaMask(),
        WalletConnect(),
        TokenPocket({
          group: "Popular",
        }),
        OkxWallet(),
      ]}
      config={config}
      queryClient={queryClient}
    >
      <div className={styles.layout}>
        <Header />
        <LayoutContent>{children}</LayoutContent>
      </div>
    </WagmiWeb3ConfigProvider>
  );
};

export default WtfLayout;
