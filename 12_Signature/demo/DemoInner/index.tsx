import React from 'react';
import { ConnectButton, Connector } from '@ant-design/web3';
import { useAccount, useSignMessage } from 'wagmi';

import { message } from 'antd';
import { useLatest } from 'ahooks';
const DemoInner:React.FC = () => {
  const { signMessageAsync } = useSignMessage();
  const { address } = useAccount();
  const addressRef = useLatest(address);
  const [signLoading, setSignLoading] = React.useState<boolean>(false);

  const doSignature = async () => {
    setSignLoading(true);
    try {
      const signature = await signMessageAsync({
        message: 'You are connecting your Ethereum address with zan.top',
      });
      console.log('signature:', signature);
      console.log('address:', addressRef.current);
      await runConnectEthAddress({
        chainAddress: addressRef.current,
        signature,
      });
    } catch (error: any) {
      message.error(`Signature failed: ${error.message}`);
    }

    setSignLoading(false);
  };

  const runConnectEthAddress = async (params: { chainAddress?: string; signature: string }) => {
    // do something
  }
  return (
    <div>
      <Connector
+       onConnected={doSignature}
        modalProps={{
          group: false,
          footer: (
            <>
              Powered by{' '}
              <a
                href="https://web3.ant.design/"
                target="_blank"
                rel="noreferrer"
              >
                Ant Design Web3
              </a>
            </>
          ),
        }}
      >
        <ConnectButton loading={signLoading} />
      </Connector>
    </div>
  );
}
export default DemoInner;
