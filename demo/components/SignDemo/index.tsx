import React from "react";
import { ConnectButton, Connector, useAccount } from "@ant-design/web3";
import { useSignMessage } from "wagmi";
import { message, Space, Button } from "antd";

const SignDemo: React.FC = () => {
  const { signMessageAsync } = useSignMessage();
  const { account } = useAccount();
  const [signLoading, setSignLoading] = React.useState(false);

  const doSignature = async () => {
    setSignLoading(true);
    try {
      const signature = await signMessageAsync({
        message: "test message for WTF-DApp demo",
      });
      await checkSignature({
        address: account?.address,
        signature,
      });
    } catch (error: any) {
      message.error(`Signature failed: ${error.message}`);
    }
    setSignLoading(false);
  };

  const checkSignature = async (params: {
    address?: string;
    signature: string;
  }) => {
    try {
      const response = await fetch("/api/signatureCheck", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(params),
      });
      const result = await response.json();
      if (result.data) {
        message.success("Signature success");
      } else {
        message.error("Signature failed");
      }
    } catch (error) {
      message.error("An error occurred");
    }
  };

  return (
    <Space>
      <Connector>
        <ConnectButton />
      </Connector>
      <Button
        loading={signLoading}
        disabled={!account?.address}
        onClick={doSignature}
      >
        Sign message
      </Button>
    </Space>
  );
};
export default SignDemo;
