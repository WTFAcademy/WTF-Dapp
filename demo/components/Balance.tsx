import React from "react";
import type { Token } from "@ant-design/web3";
import { CryptoPrice } from "@ant-design/web3";
import { useReadErc20BalanceOf } from "@/utils/contracts";
import { useAccount } from "wagmi";
import useTokenAddress from "@/hooks/useTokenAddress";

interface Props {
  token?: Token;
}

export default function Balance(props: Props) {
  const { address } = useAccount();
  const tokenAddress = useTokenAddress(props.token);
  const { data: balance } = useReadErc20BalanceOf({
    address: tokenAddress,
    args: [address as `0x${string}`],
    query: {
      enabled: !!tokenAddress,
      // 每 3 秒刷新一次
      refetchInterval: 3000,
    },
  });

  return balance === undefined ? (
    "-"
  ) : (
    <CryptoPrice
      value={balance}
      symbol={props.token?.symbol}
      decimals={props.token?.decimal}
      fixed={2}
    />
  );
}
