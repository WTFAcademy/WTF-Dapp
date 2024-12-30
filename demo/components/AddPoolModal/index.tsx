import { Modal, Form, Input, InputNumber, Select, message } from "antd";
import { parsePriceToSqrtPriceX96 } from "@/utils/common";

interface CreatePoolParams {
  token0: `0x${string}`;
  token1: `0x${string}`;
  fee: number;
  tickLower: number;
  tickUpper: number;
  sqrtPriceX96: bigint;
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
      onOk={async () => {
        const values = await form.validateFields().then((values) => {
          if (values.token0 >= values.token1) {
            message.error("Token0 should be less than Token1");
            return false;
          }
          onCreatePool({
            ...values,
            sqrtPriceX96: parsePriceToSqrtPriceX96(values.price),
          });
        });
      }}
    >
      <Form
        layout="vertical"
        form={form}
        initialValues={{
          fee: 3000,
          tickLower: -1000000,
          tickUpper: 1000000,
          price: 1,
        }}
      >
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
          <InputNumber min={0.000001} max={1000000} />
        </Form.Item>
      </Form>
    </Modal>
  );
}
