import type { Token } from "@ant-design/web3";
import { CryptoPrice } from "@ant-design/web3";
import { useReadErc20BalanceOf } from "@/utils/contracts";
import { useAccount, useChainId } from "wagmi";

interface Props {
  token?: Token;
}

export default function Balance(props: Props) {
  const { address } = useAccount();
  const chainId = useChainId();
  const { data: balance } = useReadErc20BalanceOf({
    address: props.token?.availableChains.find(
      (item) => item.chain.id === chainId
    )?.contract as `0x${string}`,
    args: [address as `0x${string}`],
    query: {
      enabled: !!(address && chainId),
    },
  });
  return balance === undefined ? (
    "-"
  ) : (
    <CryptoPrice value={balance} symbol={props.token?.symbol} />
  );
}
