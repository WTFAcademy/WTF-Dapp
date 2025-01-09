本节作者：[@愚指导](https://x.com/yudao1024)

这一讲我们将会把 Wtfswap 部署到测试网 Sepolia 上，正式完成我们的课程。

---

## 合约部署

```
npx hardhat ignition deploy ./ignition/modules/Wtfswap.ts --network sepolia
✔ Confirm deploy to network sepolia (11155111)? … yes
Hardhat Ignition 🚀

Deploying [ Wtfswap ]

Batch #1
  Executed Wtfswap#PoolManager

Batch #2
  Executed Wtfswap#PositionManager
  Executed Wtfswap#SwapRouter

[ Wtfswap ] successfully deployed 🚀

Deployed Addresses

Wtfswap#PoolManager - 0xF35DE8597A617cfA23de794BCBB4c2f8fc9bC896
Wtfswap#PositionManager - 0x59ebEa058E193B64f0E091220d5Db98288EFec57
Wtfswap#SwapRouter - 0xA8b9Fa84A4Df935e768d3cC211E3d679027d0B31
```

```
npx hardhat ignition deploy ./ignition/modules/DebugToken.ts --network sepolia
✔ Confirm deploy to network sepolia (11155111)? … yes
Hardhat Ignition 🚀

Resuming existing deployment from ./ignition/deployments/chain-11155111

Deploying [ DebugToken ]

Warning - previously executed futures are not in the module:
 - Wtfswap#PoolManager
 - Wtfswap#PositionManager
 - Wtfswap#SwapRouter

Batch #1
  Executed DebugToken#DebugTokenA
  Executed DebugToken#DebugTokenB
  Executed DebugToken#DebugTokenC

[ DebugToken ] successfully deployed 🚀

Deployed Addresses

Wtfswap#PoolManager - 0xF35DE8597A617cfA23de794BCBB4c2f8fc9bC896
Wtfswap#PositionManager - 0x59ebEa058E193B64f0E091220d5Db98288EFec57
Wtfswap#SwapRouter - 0xA8b9Fa84A4Df935e768d3cC211E3d679027d0B31
DebugToken#DebugTokenA - 0x5AAB2806D12E380c24C640a8Cd94906d7fA59b16
DebugToken#DebugTokenB - 0x00E6EC12a0Fc35d7064cD0d551Ac74A02bA8a5A5
DebugToken#DebugTokenC - 0x1D46AD43cc80BFb66C1D574d2B0E4abab191d1E0
```

## 合约认证

```
npx hardhat verify --network sepolia 0xF35DE8597A617cfA23de794BCBB4c2f8fc9bC896
[INFO] Sourcify Verification Skipped: Sourcify verification is currently disabled. To enable it, add the following entry to your Hardhat configuration:

sourcify: {
  enabled: true
}

Or set 'enabled' to false to hide this message.

For more information, visit https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-verify#verifying-on-sourcify
Successfully submitted source code for contract
contracts/wtfswap/PoolManager.sol:PoolManager at 0xF35DE8597A617cfA23de794BCBB4c2f8fc9bC896
for verification on the block explorer. Waiting for verification result...

Successfully verified contract PoolManager on the block explorer.
https://sepolia.etherscan.io/address/0xF35DE8597A617cfA23de794BCBB4c2f8fc9bC896#code
```

```
npx hardhat verify --network sepolia 0x59ebEa058E193B64f0E091220d5Db98288EFec57 0xF35DE8597A617cfA23de794BCBB4c2f8fc9bC896
[INFO] Sourcify Verification Skipped: Sourcify verification is currently disabled. To enable it, add the following entry to your Hardhat configuration:

sourcify: {
  enabled: true
}

Or set 'enabled' to false to hide this message.

For more information, visit https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-verify#verifying-on-sourcify
Successfully submitted source code for contract
contracts/wtfswap/PositionManager.sol:PositionManager at 0x59ebEa058E193B64f0E091220d5Db98288EFec57
for verification on the block explorer. Waiting for verification result...

Successfully verified contract PositionManager on the block explorer.
https://sepolia.etherscan.io/address/0x59ebEa058E193B64f0E091220d5Db98288EFec57#code
```

```
npx hardhat verify --network sepolia 0xA8b9Fa84A4Df935e768d3cC211E3d679027d0B31 0xF35DE8597A617cfA23de794BCBB4c2f8fc9bC896
[INFO] Sourcify Verification Skipped: Sourcify verification is currently disabled. To enable it, add the following entry to your Hardhat configuration:

sourcify: {
  enabled: true
}

Or set 'enabled' to false to hide this message.

For more information, visit https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-verify#verifying-on-sourcify
Successfully submitted source code for contract
contracts/wtfswap/SwapRouter.sol:SwapRouter at 0xA8b9Fa84A4Df935e768d3cC211E3d679027d0B31
for verification on the block explorer. Waiting for verification result...

Successfully verified contract SwapRouter on the block explorer.
https://sepolia.etherscan.io/address/0xA8b9Fa84A4Df935e768d3cC211E3d679027d0B31#code
```

## 前端部署
