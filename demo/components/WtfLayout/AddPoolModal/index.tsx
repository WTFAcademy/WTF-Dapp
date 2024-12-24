import { Modal, Form, Input, InputNumber, Select } from "antd";
import { encodeSqrtRatioX96 } from "@uniswap/v3-sdk";

interface CreatePoolParams {
  token0: string;
  token1: string;
  fee: number;
  tickLower: number;
  tickUpper: number;
  sqrtPriceX96: BigInt;
}

interface AddPoolModalProps {
  open: boolean;
  onCancel: () => void;
  onCreatePool: (params: CreatePoolParams) => void;
}

export default function AddPoolModal(props: AddPoolModalProps) {
  const { open, onCancel, onCreatePool } = props;
  const [form] = Form.useForm();

  return (
    <Modal
      title="Add Pool"
      open={open}
      onCancel={onCancel}
      okText="Create"
      onOk={() => {
        form.validateFields().then((values) => {
          onCreatePool({
            ...values,
            sqrtPriceX96: BigInt(
              encodeSqrtRatioX96(values.price, 1).toString()
            ),
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
        <Form.Item required label="Fee" name="fee">
          <Select>
            <Select.Option value={3000}>0.3%</Select.Option>
            <Select.Option value={500}>0.05%</Select.Option>
            <Select.Option value={10000}>1%</Select.Option>
          </Select>
        </Form.Item>
        <Form.Item required label="Tick Lower" name="tickLower">
          <InputNumber />
        </Form.Item>
        <Form.Item required label="Tick Upper" name="tickUpper">
          <InputNumber />
        </Form.Item>
        <Form.Item required label="Init Price(token1/token0)" name="price">
          <InputNumber />
        </Form.Item>
      </Form>
    </Modal>
  );
}
