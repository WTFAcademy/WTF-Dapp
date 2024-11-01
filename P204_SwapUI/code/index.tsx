import React, { useState } from 'react';
import { Card, Input, Button, Space, Typography } from 'antd';
import { TokenSelect, type Token } from '@ant-design/web3';
import { ETH, USDT, USDC } from '@ant-design/web3-assets/tokens';
import { SwapOutlined } from '@ant-design/icons';

import WtfLayout from "@/components/WtfLayout";
import styles from "./swap.module.css";

const { Text } = Typography;

export default function Wtfswap() {
  const [tokenA, setTokenA] = useState<Token>(ETH);
  const [tokenB, setTokenB] = useState<Token>(USDT);
  const [amountA, setAmountA] = useState(0);
  const [amountB, setAmountB] = useState(0);
  const [optionsA, setOptionsA] = useState<Token[]>([ETH, USDT, USDC]);
  const [optionsB, setOptionsB] = useState<Token[]>([USDT, ETH, USDC]);

  const handleAmountAChange = (e: any) => {
    setAmountA(parseFloat(e.target.value));
  };


  const handleSwitch = () => {
    setTokenA(tokenB);
    setTokenB(tokenA);
    setAmountA(amountB);
    setAmountB(amountA);
  };

  const handleMax = () => {
  };

  return (
    <WtfLayout>
      <Card title="Swap" className={styles.swapCard}>
        <Card>
          <Input
            variant="borderless"
            value={amountA}
            type="number"
            onChange={(e) => handleAmountAChange(e)}
            addonAfter={
              <TokenSelect value={tokenA} onChange={setTokenA} options={optionsA} />
            }
          />
          <Space className={styles.swapSpace}>
            <Text type="secondary">
              $ 0.0
            </Text>
            <Space>
              <Text type="secondary">
                Balance: 0
              </Text>
              <Button size="small" onClick={handleMax} type="link">
                Max
              </Button>
            </Space>
          </Space>
        </Card>
        <Space className={styles.switchBtn}>
          <Button
            shape="circle"
            icon={<SwapOutlined />}
            onClick={handleSwitch}
          />
        </Space>
        <Card>
          <Input
            variant="borderless"
            value={amountB}
            type="number"
            addonAfter={
              <TokenSelect value={tokenB} onChange={setTokenB} options={optionsB} />
            }
          />
          <Space className={styles.swapSpace}>
            <Text type="secondary">
              $ 0.0
            </Text>
            <Text type="secondary">
              Balance: 0
            </Text>
          </Space>
        </Card>
        <Button type="primary" size="large" block className={styles.swapBtn}>
          Swap
        </Button>
      </Card>
    </WtfLayout>
  );
}
