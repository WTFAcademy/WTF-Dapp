这一讲将会介绍如何在 DApp 中监听合约事件，实时更新 DApp 界面。

## 简介

区块链智能合约的事件和我们传统的应用开发理解的事件概念是有些不同的，区块链本身并没有一个消息机制来向应用发送事件。它本质上是 EVM 上日志的抽象。

这一类日志相比智能合约的状态变化，更加便宜，是一种比较经济数据存储方式，每个事件大概消耗 2000 gas，而链上存储一个新变量至少需要 20000 gas。所以在智能合约中，我们通常会使用事件来记录一些重要的状态变化。另外基于节点服务提供的 RPC 接口可以实现 DApp 前端页面监听合约事件，实现相对实时的更新。

## 如何在智能合约中添加事件

在智能合约中事件由 `event` 声明，以 `emit` 触发，下面是一个示例，这里只做简单展示，具体我们会在后面的合约开发课程中具体讲解：

```diff
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC721, Ownable {
  uint256 private _nextTokenId = 0;
+  event Minted(address minter, uint256 amount);
  constructor()
    ERC721("MyToken", "MTK")
    Ownable(msg.sender)
  {}
  function mint(uint256 quantity) public payable {
    require(quantity == 1, "quantity must be 1");
    require(msg.value == 0.01 ether, "must pay 0.01 ether");
    uint256 tokenId = _nextTokenId++;
    _mint(msg.sender, tokenId);
+    emit Minted(msg.sender, quantity);
  }
}
```

## 如何在 DApp 中监听事件

在 DApp 前端页面，我们可以通过调用节点服务提供的 RPC 接口来监听合约事件，这里我们继续使用 `wagmi` 来开发。

首先引入 [useWatchContractEvent](https://wagmi.sh/react/api/hooks/useWatchContractEvent#abi)。

```diff
import {
  createConfig,
  http,
  useReadContract,
  useWriteContract,
+  useWatchContractEvent,
} from "wagmi";
```

然后使用 `useWatchContractEvent` 监听合约事件。

```ts
useWatchContractEvent({
  address: "0xEcd0D12E21805803f70de03B72B1C162dB0898d9",
  abi: [
    {
      anonymous: false,
      inputs: [
        {
          indexed: false,
          internalType: "address",
          name: "minter",
          type: "address",
        },
        {
          indexed: false,
          internalType: "uint256",
          name: "amount",
          type: "uint256",
        },
      ],
      name: "Minted",
      type: "event",
    },
  ],
  eventName: "Minted",
  onLogs() {
    message.success("new minted!");
  },
});
```

具体的使用方法其实在类似 wagmi 这样的 SDK 的封装下和传统的前端开发并没有太大的区别，你传入合约地址和要监听的事件后就可以在 `onLogs` 回调中处理事件。

当然，上面代码只是为了演示。实际编码的时候你可能需要在 `onLogs` 中判断事件的具体内容，然后更新页面。

此外，`abi` 参数通常来说都是合约编译时候自动生成的，整体在项目中维护一份完整的内容传入即可，不需要像示例这样单独在每个调用的地方手动编写。

因为事件只有在合约被调用后才会触发，所以我们目前还无法调试，你可以继续课程，等到我们在测试环境可以部署一个测试合约后再来测试。

完整的代码可以参考 [web3.tsx](./web3.tsx)。
