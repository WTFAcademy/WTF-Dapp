import Link from "next/link";
import { usePathname } from "next/navigation";
import { Connector, ConnectButton } from "@ant-design/web3";
import styles from "./styles.module.css";

export default function WtfHeader() {
  const pathname = usePathname();
  const isSwapPage = pathname === "/wtfswap";

  return (
    <div className={styles.header}>
      <div className={styles.title}>WTFSwap</div>
      <div className={styles.nav}>
        <Link
          href="/wtfswap"
          className={isSwapPage ? styles.active : undefined}
        >
          Swap
        </Link>
        <Link
          href="/wtfswap/pool"
          className={!isSwapPage ? styles.active : undefined}
        >
          Pool
        </Link>
      </div>
      <div>
        <Connector
          modalProps={{
            mode: "simple",
          }}
        >
          <ConnectButton type="text" />
        </Connector>
      </div>
    </div>
  );
}
