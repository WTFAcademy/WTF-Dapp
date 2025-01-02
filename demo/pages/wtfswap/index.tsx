import React, { useState } from "react";
import { TokenSelect, useAccount, type Token } from "@ant-design/web3";
import { Card, Input, Button, Space, Typography, message } from "antd";
import { SwapOutlined } from "@ant-design/icons";
import { uniq } from "lodash-es";

import WtfLayout from "@/components/WtfLayout";
import Balance from "@/components/Balance";
import styles from "./swap.module.css";

import { usePublicClient } from "wagmi";
import { swapRouterAbi } from "@/utils/contracts";

import {
  useReadPoolManagerGetPairs,
  useReadIPoolManagerGetAllPools,
  useWriteSwapRouterExactInput,
  useWriteErc20Approve,
} from "@/utils/contracts";
import useTokenAddress from "@/hooks/useTokenAddress";
import {
  getContractAddress,
  getTokenInfo,
  parseAmountToBigInt,
  parseBigIntToAmount,
  computeSqrtPriceLimitX96,
} from "@/utils/common";

const { Text } = Typography;

function Swap() {
  const [loading, setLoading] = useState(false);
  // 用户选择的两个代币
  const [tokenA, setTokenA] = useState<Token>();
  const [tokenB, setTokenB] = useState<Token>();
  // 两个代币的地址
  const tokenAddressA = useTokenAddress(tokenA);
  const tokenAddressB = useTokenAddress(tokenB);
  // 按照地址大小排序
  const [token0, token1] =
    tokenAddressA && tokenAddressB && tokenAddressA < tokenAddressB
      ? [tokenAddressA, tokenAddressB]
      : [tokenAddressB, tokenAddressA];
  // 是否是 token0 来交换 token1
  const zeroForOne = token0 === tokenAddressA;
  // 两个代币的数量
  const [amountA, setAmountA] = useState(0);
  const [amountB, setAmountB] = useState(0);
  const { account } = useAccount();

  // 获取所有的交易对
  const { data: pairs = [] } = useReadPoolManagerGetPairs({
    address: getContractAddress("PoolManager"),
  });

  // 获取所有的代币信息
  const options: Token[] = uniq(
    pairs.map((pair) => [pair.token0, pair.token1]).flat()
  ).map(getTokenInfo);

  // 获取所有的交易池
  const { data: pools = [] } = useReadIPoolManagerGetAllPools({
    address: getContractAddress("PoolManager"),
  });

  // 计算交易池的交易顺序
  const swapPools = pools.filter((pool) => {
    return pool.token0 === token0 && pool.token1 === token1;
  });
  const swapIndexPath: number[] = swapPools
    .sort((a, b) => {
      // 简单处理，按照价格排序，再按照手续费排序，优先在价格低的池子中交易（按照 tick 判断），如果价格一样，就在手续费低的池子里面交易
      if (a.tick !== b.tick) {
        return a.tick > b.tick ? 1 : -1;
      }
      return a.fee - b.fee;
    })
    .map((pool) => pool.index);

  // 计算本次交易的价格限制
  const sqrtPriceLimitX96 = computeSqrtPriceLimitX96(swapPools, zeroForOne);

  const publicClient = usePublicClient();

  const updateAmountBWithAmountA = async (value: number) => {
    if (!publicClient || !tokenAddressA || !tokenAddressB) {
      return;
    }
    try {
      const newAmountB = await publicClient.simulateContract({
        address: getContractAddress("SwapRouter"),
        abi: swapRouterAbi,
        functionName: "quoteExactInput",
        args: [
          {
            tokenIn: tokenAddressA,
            tokenOut: tokenAddressB,
            indexPath: swapIndexPath,
            amountIn: parseAmountToBigInt(value, tokenA),
            sqrtPriceLimitX96,
          },
        ],
      });
      setAmountB(parseBigIntToAmount(newAmountB.result, tokenB));
    } catch (e: any) {
      message.error(e.message);
    }
  };

  const handleAmountAChange = (e: any) => {
    const value = parseFloat(e.target.value);
    setAmountA(value);
    if (!isNaN(value)) {
      updateAmountBWithAmountA(value);
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

  const { writeContractAsync } = useWriteSwapRouterExactInput();
  const { writeContractAsync: writeApprove } = useWriteErc20Approve();

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
        disabled={!tokenAddressA || !tokenAddressB || !amountA || !amountB}
        loading={loading}
        onClick={async () => {
          setLoading(true);
          const swapParams = {
            tokenIn: tokenAddressA!,
            tokenOut: tokenAddressB!,
            amountIn: parseAmountToBigInt(amountA, tokenA),
            amountOutMinimum: parseAmountToBigInt(amountB, tokenB),
            recipient: account?.address as `0x${string}`,
            deadline: BigInt(Math.floor(Date.now() / 1000) + 1000),
            sqrtPriceLimitX96,
            indexPath: swapIndexPath,
          };
          console.log("swapParams", swapParams);
          try {
            await writeApprove({
              address: tokenAddressA!,
              args: [getContractAddress("SwapRouter"), swapParams.amountIn],
            });
            await writeContractAsync({
              address: getContractAddress("SwapRouter"),
              args: [swapParams],
            });
            message.success("Swap success");
          } catch (e: any) {
            message.error(e.message);
          } finally {
            setLoading(false);
          }
        }}
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
