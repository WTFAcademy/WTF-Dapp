import { Modal, Form, Input, InputNumber } from "antd";

interface CreatePositionParams {
  token0: string;
  token1: string;
  index: number;
  amount0Desired: BigInt;
  amount1Desired: BigInt;
  recipient: string;
  deadline: BigInt;
}

interface AddPositionModalProps {
  open: boolean;
  onCancel: () => void;
  onCreatePosition: (params: CreatePositionParams) => void;
}

export default function AddPositionModal(props: AddPositionModalProps) {
  const { open, onCancel, onCreatePosition } = props;
  const [form] = Form.useForm();

  return (
    <Modal
      title="Add Position"
      open={open}
      onCancel={onCancel}
      okText="Create"
      onOk={() => {
        form.validateFields().then((values) => {
          onCreatePosition({
            ...values,
            amount0Desired: BigInt(values.amount0Desired),
            amount1Desired: BigInt(values.amount1Desired),
            deadline: BigInt(Date.now() + 100000),
          });
        });
      }}
    >
      <Form layout="vertical" form={form}>
        <Form.Item required label="Token 0" name="token0">
          <Input />
        </Form.Item>
        <Form.Item required label="Token 1" name="token1">
          <Input />
        </Form.Item>
        <Form.Item required label="Index" name="index">
          <InputNumber />
        </Form.Item>
        <Form.Item required label="Amount0 Desired" name="amount0Desired">
          <Input />
        </Form.Item>
        <Form.Item required label="Amount1 Desired" name="amount1Desired">
          <Input />
        </Form.Item>
      </Form>
    </Modal>
  );
}
