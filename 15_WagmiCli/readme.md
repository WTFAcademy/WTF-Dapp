本节作者：[@愚指导](https://x.com/yudao1024)

在上一讲我们基于 Hardhat 在本地创建了一个合约项目，在未来的 DEX 实战课程中我们会继续基于该项目创建更复杂的合约。伴随着合约越来越复杂，ABI 也会越来越庞大，这时候我们就需要一个工具来帮助我们更好的调试合约。在这一讲中我们将会引导大家给予 Wagmi CLI 自动化的创建用于合约调试的代码，并在项目中使用它，为后续的 DEX 实战课程做准备。

## 初始化 Wagmi CLI

按照下面步骤初始化，你也可以参考 [Wagmi CLI 的官方文档](https://wagmi.sh/cli/getting-started)操作。

安装依赖：

```bash
npm install --save-dev @wagmi/cli
```

修改配置 `demo/wagmi.config.ts`，添加 [hardhat](https://wagmi.sh/cli/api/plugins/hardhat) 和 [react](https://wagmi.sh/cli/api/plugins/react) 插件。

完整配置如下：

```ts
import { defineConfig } from "@wagmi/cli";
import { hardhat } from "@wagmi/cli/plugins";
import { react } from "@wagmi/cli/plugins";

export default defineConfig({
  out: "utils/contracts.ts",
  plugins: [
    hardhat({
      project: "../demo-contract",
    }),
    react(),
  ],
});
```

执行下面命令生成代码：

```bash
npx wagmi generate
```

执行完成后你会看到生成的代码在 `utils/contracts.ts` 中，接下来你就可以更方便的在项目中使用 `utils/contracts.ts` 导出的 React Hooks 来调用合约了。

## 使用 Wagmi CLI 生成的代码

我们继续修改 `demo/pages/web3.tsx` 的代码，将之前使用的 `useReadContract` 和 `useWriteContract` 替换为 Wagmi CLI 生成的代码。

```diff
// ...
-import {
-  createConfig,
-  http,
-  useReadContract,
-  useWriteContract,
-  useWatchContractEvent,
-} from "wagmi";
+import { createConfig, http, useWatchContractEvent } from "wagmi";
 import { injected, walletConnect } from "wagmi/connectors";
+import {
+  useReadMyTokenBalanceOf,
+  useWriteMyTokenMint,
+} from "@/utils/contracts";

// ...
```

修改 `balanceOf` 方法的调用逻辑：

```diff

// ...

-  const result = useReadContract({
-    abi: [
-      {
-        type: "function",
-        name: "balanceOf",
-        stateMutability: "view",
-        inputs: [{ name: "account", type: "address" }],
-        outputs: [{ type: "uint256" }],
-      },
-    ],
+  const result = useReadMyTokenBalanceOf({
     address: contractInfo.find((item) => item.id === chain?.id)
       ?.contractAddress as `0x${string}`,
-    functionName: "balanceOf",
     args: [account?.address as `0x${string}`],
   });

// ...

```

修改 `mint` 方法的调用逻辑：

```diff
-  const { writeContract } = useWriteContract();
+  const { writeContract: mintNFT } = useWriteMyTokenMint();

// ...

     const CallTest = () => {
       {result.data?.toString()}
       <Button
         onClick={() => {
-          writeContract(
+          mintNFT(
             {
-              abi: [
-                {
-                  type: "function",
-                  name: "mint",
-                  stateMutability: "payable",
-                  inputs: [
-                    {
-                      internalType: "uint256",
-                      name: "quantity",
-                      type: "uint256",
-                    },
-                  ],
-                  outputs: [],
-                },
-              ],
               address: contractInfo.find((item) => item.id === chain?.id)
                 ?.contractAddress as `0x${string}`,
-              functionName: "mint",
               args: [BigInt(1)],
               value: parseEther("0.01"),
             },
```

这样我们就完成了 Wagmi CLI 的初始化和使用，在后面的 DEX 实战开发课程中我们基于此可以更加方便的使用 Wagmi CLI 来调试合约，不需要手动搬运 ABI 代码。这除了让你在项目中的代码更简洁以外，也可以让我们可以在合约单元测试外可以更快速的编写一些调试代码，提高开发效率。
