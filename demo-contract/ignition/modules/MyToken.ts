import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MyTokenModule = buildModule("MyTokenModule", (m) => {
  const lock = m.contract("MyToken");

  return { lock };
});

export default MyTokenModule;
