import React, { forwardRef, useImperativeHandle } from "react";
import type { Token } from "@ant-design/web3";
import { CryptoPrice } from "@ant-design/web3";
import { useReadErc20BalanceOf } from "@/utils/contracts";
import { useAccount } from "wagmi";
import useTokenAddress from "@/hooks/useTokenAddress";

interface Props {
  token?: Token;
}

// 使用 forwardRef 来接收 ref
const Balance = forwardRef((props: Props, ref) => {
  const { address } = useAccount();
  const tokenAddress = useTokenAddress(props.token);
  const { data: balance, refetch } = useReadErc20BalanceOf({
    address: tokenAddress,
    args: [address as `0x${string}`],
    query: {
      enabled: !!tokenAddress,
    },
  });

  // 使用 useImperativeHandle 将 refetch 方法暴露给外部
  useImperativeHandle(ref, () => ({
    refresh: refetch,
  }));

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
});

export default Balance;
