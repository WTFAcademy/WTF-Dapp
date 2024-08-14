import { useReadSwapRouterQuoteExactInput } from "@/utils/contracts";

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
  const { data, refetch } = useReadSwapRouterQuoteExactInput({
    address: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
    args: [
      {
        tokenIn: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
        tokenOut: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
        indexPath: [],
        amountIn: BigInt(123),
        sqrtPriceLimitX96: BigInt(123),
      },
    ],
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
