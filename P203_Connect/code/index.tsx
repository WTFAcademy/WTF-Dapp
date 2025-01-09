import React from "react";
import Header from "./Header";
import {
  MetaMask,
  OkxWallet,
  TokenPocket,
  WagmiWeb3ConfigProvider,
  WalletConnect,
  Hardhat,
  Mainnet,
} from "@ant-design/web3-wagmi";

interface WtfLayoutProps {
  children: React.ReactNode;
}

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
      walletConnect={{
        projectId: "c07c0051c2055890eade3556618e38a6",
      }}
    >
      <Header />
      {children}
    </WagmiWeb3ConfigProvider>
  );
};

export default WtfLayout;
