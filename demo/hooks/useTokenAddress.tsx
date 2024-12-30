import type { Token } from "@ant-design/web3";
import { useChainId } from "wagmi";

export default (token?: Token): `0x${string}` | undefined => {
  const chainId = useChainId();
  return token?.availableChains.find((item) => item.chain.id === chainId)
    ?.contract as `0x${string}` | undefined;
};
