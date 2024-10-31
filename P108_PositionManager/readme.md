本节作者：[@愚指导](https://x.com/yudao1024)

这一讲将会实现 `PositionManager` 合约。

---

## 合约简介

`PositionManager` 合约并不是核心功能，和 Uniswap V3 的 [NonfungiblePositionManager.sol](https://github.com/Uniswap/v3-periphery/blob/main/contracts/NonfungiblePositionManager.sol) 合约类似。理论上来讲，你想要通过 Uniswap V3 来交易可以不通过 `NonfungiblePositionManager` 合约，你可以自己写一个合约来直接调用交易池来交易。这也是为什么这个合约是放在 `v3-periphery` 中，而不是在 `v3-core` 中。

我们的教程也是类似的设计，`PositionManager` 合约是为了方便用户管理自己的流动性，而不是直接调用交易池合约。和 `NonfungiblePositionManager` 一样，`PositionManager` 也是一个满足 `ERC721` 标准的合约，这样用户可以很方便的通过 NFT 的方式来管理自己的合约，也同时方便我们的前端来基于通用的 `ERC721` 的规范来开发，甚至可以放到交易所中交易。

接下来，就让我们来实现这个合约。

## 合约开发

> 完整的代码在 [demo-contract/contracts/wtfswap/PositionManager.sol](../demo-contract/contracts/wtfswap/PositionManager.sol) 中。

### 1. 添加流动性

首先，我们需要一个方法来添加流动性。整体的逻辑参考 Uniswap V3 的 [NonfungiblePositionManager.sol](https://github.com/Uniswap/v3-periphery/blob/main/contracts/NonfungiblePositionManager.sol#L128) 合约代码。但是我们的实现更简单，因为我们课程设计的每个交易池只有一个价格上下限，对应的一个池子内的流动性也都是同样一个价格上下限范围的。

我们在前面的课程中已经定义定义了 `PositionInfo` 和 `MintParams`，具体如下：

```solidity
struct PositionInfo {
    address owner;
    address token0;
    address token1;
    uint32 index;
    uint24 fee;
    uint128 liquidity;
    int24 tickLower;
    int24 tickUpper;
    uint128 tokensOwed0;
    uint128 tokensOwed1;
    // feeGrowthInside0LastX128 和 feeGrowthInside1LastX128 用于计算手续费
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
}

function getPositionInfo(
    uint256[] memory positionId
) external view returns (PositionInfo[] memory positionInfo);

struct MintParams {
    address token0;
    address token1;
    uint32 index;
    uint256 amount0Desired;
    uint256 amount1Desired;
    address recipient;
    uint256 deadline;
}
```

`mint` 方法中需要做的是，根据 `MintParams` 中的参数，调用 `Pool` 合约的 `mint` 方法来添加流动性。并且通过 `PositionInfo` 结构体来记录流动性的信息。对于 `Pool` 合约来说，流动性都是 `PositionManager` 合约掌管，`PositionManager` 相当于代管了 `LP` 的流东西，所以需要在它内部再存储下相关信息。

首先，我们先写调用 `Pool` 合约的相关代码：

```solidity
// mint 一个 NFT 作为 position 发给 LP
// NFT 的 tokenId 就是 positionId
// 通过 MintParams 里面的 token0 和 token1 以及 index 获取对应的 Pool
// 调用 poolManager 的 getPool 方法获取 Pool 地址
address _pool = poolManager.getPool(
    params.token0,
    params.token1,
    params.index
);
IPool pool = IPool(_pool);

// 通过获取 pool 相关信息，结合 params.amount0Desired 和 params.amount1Desired 计算这次要注入的流动性
uint160 sqrtPriceX96 = pool.sqrtPriceX96();
uint160 sqrtRatioAX96 = TickMath.getSqrtPriceAtTick(pool.tickLower());
uint160 sqrtRatioBX96 = TickMath.getSqrtPriceAtTick(pool.tickUpper());

liquidity = LiquidityAmounts.getLiquidityForAmounts(
    sqrtPriceX96,
    sqrtRatioAX96,
    sqrtRatioBX96,
    params.amount0Desired,
    params.amount1Desired
);

// data 是 mint 后回调 PositionManager 会额外带的数据
// 需要 PoistionManger 实现回调，在回调中给 Pool 打钱
bytes memory data = abi.encode(
    params.token0,
    params.token1,
    params.index,
    msg.sender
);
(amount0, amount1) = pool.mint(address(this), liquidity, data);
```

在上面代码中，我们通过 `TickMath` 计算了 `sqrtRatioAX96` 和 `sqrtRatioBX96`，然后通过 `LiquidityAmounts` 计算了 `liquidity`。最后调用 `pool.mint` 方法来添加流动性。对应的，你需要在合约中引入相关依赖：

```diff
+ import "./libraries/LiquidityAmounts.sol";
+ import "./libraries/TickMath.sol";
```

其中 `LiquidityAmounts.sol` 复制自 [v3-periphery](https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/LiquidityAmounts.sol)，你需要修改它头部的两行 `import` 语句：

```diff
- import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
- import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';
+ import './FullMath.sol';
+ import './FixedPoint96.sol';
```

调用 `mint` 方法后，`Pool` 合约会回调 `PositionManager` 合约，所以我们需要实现一个回调函数，并且在回调中给 `Pool` 合约打钱：

```solidity
function mintCallback(
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
) external override {
    // 检查 callback 的合约地址是否是 Pool
    (address token0, address token1, uint32 index, address payer) = abi
        .decode(data, (address, address, uint32, address));
    address _pool = poolManager.getPool(token0, token1, index);
    require(_pool == msg.sender, "Invalid callback caller");

    // 在这里给 Pool 打钱，需要用户先 approve 足够的金额，这里才会成功
    if (amount0 > 0) {
        IERC20(token0).transferFrom(payer, msg.sender, amount0);
    }
    if (amount1 > 0) {
        IERC20(token1).transferFrom(payer, msg.sender, amount1);
    }
}
```

在上面的实现中，我们需要检查调用 `mintCallback` 的合约地址是否是 `Pool` 合约，然后给 `Pool` 合约打钱。这里需要用户先 `approve` 足够的金额，这样才能成功。

接下来我们需要在 `PositionManager` 合约中更新相关状态，并且 mint 一个 NFT 作为 position 发给 LP：

```solidity
_mint(params.recipient, (positionId = _nextId++));

(
    ,
    uint256 feeGrowthInside0LastX128,
    uint256 feeGrowthInside1LastX128,
    ,

) = pool.getPosition(address(this));

positions[positionId] = PositionInfo({
    owner: params.recipient,
    token0: params.token0,
    token1: params.token1,
    index: params.index,
    fee: pool.fee(),
    liquidity: liquidity,
    tickLower: pool.tickLower(),
    tickUpper: pool.tickUpper(),
    tokensOwed0: 0,
    tokensOwed1: 0,
    feeGrowthInside0LastX128: feeGrowthInside0LastX128,
    feeGrowthInside1LastX128: feeGrowthInside1LastX128
});
```

在上面的代码中，我们通过 `import "@openzeppelin/contracts/token/ERC721/ERC721.sol";` 提供的 `_mint` 方法就可以轻松的实现一个 NFT 合约的相关逻辑。另外我们还需要调用 `Pool` 合约的 `getPosition` 方法来获取相关信息，然后更新 `positions` 的状态。

`getPosition` 方法实现如下（在 `Pool.sol` 中实现）：

```solidity
function getPosition(
    address owner
)
    external
    view
    override
    returns (
        uint128 _liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    )
{
    return (
        positions[owner].liquidity,
        positions[owner].feeGrowthInside0LastX128,
        positions[owner].feeGrowthInside1LastX128,
        positions[owner].tokensOwed0,
        positions[owner].tokensOwed1
    );
}
```

它也参考了 [Uniswap V3 的实现](https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol#L37)，只不过我们直接写在了 `Pool.sol` 合约中，更简单。通过这个方法可以获取到手续费相关信息，需要记录下来，后续计算手续费需要。

至此，`mint` 方法就完成了。

### 2. 移除流动性

接下来我们需要实现 `burn` 方法，用来移除流动性。和 `mint` 方法类似，我们需要调用 `Pool` 合约的 `burn` 方法来移除流动性。

首先引入一个依赖（计算手续费需要）：

```diff
+ import "./libraries/FixedPoint128.sol";
```

然后在 `PositionManager` 合约中实现 `burn` 方法：

```solidity
function burn(
    uint256 positionId
)
    external
    override
    isAuthorizedForToken(positionId)
    returns (uint256 amount0, uint256 amount1)
{
    PositionInfo storage position = positions[positionId];
    // 通过 isAuthorizedForToken 检查 positionId 是否有权限
    // 移除流动性，但是 token 还是保留在 pool 中，需要再调用 collect 方法才能取回 token
    // 通过 positionId 获取对应 LP 的流动性
    uint128 _liquidity = position.liquidity;
    // 调用 Pool 的方法给 LP 退流动性
    address _pool = poolManager.getPool(
        position.token0,
        position.token1,
        position.index
    );
    IPool pool = IPool(_pool);
    (amount0, amount1) = pool.burn(_liquidity);

    // 计算这部分流动性产生的手续费
    (
        ,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        ,

    ) = pool.getPosition(address(this));

    position.tokensOwed0 +=
        uint128(amount0) +
        uint128(
            FullMath.mulDiv(
                feeGrowthInside0LastX128 -
                    position.feeGrowthInside0LastX128,
                position.liquidity,
                FixedPoint128.Q128
            )
        );

    position.tokensOwed1 +=
        uint128(amount1) +
        uint128(
            FullMath.mulDiv(
                feeGrowthInside1LastX128 -
                    position.feeGrowthInside1LastX128,
                position.liquidity,
                FixedPoint128.Q128
            )
        );

    // 更新 position 的信息
    position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
    position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
    position.liquidity = 0;
}
```

在该方法中，我们做了如下两件事：

- 调用 `Pool` 合约的 `burn` 方法来移除流动性。
- 更新 `position` 的状态，更新 `tokensOwed0` 和 `tokensOwed1`，它们代表了 LP 可以提取的 token，包括手续费。

计算手续费依然涉及到了通过 `FullMath.mulDiv` 来做大数的乘除，解决取整的问题，具体可以参考[上一讲](../P107_PoolFee/readme.md)关于手续费的逻辑。相关代码我们参考了 Uniswap V3 中的 [decreaseLiquidity](https://github.com/Uniswap/v3-periphery/blob/main/contracts/NonfungiblePositionManager.sol#L257)。

另外需要注意的是，在该方法上我们添加了一个 `isAuthorizedForToken` 修饰器，用来检查调用者是否有权限操作该 `positionId`，具体实现如下：

```solidity
modifier isAuthorizedForToken(uint256 tokenId) {
    address owner = ERC721.ownerOf(tokenId);
    require(_isAuthorized(owner, msg.sender, tokenId), "Not approved");
    _;
}
```

它用于确保合约调用者有对应流动性的 NFT 的权限，关于修饰器的详细介绍可以参考[WTF 的 Solidity 课程中相关内容](https://github.com/AmazingAng/WTF-Solidity/blob/main/11_Modifier/readme.md)。

### 3. 提取代币

和 `Pool` 合约类似，我们还需要实现 `collect` 方法来提供给 LP 提取代币。

```solidity
function collect(
    uint256 positionId,
    address recipient
)
    external
    override
    isAuthorizedForToken(positionId)
    returns (uint256 amount0, uint256 amount1)
{
    // 通过 isAuthorizedForToken 检查 positionId 是否有权限
    // 调用 Pool 的方法给 LP 退流动性
    address _pool = poolManager.getPool(
        positions[positionId].token0,
        positions[positionId].token1,
        positions[positionId].index
    );
    IPool pool = IPool(_pool);
    (amount0, amount1) = pool.collect(
        recipient,
        positions[positionId].tokensOwed0,
        positions[positionId].tokensOwed1
    );

    // position 已经彻底没用了，销毁
    _burn(positionId);
}
```

在上面代码中，我们调用了 `Pool` 合约的 `collect` 方法来提取代币，然后销毁 `positionId` 对应的 NFT。同样我们也需要修饰器 `isAuthorizedForToken` 来确保调用者有权限操作该 `positionId`。

## 合约测试

同样，我们依然需要编写测试用例来测试我们的合约。在笔者实现本课程的过程中，通过编写测试样例发现了很多重大的 Bug，编写单元测试也是很好也很高效的一种方式来保证合约的正确性。对于 `PositionManager` 合约，笔者尝试写了一个完整的从 `mint` 到产生交易到最后提取流动性的测试用例。

具体的测试代码不再全部贴出，你可以在 [PositionManager.ts](../demo-contract/test/wtfswap/PositionManager.ts) 中查看。

需要说明的是，我们在测试样例中通过下面的代码获取到了当前交易发起的用户地址，这在测试样例编写中很有用：

```ts
const [owner] = await hre.viem.getWalletClients();
const [sender] = await owner.getAddresses();
```

具体的说明你可以参考 Hardhat 的 viem 插件的[文档](https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-viem)。

至此我们就完成了 `PositionManager` 的开发，这个合约也是后续我们在前端开发中需要直接调用到的合约，在前端开发部分课程，我们也会接触到它。
