import { createConfig, http } from "wagmi";
import { mainnet } from "wagmi/chains";
 import { WagmiWeb3ConfigProvider, MetaMask } from "@ant-design/web3-wagmi";
 import { Address, NFTCard, Connector, ConnectButton } from "@ant-design/web3";
 import { injected } from "wagmi/connectors";

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

export default function Web3() {
  return (
    <WagmiWeb3ConfigProvider config={config} wallets={[MetaMask()]}>
      <Address format address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9" />
      <NFTCard
        address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9"
        tokenId={641}
      />
       <Connector>
         <ConnectButton />
     </Connector>
    </WagmiWeb3ConfigProvider>
  );
};
