# WTF Dapp contracts

Use Node.js 22.12 or newer. This project pins Hardhat 3.22.0, Solidity 0.8.39,
and OpenZeppelin Contracts 5.6.1.

```sh
npm ci
npm test
npx hardhat node
```

The Node.js test suite uses the Viem connection provided by
`@nomicfoundation/hardhat-toolbox-viem`. The deployment modules are in
[`ignition/modules/`](./ignition/modules/).
