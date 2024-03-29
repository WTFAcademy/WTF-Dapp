import Head from "next/head";
import Image from "next/image";
import { Inter } from "next/font/google";
import styles from "@/styles/Home.module.css";

const inter = Inter({ subsets: ["latin"] });

export default function Home() {
  return (
    <>
      <Head>
        <title>WTF Academy DApp 极简入门教程</title>
        <meta
          name="description"
          content="WTF Academy DApp 极简入门教程，帮助开发者入门去中心应用开发。"
        />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="icon" href="/favicon.ico" />
      </Head>
      <main className={`${styles.main} ${inter.className}`}>
        <div className={styles.description}>
          <p>WTF Academy DApp 极简入门教程，帮助开发者入门去中心应用开发。</p>
          <div>
            <a
              href="https://vercel.com?utm_source=create-next-app&utm_medium=default-template&utm_campaign=create-next-app"
              target="_blank"
              rel="noopener noreferrer"
            >
              By{" "}
              <Image
                src="/wtf.png"
                alt="ETF Logo"
                className={styles.vercelLogo}
                width={100}
                height={42}
                priority
              />
            </a>
          </div>
        </div>

        <div className={styles.center}>
          <Image
            className={styles.logo}
            src="/wtf-antdweb3.png"
            alt="wtf antdweb3 Logo"
            width={689}
            height={412}
            priority
          />
        </div>

        <div className={styles.grid}>
          <a
            href="https://github.com/WTFAcademy/WTF-Dapp"
            className={styles.card}
            target="_blank"
            rel="noopener noreferrer"
          >
            <h2>
              Github <span>-&gt;</span>
            </h2>
            <p>前往 Github 获取教程</p>
          </a>

          <a
            href="https://www.wtf.academy/"
            className={styles.card}
            target="_blank"
            rel="noopener noreferrer"
          >
            <h2>
              More <span>-&gt;</span>
            </h2>
            <p>获取更多 WTF Academy 课程</p>
          </a>

          <a
            href="/web3"
            className={styles.card}
            target="_blank"
            rel="noopener noreferrer"
          >
            <h2>
              Demo <span>-&gt;</span>
            </h2>
            <p>访问课程 Demo</p>
          </a>

          <a
            href="https://web3.ant.design/"
            className={styles.card}
            target="_blank"
            rel="noopener noreferrer"
          >
            <h2>
              Ant Design Web3 <span>-&gt;</span>
            </h2>
            <p>了解 Ant Design Web3</p>
          </a>
        </div>
      </main>
    </>
  );
}
