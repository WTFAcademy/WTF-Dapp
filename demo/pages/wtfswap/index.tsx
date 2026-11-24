import React, { useState, useEffect, useMemo } from "react";
import { TokenSelect, useAccount, type Token } from "@ant-design/web3";
import { Card, Input, Button, Space, Typography, message } from "antd";
import { SwapOutlined } from "@ant-design/icons";
import { uniq } from "lodash-es";

import WtfLayout from "@/components/WtfLayout";
import Balance from "@/components/Balance";
import Faucet from "@/components/Faucet";
import styles from "./swap.module.css";

import { usePublicClient } from "wagmi";
import { swapRouterAbi } from "@/utils/contracts";

import {
  useReadPoolManagerGetPairs,
  useReadIPoolManagerGetAllPools,
  useWriteSwapRouterExactInput,
  useWriteSwapRouterExactOutput,
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
  const { data: pairs } = useReadPoolManagerGetPairs({
    address: getContractAddress("PoolManager"),
  });
  const tokens = useMemo(
    () => uniq((pairs ?? []).flatMap(({ token0, token1 }) => [token0, token1])).map(getTokenInfo),
    [pairs],
  );
  const [selectedTokenA, setTokenA] = useState<Token>();
  const [selectedTokenB, setTokenB] = useState<Token>();
  const tokenA = selectedTokenA ?? tokens[0];
  const tokenB = selectedTokenB ?? tokens[1];
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
  // 是否是指定输入（否则就是指定输出）
  const [isExactInput, setIsExactInput] = useState(true);
  // 两个代币的数量
  const [amountA, setAmountA] = useState(0);
  const [amountB, setAmountB] = useState(0);
  const { account } = useAccount();

  const { data: pools } = useReadIPoolManagerGetAllPools({
    address: getContractAddress("PoolManager"),
  });
  const swapPools = useMemo(() => {
    const matching = (pools ?? []).filter(
      (pool) => pool.token0 === token0 && pool.token1 === token1 && pool.liquidity > 0,
    );
    return matching.sort((a, b) => {
      if (a.tick !== b.tick) {
        return zeroForOne ? Number(b.tick - a.tick) : Number(a.tick - b.tick);
      }
      return a.fee - b.fee;
    });
  }, [pools, token0, token1, zeroForOne]);
  const swapIndexPath = useMemo(() => swapPools.map((pool) => pool.index), [swapPools]);
  const sqrtPriceLimitX96 = computeSqrtPriceLimitX96(swapPools, zeroForOne);
  const publicClient = usePublicClient();
  const sourceAmount = isExactInput ? amountA : amountB;
  const handleAmountAChange = (e: any) => {
    const value = parseFloat(e.target.value);
    setAmountA(value);
    setIsExactInput(true);
  };

  const handleAmountBChange = (e: any) => {
    const value = parseFloat(e.target.value);
    setAmountB(value);
    setIsExactInput(false);
  };

  const handleSwitch = () => {
    setTokenA(tokenB);
    setTokenB(tokenA);
    setAmountA(amountB);
    setAmountB(amountA);
  };

  useEffect(() => {
    if (!publicClient || !tokenAddressA || !tokenAddressB || !sourceAmount) {
      return;
    }
    if (tokenAddressA === tokenAddressB) {
      message.error("Please select different tokens");
      return;
    }

    let current = true;
    const route = {
      tokenIn: tokenAddressA,
      tokenOut: tokenAddressB,
      indexPath: swapIndexPath,
      sqrtPriceLimitX96,
    };
    const quote = isExactInput
      ? publicClient.simulateContract({
          address: getContractAddress("SwapRouter"),
          abi: swapRouterAbi,
          functionName: "quoteExactInput",
          args: [{ ...route, amountIn: parseAmountToBigInt(sourceAmount, tokenA) }],
        })
      : publicClient.simulateContract({
          address: getContractAddress("SwapRouter"),
          abi: swapRouterAbi,
          functionName: "quoteExactOutput",
          args: [{ ...route, amountOut: parseAmountToBigInt(sourceAmount, tokenB) }],
        });

    void quote.then(({ result }) => {
      if (!current) return;
      if (isExactInput) {
        setAmountB(parseBigIntToAmount(result, tokenB));
      } else {
        setAmountA(parseBigIntToAmount(result, tokenA));
      }
    }).catch((error: Error) => {
      if (current) message.error(error.message);
    });

    return () => {
      current = false;
    };
  }, [
    publicClient, tokenAddressA, tokenAddressB, swapIndexPath,
    sqrtPriceLimitX96, isExactInput, sourceAmount, tokenA, tokenB,
  ]);
  const { writeContractAsync: writeExactInput } =
    useWriteSwapRouterExactInput();
  const { writeContractAsync: writeExactOutput } =
    useWriteSwapRouterExactOutput();
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
            <TokenSelect value={tokenA} onChange={setTokenA} options={tokens} />
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
            <TokenSelect value={tokenB} onChange={setTokenB} options={tokens} />
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
          try {
            if (isExactInput) {
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
              await writeApprove({
                address: tokenAddressA!,
                args: [getContractAddress("SwapRouter"), swapParams.amountIn],
              });
              await writeExactInput({
                address: getContractAddress("SwapRouter"),
                args: [swapParams],
              });
            } else {
              const swapParams = {
                tokenIn: tokenAddressA!,
                tokenOut: tokenAddressB!,
                amountOut: parseAmountToBigInt(amountB, tokenB),
                amountInMaximum: parseAmountToBigInt(
                  Math.ceil(amountA),
                  tokenA
                ),
                recipient: account?.address as `0x${string}`,
                deadline: BigInt(Math.floor(Date.now() / 1000) + 1000),
                sqrtPriceLimitX96,
                indexPath: swapIndexPath,
              };
              console.log("swapParams", swapParams);
              await writeApprove({
                address: tokenAddressA!,
                args: [
                  getContractAddress("SwapRouter"),
                  swapParams.amountInMaximum,
                ],
              });
              await writeExactOutput({
                address: getContractAddress("SwapRouter"),
                args: [swapParams],
              });
            }
            message.success("Swap success");
            setAmountA(NaN);
            setAmountB(NaN);
          } catch (e: any) {
            message.error(e.message);
          } finally {
            setLoading(false);
          }
        }}
      >
        Swap
      </Button>
      <Faucet />
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
