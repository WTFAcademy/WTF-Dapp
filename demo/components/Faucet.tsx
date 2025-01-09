import React from "react";
import { Flex, Space, message, Divider } from "antd";
import { useAccount } from "@ant-design/web3";
import { useWriteDebugTokenMint } from "@/utils/contracts";
import { getContractAddress } from "@/utils/common";

export default function Faucet() {
  const { account } = useAccount();
  const [loading, setLoading] = React.useState(false);
  const { writeContractAsync } = useWriteDebugTokenMint();

  const claim = async (address: `0x${string}`, name: string) => {
    if (loading) {
      return;
    }
    try {
      setLoading(true);
      await writeContractAsync({
        address,
        // default to 10 TestToken
        args: [
          account?.address as `0x${string}`,
          BigInt("10000000000000000000"),
        ],
      });
      message.success(`Claim 10 ${name} success`);
    } catch (error: any) {
      message.error(error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <Divider />
      <Flex align="center" justify="center">
        <div>领取测试代币：</div>
        {loading ? (
          "Claiming..."
        ) : (
          <Space>
            <a
              type="link"
              onClick={() => {
                claim(getContractAddress("DebugTokenA"), "DTA");
              }}
            >
              DTA
            </a>
            <a
              type="link"
              onClick={() => {
                claim(getContractAddress("DebugTokenB"), "DTB");
              }}
            >
              DTB
            </a>
            <a
              type="link"
              onClick={() => {
                claim(getContractAddress("DebugTokenC"), "DTC");
              }}
            >
              DTC
            </a>
          </Space>
        )}
      </Flex>
    </>
  );
}
