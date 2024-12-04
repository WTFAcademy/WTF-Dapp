import React from "react";
import { Flex, Table, Space, Typography, Button } from "antd";
import type { TableProps } from "antd";
import WtfLayout from "@/components/WtfLayout";
import Link from "next/link";
import styles from "./pool.module.css";

const columns: TableProps["columns"] = [
  {
    title: "Token 0",
    dataIndex: "token0",
    key: "token0",
  },
  {
    title: "Token 1",
    dataIndex: "token1",
    key: "token1",
  },
  {
    title: "Index",
    dataIndex: "index",
    key: "index",
  },
  {
    title: "Fee",
    dataIndex: "fee",
    key: "fee",
  },
  {
    title: "Fee Protocol",
    dataIndex: "feeProtocol",
    key: "feeProtocol",
  },
  {
    title: "Tick Lower",
    dataIndex: "tickLower",
    key: "tickLower",
  },
  {
    title: "Tick Upper",
    dataIndex: "tickUpper",
    key: "tickUpper",
  },
  {
    title: "Tick",
    dataIndex: "tick",
    key: "tick",
  },
  {
    title: "Price",
    dataIndex: "sqrtPriceX96",
    key: "sqrtPriceX96",
    render: (value: bigint) => {
      return value.toString();
    },
  },
];

const PoolListTable: React.FC = () => {
  const data = [
    {
      token0: "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
      token1: "0xEcd0D12E21805803f70de03B72B1C162dB0898d9",
      index: 0,
      fee: 3000,
      feeProtocol: 0,
      tickLower: -100000,
      tickUpper: 100000,
      tick: 1000,
      sqrtPriceX96: BigInt("7922737261735934252089901697281"),
    },
  ];
  return (
    <Table
      title={() => (
        <Flex justify="space-between">
          <div>Pool List</div>
          <Space>
            <Link href="/wtfswap/positions">
              <Button>My Positions</Button>
            </Link>
            <Button type="primary">Add Pool</Button>
          </Space>
        </Flex>
      )}
      columns={columns}
      dataSource={data}
    />
  );
};

export default function WtfswapPool() {
  return (
    <WtfLayout>
      <div className={styles.container}>
        <Typography.Title level={2}>Pool</Typography.Title>
        <PoolListTable />
      </div>
    </WtfLayout>
  );
}
