In the previous session, we set up a contract project on your local machine using Hardhat. As we progress in our DEX practical courses, we will continue to build increasingly complex contracts based on this foundation. With this complexity, the ABI will also expand. At this stage, a tool to assist in contract debugging becomes essential. In this session, we'll introduce you to using Wagmi CLI to automatically generate debugging code for contracts and integrate it into your project, preparing you for the upcoming DEX practical courses.

---

## Setting Up Wagmi CLI

Follow the steps below to get started, or consult the [official Wagmi CLI documentation](https://wagmi.sh/cli/getting-started) for more details.

Install dependencies:

```bash
npm install --save-dev @wagmi/cli
```

Update the `demo/wagmi.config.ts` configuration file to include the [hardhat](https://wagmi.sh/cli/api/plugins/hardhat) and [react](https://wagmi.sh/cli/api/plugins/react) plugins.

Here is the complete configuration:

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

To generate code, use the following command: 

```bash
npx wagmi generate
```

Once the execution is complete, you'll find the generated code in `utils/contracts.ts`. After that, you can easily use the React Hooks exported from `utils/contracts.ts` to interact with contracts in your project.

## Implementing Wagmi CLI Generated Code

Next, update the code in `demo/pages/web3.tsx` by replacing the `useReadContract` and `useWriteContract` functions with the newly generated code from the Wagmi CLI.

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

Update the logic for calling the `balanceOf` Method:

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
Update the logic for calling the `mint` method:

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

With this, we've completed the setup and utilization of the Wagmi CLI. In the upcoming practical course on developing decentralized exchanges (DEX), we'll be able to use the Wagmi CLI more efficiently to debug contracts without the need to manually handle ABI code. This method not only streamlines your project's code but also allows us to quickly write debugging scripts outside of contract unit tests, enhancing overall development efficiency.
