import React from "react";
import { Flex, Table, Space, Typography, Button, message } from "antd";
import type { TableProps } from "antd";
import WtfLayout from "@/components/WtfLayout";
import AddPoolModal from "@/components/AddPoolModal";
import Link from "next/link";

import { getContractAddress } from "@/utils/common";
import {
  useReadPoolManagerGetAllPools,
  useWritePoolManagerCreateAndInitializePoolIfNecessary,
} from "@/utils/contracts";

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
  const [openAddPoolModal, setOpenAddPoolModal] = React.useState(false);
  const result = useReadPoolManagerGetAllPools({
    address: getContractAddress("PoolManager"),
  });
  console.log("get result", result);
  const { writeContractAsync } =
    useWritePoolManagerCreateAndInitializePoolIfNecessary();
  return (
    <>
      <Table
        rowKey={(record) => `${record.token0}-${record.token1}-${record.index}`}
        title={() => (
          <Flex justify="space-between">
            <div>Pool List</div>
            <Space>
              <Link href="/wtfswap/positions">
                <Button>My Positions</Button>
              </Link>
              <Button
                type="primary"
                onClick={() => {
                  setOpenAddPoolModal(true);
                }}
              >
                Add Pool
              </Button>
            </Space>
          </Flex>
        )}
        columns={columns}
        dataSource={[]}
      />
      <AddPoolModal
        open={openAddPoolModal}
        onCancel={() => {
          setOpenAddPoolModal(false);
        }}
        onCreatePool={async (createParams) => {
          console.log("get createPram", createParams);
          try {
            await writeContractAsync({
              address: getContractAddress("PoolManager"),
              args: [
                {
                  token0: createParams.token0,
                  token1: createParams.token1,
                  fee: createParams.fee,
                  tickLower: createParams.tickLower,
                  tickUpper: createParams.tickUpper,
                  sqrtPriceX96: createParams.sqrtPriceX96,
                },
              ],
            });
            message.success("Create Pool Success");
          } catch (error: any) {
            message.error(error.message);
          }

          setOpenAddPoolModal(false);
        }}
      />
    </>
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
