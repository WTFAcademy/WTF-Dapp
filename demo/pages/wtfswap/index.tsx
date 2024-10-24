import React, { useState } from 'react';
import { TokenSelect, type Token } from '@ant-design/web3';
import { ETH, USDT } from '@ant-design/web3-assets/tokens';
import { Card, Input, Button, Row, Col, Space, Typography } from 'antd';
import { SwapOutlined } from '@ant-design/icons';

import WtfLayout from "@/components/WtfLayout";
import styles from "./styles.module.css";

const { Text } = Typography;


export default function Wtfswap() {
  const [token1, setToken1] = useState<Token>(ETH);
  const [token2, setToken2] = useState<Token>(USDT);
  const [amount1, setAmount1] = useState(0);
  const [amount2, setAmount2] = useState(0);


  const handleAmount1Change = (e: any) => {
    setAmount1(parseFloat(e.target.value));
    // todo: setAmount2
    // const a2 = amount1 * 20;
    // setAmount1(a2);
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
                  type="number"
                  onChange={(e) => handleAmount1Change(e)}
                  addonAfter={
                    <TokenSelect value={token1} onChange={setToken1} options={[ETH, USDT]} />
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
                        Balance: 0
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
              onClick={handleSwitch}
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
                    <TokenSelect value={token2} onChange={setToken2} options={[ETH, USDT]} />
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
                        Balance: 0
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
    </WtfLayout>
  );
}
