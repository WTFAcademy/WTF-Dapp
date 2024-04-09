import * as React from 'react';
import { Button, Checkbox, Form, type FormProps, Input } from 'antd';
import { type BaseError, useSendTransaction, useWaitForTransactionReceipt} from 'wagmi';
import { parseEther } from 'viem';

type FieldType = {
  to: `0x${string}`;
  value: string;
};
 
export const SendEth:React.FC = () => {
  const { data: hash, error, isPending, sendTransaction } = useSendTransaction();

  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({ hash });

  const onFinish: FormProps<FieldType>["onFinish"] = (values) => {
    console.log('Success:', values);
    sendTransaction({ to: values.to, value: parseEther(values.value) }) 
  };
  
  const onFinishFailed: FormProps<FieldType>["onFinishFailed"] = (errorInfo) => {
    console.log('Failed:', errorInfo);
  };

  return (
    <Form
      name="basic"
      labelCol={{ span: 8 }}
      wrapperCol={{ span: 16 }}
      style={{ maxWidth: 600 }}
      initialValues={{ remember: true }}
      onFinish={onFinish}
      onFinishFailed={onFinishFailed}
      autoComplete="off"
    >
      <Form.Item<FieldType>
        label="to"
        name="to"
        rules={[{ required: true, message: 'Please input!' }]}
      >
        <Input />
      </Form.Item>

      <Form.Item<FieldType>
        label="value"
        name="value"
        rules={[{ required: true, message: 'Please input!' }]}
      >
        <Input />
      </Form.Item>

      <Form.Item wrapperCol={{ offset: 8, span: 16 }}>
        <Button type="primary" htmlType="submit">
          {isPending ? 'Confirming...' : 'Send'} 
        </Button>
      </Form.Item>

      {hash && <div>Transaction Hash: {hash}</div>} 
      {isConfirming && <div>Waiting for confirmation...</div>} 
      {isConfirmed && <div>Transaction confirmed.</div>} 
      {error && ( 
        <div>Error: {(error as BaseError).shortMessage || error.message}</div> 
      )} 
    </Form>
  )
}
