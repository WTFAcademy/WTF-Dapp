import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const WtfswapModule = buildModule("Wtfswap", (m) => {
  const pool = m.contract("Pool");
  const factory = m.contract("Factory");
  const poolManager = m.contract("PoolManager");
  const swapRouter = m.contract("SwapRouter");
  const positionManager = m.contract("PositionManager");

  return { pool, factory, poolManager, swapRouter, positionManager };
});

export default WtfswapModule;
