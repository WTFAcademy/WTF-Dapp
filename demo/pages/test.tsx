import { useReadPoolManagerGetAllPools } from "@/utils/contracts";

import { hardhat } from "wagmi/chains";
import { WagmiWeb3ConfigProvider, Hardhat } from "@ant-design/web3-wagmi";
import { Button } from "antd";
import { createConfig, http } from "wagmi";
import { Connector, ConnectButton } from "@ant-design/web3";

const config = createConfig({
  chains: [hardhat],
  transports: {
    [hardhat.id]: http("http://127.0.0.1:8545/"),
  },
});

const CallTest = () => {
  const { data, refetch } = useReadPoolManagerGetAllPools({
    address: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  });
  console.log("get data", data);
  return (
    <>
      {data?.toString()}
      <Button
        onClick={() => {
          refetch();
        }}
      >
        refetch
      </Button>
    </>
  );
};

export default function Web3() {
  return (
    <WagmiWeb3ConfigProvider
      config={config}
      eip6963={{
        autoAddInjectedWallets: true,
      }}
      chains={[Hardhat]}
    >
      <Connector>
        <ConnectButton />
      </Connector>
      <CallTest />
    </WagmiWeb3ConfigProvider>
  );
}
