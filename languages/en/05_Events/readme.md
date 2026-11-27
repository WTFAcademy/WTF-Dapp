This section will explain how to monitor contract events within a DApp and update its interface in real-time.

## Introduction

In blockchain smart contracts, the concept of events is somewhat distinct from how events are understood in traditional application development. Blockchain lacks a built-in messaging system to send events to applications. Instead, events are essentially abstractions of logs generated on the Ethereum Virtual Machine (EVM).

Compared to direct state changes in smart contracts, these log-based events are more cost-effective, serving as an economical method for data storage. An event typically uses about 2000 gas, while storing a new variable on the blockchain requires at least 20,000 gas. Consequently, events are often used in smart contracts to document significant state changes. Moreover, by leveraging the RPC interfaces provided by node services, the frontend of a DApp can listen to these contract events and update the interface in near real-time.

## How to Add Events in Smart Contracts

In smart contracts, events are defined with the `event` keyword and activated using the `emit` command. Here's a straightforward example to illustrate this concept. We will offer a more detailed explanation in our upcoming contract development courses.

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

## How to Listen to Events in a DApp

To listen to contract events in a DApp's front-end, we can utilize the RPC interface provided by the node service. For this example, we'll continue using `wagmi` for our development needs.

We'll start by implementing the [useWatchContractEvent](https://wagmi.sh/react/api/hooks/useWatchContractEvent#abi) hook.

```diff
import {
  createConfig,
  http,
  useReadContract,
  useWriteContract,
+  useWatchContractEvent,
} from "wagmi";
```

To monitor contract events, use `useWatchContractEvent`.

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

When using an SDK like wagmi, the approach is quite similar to traditional front-end development. You start by entering the contract address and the event you wish to monitor. Then, you can handle these events through the `onLogs` callback function.

It's important to note that the code provided here is for demonstration purposes only and may not encompass all practical applications. In a real-world scenario, you would need to determine the specific details of the event within `onLogs` and update your page accordingly.

Typically, the `abi` parameter is generated automatically when compiling the contract. Instead of manually writing it each time, it's best to maintain a complete version within your project and use it as needed.

Since events only occur after a contract is invoked, we can't debug this right now. You should continue with the course material and return to test this once you're able to deploy a test contract in a testing environment.
