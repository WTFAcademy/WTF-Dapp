import React from 'react';
import { ConnectButton, Connector } from '@ant-design/web3';
import { useAccount, useSignMessage } from 'wagmi';
import { message } from 'antd';

const DemoInner:React.FC = () => {
  const { signMessageAsync } = useSignMessage();
  const { address } = useAccount();
  const [signLoading, setSignLoading] = React.useState<boolean>(false);

  const doSignature = async () => {
    setSignLoading(true);
    try {
      const signature = await signMessageAsync({
        message: 'You are connecting your Ethereum address with zan.top',
      });
      await runConnectEthAddress({
        chainAddress: address
        signature,
      });
    } catch (error: any) {
      message.error(`Signature failed: ${error.message}`);
    }
    setSignLoading(false);
  };

  const runConnectEthAddress = async (params: { chainAddress?: string; signature: string }) => {
    try {
      const response = await fetch('/api/signatureCheck', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(params),
      })
      const result = await response.json();
      if (result.data) {
        message.success('Signature success');
      } else {
        message.error('Signature failed');
      }
    } catch (error) {
      message.error('An error occurred');
    }
  }
  return (
    <div>
      <Connector
        onConnected={doSignature}
        modalProps={{
          group: false,
        }}
      >
        <ConnectButton loading={signLoading} />
      </Connector>
    </div>
  );
}
export default DemoInner;
