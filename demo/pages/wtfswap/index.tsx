import React, { useState } from "react";
import { TokenSelect, type Token } from "@ant-design/web3";
import { Card, Input, Button, Space, Typography } from "antd";
import { SwapOutlined } from "@ant-design/icons";
import { uniq } from "lodash-es";

import WtfLayout from "@/components/WtfLayout";
import Balance from "@/components/Balance";
import styles from "./swap.module.css";

import {
  useReadPoolManagerGetPairs,
  useWriteSwapRouterExactInput,
  useWriteSwapRouterQuoteExactOutput,
  useSimulateSwapRouterQuoteExactInput,
  useSimulateSwapRouterQuoteExactOutput,
} from "@/utils/contracts";
import useTokenAddress from "@/hooks/useTokenAddress";
import { getContractAddress, getTokenInfo } from "@/utils/common";
import { TickMath } from "@uniswap/v3-sdk";

const { Text } = Typography;

function Swap() {
  const [tokenA, setTokenA] = useState<Token>();
  const [tokenB, setTokenB] = useState<Token>();
  const tokenAddressA = useTokenAddress(tokenA);
  const tokenAddressB = useTokenAddress(tokenB);
  const [amountA, setAmountA] = useState(0);
  const [amountB, setAmountB] = useState(0);

  const { data: quoteAmountB, refetch: fetchQuoteAmountB } =
    useSimulateSwapRouterQuoteExactInput({
      address: getContractAddress("SwapRouter"),
      args: [
        {
          tokenIn: tokenAddressA as `0x${string}`,
          tokenOut: tokenAddressB as `0x${string}`,
          indexPath: [0],
          amountIn: isNaN(amountA)
            ? BigInt(0)
            : BigInt(amountA) * BigInt(10 ** (tokenA?.decimal || 18)),
          sqrtPriceLimitX96:
            BigInt(TickMath.MIN_SQRT_RATIO.toString()) + BigInt(1),
        },
      ],
      query: {
        enabled: false,
      },
    });

  console.log("quoteAmountB", quoteAmountB?.result);

  const handleAmountAChange = (e: any) => {
    const value = parseFloat(e.target.value);
    setAmountA(value);
    if (!isNaN(value)) {
      fetchQuoteAmountB();
    }
  };

  const handleAmountBChange = (e: any) => {
    const value = parseFloat(e.target.value);
    setAmountB(value);
  };

  const handleSwitch = () => {
    setTokenA(tokenB);
    setTokenB(tokenA);
    setAmountA(amountB);
    setAmountB(amountA);
  };

  const { data: pairs = [] } = useReadPoolManagerGetPairs({
    address: getContractAddress("PoolManager"),
  });

  const options: Token[] = uniq(
    pairs.map((pair) => [pair.token0, pair.token1]).flat()
  ).map(getTokenInfo);

  return (
    <Card title="Swap" className={styles.swapCard}>
      <Card>
        <Input
          variant="borderless"
          value={amountA}
          type="number"
          onChange={(e) => handleAmountAChange(e)}
          addonAfter={
            <TokenSelect
              value={tokenA}
              onChange={setTokenA}
              options={options}
            />
          }
        />
        <Space className={styles.swapSpace}>
          <Text type="secondary"></Text>
          <Text type="secondary">
            Balance: <Balance token={tokenA} />
          </Text>
        </Space>
      </Card>
      <Space className={styles.switchBtn}>
        <Button shape="circle" icon={<SwapOutlined />} onClick={handleSwitch} />
      </Space>
      <Card>
        <Input
          value={amountB}
          variant="borderless"
          type="number"
          onChange={(e) => handleAmountBChange(e)}
          addonAfter={
            <TokenSelect
              value={tokenB}
              onChange={setTokenB}
              options={options}
            />
          }
        />
        <Space className={styles.swapSpace}>
          <Text type="secondary"></Text>
          <Text type="secondary">
            Balance: <Balance token={tokenB} />
          </Text>
        </Space>
      </Card>
      <Button
        type="primary"
        size="large"
        block
        className={styles.swapBtn}
        onClick={() => {}}
      >
        Swap
      </Button>
    </Card>
  );
}

export default function Wtfswap() {
  return (
    <WtfLayout>
      <Swap />
    </WtfLayout>
  );
}
