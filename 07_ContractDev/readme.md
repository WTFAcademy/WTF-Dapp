这一讲会简单介绍如何开发和测试一个智能合约。

---


本教程中，我们将使用 `Remix` 运行 `Solidity` 合约。

`Remix` 是以太坊官方推荐的智能合约集成开发环境（IDE），适合新手，提供了一个易于使用的界面，可以在浏览器中快速编写、编译和部署智能合约，无需在本地安装任何程序。

`Solidity` 是一门为实现 `智能合约` 而创建的高级编程语言。这门语言受到了 `C++`，`Python` 和 `Javascript` 语言的影响，设计的目的是能在以太坊虚拟机（`EVM`）上运行。`Solidity` 是静态类型语言，支持继承、库和复杂的用户定义类型。

## 初始化合约

### 面板

进入[Remix](https://remix.ethereum.org)，我们可以看到如下图所示的界面：

![](./img/remix.png)

像你看到的这样，`Remix` 由三个面板和一个终端组成。

1. 图标面板-点击可更改侧面板中显示的插件；
2. 侧面板–大多数插件（并非所有插件）的界面都在这里；
3. 主面板-用于编辑文件、大型工具和主页选项卡；
4. 终端-用于查看交易收据和各种日志。

#### 图标面板

![](./img/slide.png)

简单介绍下侧栏图标功能，后边我们用到了会更加详细的介绍讲解。  
`Home` 总是能打开主页面的，即使他被关闭掉了。  
`File explorer` 用于管理工作区和文件。  
`Search` 是一个全局搜索功能。  
`Solidity Compiler` 是合约编译器界面，界面中默认展示编译器的基础配置项和`Advanced Configurations` 按钮打开高级配置面板。  
`Deploy&Run` 是为了将交易发送到当前的`环境`中。  
`Debugger` 是一个调试器，调试交易的时候，调试器会显示合约的状态。  
`Plugin mananer` 是插件管理器，里边有非常多的插件可以选择安装。  
`Setting` 里会有一些基础的设置项，如 `语言`，`主题`，`Github 访问令牌`，`常规设置` 等。

### 工作区和文件

`Remix` 中的 `WORKSPACES` 是分隔项目的特殊文件夹。 一个工作区的文件不能导入或访问另一个不同工作区的文件。  
如下图所示，点击图标 1 可以切换不同的工作空间，图标 2 可以进行 `Create`，`Clone`，`Rename`，`Download`，`Delete` 等等一系列的对于工作空间的操作。

![](./img/createBtn.png) ![](./img/more.png)

### 创建

我们本次的教程是通过 `Create` 按钮，进行演示的。  
当我们点击 `Create` 时，会弹出 `Create Workspace` 的弹窗，`Remix` 提供了以下模板：

- Basic
- Blank
- OpenZeppelin ERC20
- OpenZeppelin ERC721
- OpenZeppelin ERC1155
- 0xProject ERC20
- Gnosis MultiSig

当选择一个 `OpenZeppelin` 库的 `ERC721` 模板时，可以添加额外的功能。

> [ERC721](https://eips.ethereum.org/EIPS/eip-721)（Ethereum Request for Comments 721），由 William Entriken、Dieter Shirley、Jacob Evans、Nastassia Sachs 在 2018 年 1 月提出，是一个在智能合约中实现代币 API 的非同质化代币标准。  
> [OpenZeppelin](https://docs.openzeppelin.com/contracts/5.x/)是一个用于安全智能合约开发的库，内置了很多常用合约的标准实现。

![](./img/create.png) ![](./img/mintable.png)

勾选上 `Mintable`，表示我们向模板合约里添加了 `Mint` 的方法，然后点击 `OK`。  
到这里，我们的 `Workspace` 就新建好了。如下图：

![](./img/initCode.png)

`.deps` 目录下是我们安装的 `@openzeppelin` 的 npm 包，这里边安装的是我们合约里引用的 `合约模板` 以及合约模板里引用的 `工具包`。  
`contracts` 下是放的自己编写的合约文件。  
`scripts` 文件夹下是自动生成的部署合约的脚本文件，执行这个下边的 js 文件也能实现部署合约。  
`tests` 里边自动编写了一些自动校验的测试文件。

`@openzeppelin` 向我们提供的`ERC721` 合约模板在`contracts/MyToken.sol` ，我们简单了解下这个合约的内容。

1. 第 1 行是注释，会写一下这个代码所用的软件许可（`license`），这里用的是 `MIT license`。如果不写许可，编译时会警告（`warning`），但程序可以运行。`solidity` 的注释由 `//` 开头，后面跟注释的内容（不会被程序运行）。
2. 第 2 行声明源文件所用的 `solidity` 版本，因为不同版本语法有差别。这行代码意思是源文件将不允许小于 `0.8.20` 版本或大于等于 `0.9.0` 的编译器编译（第二个条件由`^`提供）。`Solidity` 语句以分号（`;`）结尾。
3. 第 4-5 行是导入外部 `Solidity` 文件，导的 `Solidity` 文件和本身的 `Solidity` 文件相当于变成同一个 `Solidity` 合约。
4. 第 7 行是创建合约（`contract`），并声明合约的名字 `MyToken`，`is` 表示继承了引入的`ERC721`和`Ownable`合约。
5. 第 8-10 行是在 `constructor` 中我们传入了继承来的合约定义好的参数，为 `ERC721` 传入 `token` 的 `name` 和 `symbol`，`Ownable` 传合约拥有者的地址。
6. 第 13-15 行是定义了 `public` 对外开放的 `safeMint` 方法，需要传入类型为 `address`的 `to` 参数和类型为 `uint256` 的 `tokenId`，方法里执行 `ERC721.sol` 里引用的合约私有方法 `_safeMint()`，并带入了参数 `to` 和 `tokenId`。

接下来我们就尝试，向合约模板里写入一些我们自定义的功能。


## 开发合约

我们继续了解下合约的功能编写和编译测试。

下面的代码我们简单实现一个新的 `mint` 方法来取代默认生成的 `safeMint`，新的 `mint` 方法和我们在上一章用到的方法接口保持一致，这样当我们部署完成这个合约之后就可以把课程的合约替换为新的合约了。

具体要修改的内有：

1. 把 `initialOwner` 设置为合约发行人，这样在部署合约的时候就会更简单，不用指定 `initialOwner`。
2. 定义了一个名为 `_nextTokenId` 类型为 `uint256` 合约私有变量 `private`，用来标记当前的进度，每新增一个 NFT 该值需要加一；
3. 在 `mint` 方法中要求传入的类型为 `uint256` 的 `quantity`，代表这次要铸造多少个 NFT。在这里，我们先简化逻辑，限制每次只能铸造一个。
4. 去掉 `onlyOwner` 修饰符，这样就可以让任何人都可以调用 `mint` 方法了。
5. 添加 `payable` 修饰符，这样就可以让调用 `mint` 方法的人可以同时向合约转账了。
6. `_safeMint` 也要改为 `_mint`，这个主要是为了避免在后面通过 Remix 合约调用合约来测试的时候报错，`to` 也对应改为 `msg.sender`，代表 NFT 铸造给发起交易的地址。

代码如下：

```diff
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC721, Ownable {
+    uint256 private _nextTokenId = 0;

-    constructor(address initialOwner)
+    constructor()
        ERC721("MyToken", "MTK")
-        Ownable(initialOwner)
+        Ownable(msg.sender)
    {}

-    function safeMint(address to, uint256 tokenId) public onlyOwner {
+    function mint(uint256 quantity) public payable {
+        require(quantity == 1, "quantity must be 1");
+        require(msg.value == 0.01 ether, "must pay 0.01 ether");
+        uint256 tokenId = _nextTokenId++;
-        _safeMint(to, tokenId);
+        _mint(msg.sender, tokenId);
    }
}
```

> private 是指只有部署前合约里才能调用的方法和变量，public 方法和变量则是所有人都可以访问的。

## 测试合约

1. 单元测试插件

我们需要点击左下角的 `Plugin mananer `图标在插件管理器搜索 `unit` 关键字，然后会出现搜索结果 `SOLIDITY UNIT TESTING`，点击 `Activate`，安装激活插件，如下图所示：

![](./img/unitTest.png)

然后，`Solidity unit testing` 的图标将出现在左侧图标栏中，单击该图标将在侧面板中加载插件。

成功加载后，插件看起来应该是这样子的：

![](./img/unitTest1.png)

2. 单元测试文件

Remix 注入了一个内置的 assert 库，可用于测试。您可以在此处查看库的文档 [这里](https://remix-ide.readthedocs.io/en/latest/assert_library.html)。  
除此之外，Remix 允许在测试文件中使用一些特殊函数，以使测试更具结构性。它们是：

- `beforeEach()` - 在每次测试之前运行
- `beforeAll()` - 在所有测试之前运行
- `afterEach()` - 在每次测试之后运行
- `afterAll()` - 在所有测试之后运行

我们的单元测试文件，在目录 `tests/MyToken_test.sol`，这是因为我们选择的模板合约自动帮我们创建了测试合约。如果我们是新建的空白文件夹，那么就需要点击通过 `Generate` 按钮来生成测试文件，如下图所示：

![](./img/generate.png)

然后我们在`File explorer`中点击我们的测试文件 `tests/MyToken_test.sol`，并编写以下测试内容：

1. `remix_tests.sol` 由 `Remix` 自动注入的；
2. `remix_accounts.sol` 为我们生成了测试账户的地址列表；
3. `../contracts/MyToken.sol` 引入了我们编写过的合约文件；
4. 在 `beforeAll()` 里实例化我们的合约 `MyToken` 定义为 `s`，并拿一个测试地址存起来 `TestsAccounts.getAccount(0)` 定义为 `acc0`；
5. `testTokenNameAndSymbol()` 里验证了，实例化后的合约 `name()` 要获取到的值为 `MyToken`，`symbol()` 的值为 `MTK`；
6. 编写函数 `testMint()`，调用我们的 `mint(1)` 方法，铸造过一次的 `balanceOf()` 值应该为 `1`;

`tests/MyToken_test.sol` 文件代码如下：

```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;
import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/MyToken.sol";

contract MyTokenTest {
    MyToken s;
    function beforeAll () public {
        s = new MyToken();
    }

    function testTokenNameAndSymbol () public {
        Assert.equal(s.name(), "MyToken", "token name did not match");
        Assert.equal(s.symbol(), "MTK", "token symbol did not match");
    }
    /// #value: 10000000000000000
    function testMint() public payable {
        s.mint{value: msg.value}(1);
        Assert.equal(s.balanceOf(address(this)), 1, "balance did not match");
    }
}
```

Remix 的单测是在一个合约中调用我们要测试的合约来进行测试的，具体就先不展开了，大家可以参考 [Remix 单元测试插件的文档](https://remix-ide.readthedocs.io/en/latest/unittesting.html)。

3. 运行单元测试

当我们完成编写测试后，选择文件并点击 `Run` 以执行测试。执行将在单独的环境中运行。完成一个文件的执行后，将显示如下的测试摘要：

![](./img/run.png)

到这里，我们合约的单元测试就完成啦。

当然如果你更擅长使用 Chai 和 Mocha 测试的话，`Remix` 也是支持的。

> Chai 是一个用于 Node.js 和浏览器的 BDD / TDD 断言库，可以与任何 JavaScript 测试框架愉快地配对使用。Mocha 是一个功能丰富的 JavaScript 测试框架，在 Node.js 和浏览器上运行，使异步测试变得简单而有趣。

只需要在工作区创建一个 `js` 文件，最好将其创建在 `scripts` 文件夹中。然后右键新建并编写好测试代码的 `js` 文件，点击 `Run`。  
大概像这样：

![](./img/chai.png)

点击 `Run` ，执行测试后结果会显示在终端上。

这里只是一个示例，提供了可以操作的方式和方法，如果你擅长这种方式的话，完全是支持的。

接下来我们会尝试，把我们编写好的合约文件 `编译` 并 `部署上链` 。
