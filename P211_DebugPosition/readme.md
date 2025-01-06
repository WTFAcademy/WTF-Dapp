本节作者：[@愚指导](https://x.com/yudao1024)

这一讲会完成前端和链交互相关的获取流动性列表、添加流动性、移除流动性和提取流动性的逻辑。

---

## 获取流动性列表

我们在之前的[《PositionManager 合约开发》](../P108_PositionManagerc/readme.md)中已经实现了 `getAllPositions` 方法，和上一讲类似，我们直接通过 `useReadPositionManagerGetAllPositions` Hook 来获取所有的流动性列表。

```diff
+ import { useReadPositionManagerGetAllPositions } from "@/utils/contracts";

const PoolListTable: React.FC = () => {
+ const { data = [], refetch } = useReadPositionManagerGetAllPositions({
+   address: getContractAddress("PositionManager"),
+ });

  return (
    <>
      <Table
        rowKey="id"
        scroll={{ x: "max-content" }}
        title={() => (
// ...
        )}
        columns={columns}
+        dataSource={data}
      />
    </>
  );
};
```

## 添加流动性

相比添加交易池来说，添加流动性更麻烦一些，因为添加流动性涉及到 Token 的转移，需要 LP 授权。也就是在添加流动性之前需要先调用 `ERC20` 合约的 `approve` 方法，授权给 `PositionManager` 合约来管理用户的 Token。

我们可以使用 `useWriteErc20Approve` Hook 来授权，使用 `useWritePositionManagerMint` Hook 来添加流动性。

````diff

关键代码如下：

```diff
import {
  useReadPositionManagerGetAllPositions,
+  useWriteErc20Approve
+  useWritePositionManagerMint,
} from "@/utils/contracts";

const PoolListTable: React.FC = () => {
+  const [loading, setLoading] = React.useState(false);
  const [openAddPositionModal, setOpenAddPositionModal] = React.useState(false);
  const { account } = useAccount();
  const { data = [], refetch } = useReadPositionManagerGetAllPositions({
    address: getContractAddress("PositionManager"),
  });

  const { writeContractAsync } = useWritePositionManagerMint();
  const { writeContractAsync: writeErc20Approve } = useWriteErc20Approve();

  return (
    <>
      <Table
        rowKey="id"
        scroll={{ x: "max-content" }}
        title={() => (
          <Flex justify="space-between">
            <div>Positions</div>
            <Space>
              <Button
                type="primary"
+                loading={loading}
                onClick={() => {
                  setOpenAddPositionModal(true);
                }}
              >
                Add
              </Button>
            </Space>
          </Flex>
        )}
        columns={columns}
        dataSource={data}
      />
      <AddPositionModal
        open={openAddPositionModal}
        onCancel={() => {
          setOpenAddPositionModal(false);
        }}
        onCreatePosition={async (createParams) => {
+          console.log("get createParams", createParams);
+          if (account?.address === undefined) {
+            message.error("Please connect wallet first");
+            return;
+          }
+          setOpenAddPositionModal(false);
+          setLoading(true);
+          try {
+            await writeErc20Approve({
+              address: createParams.token0,
+              args: [
+                getContractAddress("PositionManager"),
+                createParams.amount0Desired,
+              ],
+            });
+            await writeErc20Approve({
+              address: createParams.token1,
+              args: [
+                getContractAddress("PositionManager"),
+                createParams.amount1Desired,
+              ],
+            });
+            await writeContractAsync({
+              address: getContractAddress("PositionManager"),
+              args: [
+                {
+                  token0: createParams.token0,
+                  token1: createParams.token1,
+                  index: createParams.index,
+                  amount0Desired: createParams.amount0Desired,
+                  amount1Desired: createParams.amount1Desired,
+                  recipient: account?.address as `0x${string}`,
+                  deadline: createParams.deadline,
+                },
+              ],
+            });
+            refetch();
+          } catch (error: any) {
+            message.error(error.message);
+          } finally {
+            setLoading(false);
+          }
        }}
      />
    </>
  );
};
````

核心逻辑是完善了 `onCreatePosition` 方法，它会调用授权和 Mint 的 `writeContractAsync` 方法，一共会三次唤起钱包签名，注入流动性。

## 移除和提取流动性

我们在每一列的最后添加两个操作按钮 `Remove` 和 `Coolect`，分别调用合约的 `burn` 和 `collect` 方法，提供给 LP 移除流动性并收回自己的 Token。

```tsx
const { writeContractAsync: writePositionManagerBurn } =
  useWritePositionManagerBurn();
const { writeContractAsync: writePositionManagerCollect } =
  useWritePositionManagerCollect();

const columns: TableProps["columns"] = [
  // ...
  {
    title: "Actions",
    key: "actions",
    fixed: "right",
    render: (_, item) => {
      if (item.owner !== account?.address) {
        return "-";
      }
      return (
        <Space className={styles.actions}>
          {item.liquidity > 0 && (
            <a
              onClick={async () => {
                try {
                  await writePositionManagerBurn({
                    address: getContractAddress("PositionManager"),
                    args: [item.id],
                  });
                  refetch();
                } catch (error: any) {
                  message.error(error.message);
                }
              }}
            >
              Remove
            </a>
          )}
          {(item.tokensOwed0 > 0 || item.tokensOwed1 > 0) && (
            <a
              onClick={async () => {
                try {
                  await writePositionManagerCollect({
                    address: getContractAddress("PositionManager"),
                    args: [item.id, account?.address as `0x${string}`],
                  });
                  refetch();
                } catch (error: any) {
                  message.error(error.message);
                }
              }}
            >
              Collect
            </a>
          )}
        </Space>
      );
    },
  },
];
```

上面是核心逻辑的代码，需要注意的是，因为我们在 `Actions` 这一列的操作中需要调用 Hooks，所以我们需要把 `columns` 整体移动到组件内部。

另外我们还需要做一个简单的判断，只允许当前用户操作自己的流动性，以及只能针对 `liquidity` 大于 0 的头寸做移除，针对 `tokensOwed0` 或者 `tokensOwed1` 的头寸做提取。

完成的代码你可以在 [demo/pages/wtfswap/positions.tsx](../demo/pages/wtfswap/positions.tsx) 中查看。

最后的效果如下：

![position](./img/position.png)
