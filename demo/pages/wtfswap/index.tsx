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
import { getContractAddress, getTokenInfo } from "@/utils/common";

const { Text } = Typography;

function Swap() {
  const [tokenA, setTokenA] = useState<Token>();
  const [tokenB, setTokenB] = useState<Token>();
  const [amountA, setAmountA] = useState(0);
  const [amountB, setAmountB] = useState(0);

  const handleAmountAChange = (e: any) => {
    setAmountA(parseFloat(e.target.value));
    // todo: setAmountB
  };

  const handleSwitch = () => {
    setTokenA(tokenB);
    setTokenB(tokenA);
    setAmountA(amountB);
    setAmountB(amountA);
  };

  const handleMax = () => {
    // max
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
          <Space>
            <Text type="secondary">
              Balance: <Balance token={tokenA} />
            </Text>
            <Button size="small" onClick={handleMax} type="link">
              Max
            </Button>
          </Space>
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
