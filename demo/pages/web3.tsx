import { mainnet, sepolia, polygon, hardhat } from "wagmi/chains";
import {
  WagmiWeb3ConfigProvider,
  MetaMask,
  Sepolia,
  Polygon,
  Hardhat,
  WalletConnect,
} from "@ant-design/web3-wagmi";
import {
  Address,
  ConnectButton,
  Connector,
  NFTCard,
  useAccount,
  useProvider,
} from "@ant-design/web3";
import { Button, message } from "antd";
import { parseEther } from "viem";
import { createConfig, http, useWatchContractEvent } from "wagmi";
import { injected, walletConnect } from "wagmi/connectors";
import {
  useReadMyTokenBalanceOf,
  useWriteMyTokenMint,
} from "@/utils/contracts";

const config = createConfig({
  chains: [mainnet, sepolia, polygon, hardhat],
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(),
    [polygon.id]: http(),
    [hardhat.id]: http("http://127.0.0.1:8545/"),
  },
  connectors: [
    injected({
      target: "metaMask",
    }),
    walletConnect({
      projectId: "c07c0051c2055890eade3556618e38a6",
      showQrModal: false,
    }),
  ],
});

const contractInfo = [
  {
    id: 1,
    name: "Ethereum",
    contractAddress: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
  },
  {
    id: 5,
    name: "Sepolia",
    contractAddress: "0x418325c3979b7f8a17678ec2463a74355bdbe72c",
  },
  {
    id: 137,
    name: "Polygon",
    contractAddress: "0x418325c3979b7f8a17678ec2463a74355bdbe72c",
  },
  {
    id: hardhat.id,
    name: "Hardhat",
    contractAddress: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  },
];

const CallTest = () => {
  const { account } = useAccount();
  const { chain } = useProvider();
  const result = useReadMyTokenBalanceOf({
    address: contractInfo.find((item) => item.id === chain?.id)
      ?.contractAddress as `0x${string}`,
    args: [account?.address as `0x${string}`],
  });
  const { writeContract: mintNFT } = useWriteMyTokenMint();

  useWatchContractEvent({
    address: "0xEcd0D12E21805803f70de03B72B1C162dB0898d9",
    abi: [
      {
        anonymous: false,
        inputs: [
          {
            indexed: false,
            internalType: "address",
            name: "minter",
            type: "address",
          },
          {
            indexed: false,
            internalType: "uint256",
            name: "amount",
            type: "uint256",
          },
        ],
        name: "Minted",
        type: "event",
      },
    ],
    eventName: "Minted",
    onLogs() {
      message.success("new minted!");
    },
  });

  return (
    <div>
      {result.data?.toString()}
      <Button
        onClick={() => {
          mintNFT(
            {
              address: contractInfo.find((item) => item.id === chain?.id)
                ?.contractAddress as `0x${string}`,
              args: [BigInt(1)],
              value: parseEther("0.01"),
            },
            {
              onSuccess: () => {
                message.success("Mint Success");
              },
              onError: (err) => {
                message.error(err.message);
              },
            }
          );
        }}
      >
        mint
      </Button>
    </div>
  );
};

export default function Web3() {
  return (
    <WagmiWeb3ConfigProvider
      config={config}
      wallets={[MetaMask(), WalletConnect()]}
      eip6963={{
        autoAddInjectedWallets: true,
      }}
      chains={[Sepolia, Polygon, Hardhat]}
    >
      <Address format address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9" />
      <NFTCard
        address="0xEcd0D12E21805803f70de03B72B1C162dB0898d9"
        tokenId={641}
      />
      <Connector>
        <ConnectButton />
      </Connector>
      <CallTest />
    </WagmiWeb3ConfigProvider>
  );
}
