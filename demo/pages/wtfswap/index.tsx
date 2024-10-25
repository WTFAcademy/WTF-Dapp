import React, { useState } from 'react';
import { TokenSelect, type Token } from '@ant-design/web3';
import { ETH, USDT, USDC } from '@ant-design/web3-assets/tokens';
import { Card, Input, Button, Space, Typography } from 'antd';
import { SwapOutlined } from '@ant-design/icons';

import WtfLayout from "@/components/WtfLayout";
import styles from "./swap.module.css";

const { Text } = Typography;


export default function Wtfswap() {
  const [token1, setToken1] = useState<Token>(ETH);
  const [token2, setToken2] = useState<Token>(USDT);
  const [amount1, setAmount1] = useState(0);
  const [amount2, setAmount2] = useState(0);
  const [options1, setOptions1] = useState<Token[]>([ETH, USDT, USDC]);;
  const [options2, setOptions2] = useState<Token[]>([USDT, ETH, USDC]);;

  const handleAmount1Change = (e: any) => {
    setAmount1(parseFloat(e.target.value));
    // todo: setAmount2
  };


  const handleSwitch = () => {
    setToken1(token2);
    setToken2(token1);
    setAmount1(amount2);
    setAmount2(amount1);
  };

  const handleMax = () => {
    // max 
  };

  return (
    <WtfLayout>
      <Card title="Swap" className={styles.swapCard}>
        <Card>
          <Input
            variant="borderless"
            value={amount1}
            type="number"
            onChange={(e) => handleAmount1Change(e)}
            addonAfter={
              <TokenSelect value={token1} onChange={setToken1} options={options1} />
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
            value={amount2}
            variant="borderless"
            type="number"
            addonAfter={
              <TokenSelect value={token2} onChange={setToken2} options={options2} />
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
        <Button type="primary" size="large" block>
          Swap
        </Button>
      </Card>
    </WtfLayout>
  );
}
