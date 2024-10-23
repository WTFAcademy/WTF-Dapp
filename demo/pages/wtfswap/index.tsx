import React, { useState } from 'react';
import { Card, Select, Input, Button, Row, Col, Typography, Space, Avatar } from 'antd';
import { SwapOutlined } from '@ant-design/icons';

import WtfLayout from "@/components/WtfLayout";
import styles from "./styles.module.css";

const { Option } = Select;
const { Text } = Typography;

export default function Wtfswap() {
  const [token1, setToken1] = useState('ETH');
  const [token2, setToken2] = useState('XRP');
  const [amount1, setAmount1] = useState(0);
  const [amount2, setAmount2] = useState(0);

  const tokenList = [
    { symbol: 'ETH', balance: 23491 },
    { symbol: 'XRP', balance: 0 },
    { symbol: 'USDT', balance: 10000 },
    { symbol: 'DAI', balance: 5000 },
  ];

  const handleSwap = () => {
    setToken1(token2);
    setToken2(token1);
    setAmount1(0);
    setAmount2(0);
  };

  const handleMax = () => {
    const selectedToken = tokenList.find((token) => token.symbol === token1);
    setAmount1(selectedToken.balance);
    setAmount2(selectedToken.balance); 
  };


  return (<WtfLayout>
    <div>
      <Card title="Swap" className={styles.swapcard}>
        <Row gutter={[16, 16]}>
          <Col span={24}>
            <Card>
              <Space direction="vertical" style={{ width: '100%' }}>
                <Input
                  size="large"
                  placeholder="0"
                  variant="borderless"
                  value={amount1}
                  // onChange={(e) => setAmount1(e.target.value)}
                  addonAfter={
                    <Select className={styles.swapselect} variant="borderless" defaultValue="ETH" value={token1} onChange={(value) => setToken1(value)}>
                      {tokenList.map((token) => (
                        <Option className={styles.swapoption} key={token.symbol} value={token.symbol}>
                          <div style={{ display: 'flex', alignItems: 'center' }}>
                            <Avatar src="https://coin-images.coingecko.com/coins/images/6319/large/usdc.png?1696506694" size="small" style={{ marginRight: '8px' }} />
                            {token.symbol}
                          </div>
                        </Option>
                      ))}
                    </Select>
                  }
                />

                <Row style={{ width: '100%' }} align="middle">
                  <Col flex="1">
                    <Text type="secondary">
                      $ 0.0
                    </Text>
                  </Col>
                  <Col>
                    <Space style={{ justifyContent: 'flex-end' }}>
                      <Text type="secondary">
                        Balance: {tokenList.find((token) => token.symbol === token1)?.balance}
                      </Text>
                      <Button size="small" onClick={handleMax} type="link">
                        Max
                      </Button>
                    </Space>
                  </Col>
                </Row>
              </Space>
            </Card>
          </Col>

          <Col span={24} style={{ textAlign: 'center' }}>
            <Button
              shape="circle"
              icon={<SwapOutlined />}
              onClick={handleSwap}
              style={{ fontSize: '20px' }}
            />
          </Col>

          <Col span={24}>
            <Card>
              <Space direction="vertical" style={{ width: '100%' }}>
                <Input
                  size="small"
                  placeholder="0"
                  value={amount2}
                  readOnly
                  variant="borderless"
                  addonAfter={
                    <Select className={styles.swapselect} defaultValue="XRP" value={token2} onChange={(value) => setToken2(value)}>
                     {tokenList.map((token) => (
                        <Option key={token.symbol} value={token.symbol}>
                          <div style={{ display: 'flex', alignItems: 'center' }}>
                            <Avatar src="https://coin-images.coingecko.com/coins/images/6319/large/usdc.png?1696506694" size="small" style={{ marginRight: '8px' }} />
                            {token.symbol}
                          </div>
                        </Option>
                      ))}
                    </Select>
                  }
                />
                <Row style={{ width: '100%' }} align="middle">
                  <Col flex="1">
                    <Text type="secondary">
                      $ 0.0
                    </Text>
                  </Col>
                  <Col>
                    <Space style={{ justifyContent: 'flex-end' }}>
                      <Text type="secondary">
                        Balance: {tokenList.find((token) => token.symbol === token1)?.balance}
                      </Text>
                    </Space>
                  </Col>
                </Row>
              </Space>

            </Card>
          </Col>

          <Col span={24}>
            <Button type="primary" size="large" block>
              Swap
            </Button>
          </Col>
        </Row>
      </Card>
    </div>
  </WtfLayout>);
}
