// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import "./interfaces/IERC20.sol";
import "./interfaces/IPool.sol";
import "./lib/SafeCast.sol";
import "./lib/TickMath.sol";
import "./lib/Position.sol";
import "./lib/Tick.sol";
import "./lib/TickBitmap.sol";
import "./lib/SqrtPriceMath.sol";
import "./lib/SwapMath.sol";
import "./lib/FullMath.sol";
import "./lib/FixedPoint128.sol";

struct Slot0 {
    // 当前 price 和 tick
    uint160 sqrtPriceX96;
    int24 tick;
    bool unlocked;
}

function checkTicks(int24 tickLower, int24 tickUpper) pure {
    require(tickLower < tickUpper);
    require(tickLower >= TickMath.MIN_TICK);
    require(tickUpper <= TickMath.MAX_TICK);
}

contract Pool is IPool {
    // 在本合约的数据上使用相关合约的数据类型
    using SafeCast for int256;
    using SafeCast for uint256;
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    address public immutable token0;
    address public immutable token1;
    // 0.1% = 1000
    uint24 public immutable fee;
    int24 public immutable tickSpacing;
    uint128 public immutable maxLiquidityPerTick; // 每 tick 最大流动性

    Slot0 public slot0;
    uint256 public feeGrowthGlobal0X128;
    uint256 public feeGrowthGlobal1X128;
    uint128 public liquidity;
    mapping(int24 => Tick.Info) public ticks;
    mapping(int16 => uint256) public tickBitmap;
    mapping(bytes32 => Position.Info) public positions; // bytes32 是 ID

    modifier lock() {
        require(slot0.unlocked, "locked");
        // lock 是 reentrancy box, 执行代码后再解锁
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    // 初始化代币、fee、每 tick 最大流动性
    constructor(
        address _token0,
        address _token1,
        uint24 _fee,
        int24 _tickSpacing
    ) {
        require(_token0 != address(0), "token 0 = zero address");
        require(_token0 < _token1, "token 0 >= token 1");

        token0 = _token0;
        token1 = _token1;
        fee = _fee;
        tickSpacing = _tickSpacing;
        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(
            _tickSpacing
        );
    }

    // function factory() external view returns (address);
    function getToken0() external view returns (address) {
        return token0;
    }

    function getToken1() external view returns (address) {
        return token1;
    }

    function getFee() external view returns (uint24) {
        return fee;
    }

    function tickLower() external view returns (int24) {
        return slot0.tick - tickSpacing;
    }

    function tickUpper() external view returns (int24) {
        return slot0.tick + tickSpacing;
    }

    function getSqrtPriceX96() external view returns (uint160) {
        return slot0.sqrtPriceX96;
    }

    function getTick() external view returns (int24) {
        return slot0.tick;
    }

    function getLiquidity() external view returns (uint128) {
        return liquidity;
    }

    function getPositions(
        address owner,
        int24 tickLower,
        int24 tickUpper
    )
        external
        view
        returns (uint128 _liquidity, uint128 tokensOwed0, uint128 tokensOwed1)
    {
        Position.Info memory position = positions.get(
            owner,
            tickLower,
            tickUpper
        );

        (_liquidity, tokensOwed0, tokensOwed1) = (
            position.liquidity,
            position.tokensOwed0,
            position.tokensOwed1
        );

        return (_liquidity, tokensOwed0, tokensOwed1);
    }

    /**
     * @dev initialize 设置初始价格(只能被调用一次， 所以检查 sqrtPriceX96 是否等于0)
     * @notice sqrtPriceX96 和 Slot0 零插槽
     *    - Slot0 使用的是 EVM state variables 的 storage 的 zero slot (每个槽是 32 个字节)
     * @notice sqrtPriceX96(就是价格的平方根乘以某标量 scalar, Q96 = 2**96)
     *    - sqrtPriceX96 = √P * Q96
     *    - Sqrt 转 tick: TickMath.getTickAtSqrtRatio(sqrtPriceX96); tick 转 Sqrt TickMath.getSqrtRatioAtTick(tick)
     */

    function initialize(uint160 sqrtPriceX96) external {
        require(slot0.sqrtPriceX96 == 0, "already initialized");
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        // 初始化零插槽
        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick, unlocked: true});
    }

    /**
     * @dev mint 添加流动性(把添加的流动性 amount 转换成两个代币分别要增加的流动性)
     * @notice amount 要添加的流动性数量， 返回的是代币0 和 1 要增加的流动性
     * @notice _modifyPosition 修改仓位：position 和 tick
     * @notice ModifyPositionParams 参数： tickLower、tickUpper、liquidityDelta(就是 tickLower 与 tickUpper 的差值), 返回 position, amount0, amount1
     * @notice _updatePosition 更新仓位
     * @notice  SqrtPriceMath 合约里的getAmount0Delta 在既定的prive range(Price A 和 Price B)下， 计算 token 0 的数量、以及liquidity； 同理 getAmount1Delta
     */

    struct ModifyPositionParams {
        address owner;
        int24 tickLower;
        int24 tickUpper;
        int128 liquidityDelta;
    }

    function _modifyPosition(
        ModifyPositionParams memory params
    )
        private
        returns (Position.Info storage position, int256 amount0, int256 amount1)
    {
        checkTicks(params.tickLower, params.tickUpper);

        // 加载到内存可以节省 gas
        Slot0 memory _slot0 = slot0;

        // 更新仓位: 是指在 tickLower 和 tickUpper 之间增加流动性
        position = _updatePosition(
            params.owner,
            params.tickUpper,
            params.tickLower,
            params.liquidityDelta,
            _slot0.tick
        );

        // SqrtPriceMath 合约里的getAmount0Delta 在既定的prive range(Price A 和 Price B)下， 计算 token 0 的数量、以及liquidity； 同理 getAmount1Delta
        // 计算 3 种情况下的 amount0 和 amount1： (当前价格就是 _slot0.tick )当前价格 P <= P_A， P >= P_B, P_A < P <P_B
        if (params.liquidityDelta != 0) {
            if (_slot0.tick < params.tickLower) {
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            } else if (_slot0.tick < params.tickUpper) {
                amount0 = SqrtPriceMath.getAmount0Delta(
                    _slot0.sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    _slot0.sqrtPriceX96,
                    params.liquidityDelta
                );

                // 因为添加了流动性, 所以要更新 liquidity
                liquidity = params.liquidityDelta < 0
                    ? liquidity - uint128(-params.liquidityDelta)
                    : liquidity + uint128(params.liquidityDelta);
            } else {
                amount1 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            }
        }
    }

    function _updatePosition(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,
        int24 tick
    ) private returns (Position.Info storage position) {
        // get 函数就是把这三个参数 hash 了
        position = positions.get(owner, tickLower, tickUpper);

        // 设置 fee 的部分
        uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128;
        uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128;

        bool flippedLower;
        bool flippedUpper;
        if (liquidityDelta != 0) {
            flippedLower = ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                false,
                maxLiquidityPerTick
            );

            flippedUpper = ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                true,
                maxLiquidityPerTick
            );

            // 添加或删除流动性时调用 _updatePosition()，导致tick 发生变化(liquidityDelta 不等于0 时要更新 tick, 并且决定 tick 是否被翻转)
            if (flippedLower) {
                tickBitmap.flipTick(tickLower, tickSpacing);
            }

            if (flippedUpper) {
                tickBitmap.flipTick(tickUpper, tickSpacing);
            }
        }

        // fee growth inside
        // _feeGrowthGlobal0X128, _feeGrowthGlobal1X128 就是上面更新的
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = ticks
            .getFeeGrowthInside(
                tickLower,
                tickUpper,
                tick,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128
            );

        position.update(
            liquidityDelta,
            feeGrowthInside0X128,
            feeGrowthInside1X128
        );

        // liquidityDelta < 0 是删除流动性， flippedLower 该流动性被翻转（意味着该 tick 的流动性现在等于零）
        if (liquidityDelta < 0) {
            if (flippedLower) {
                ticks.clear(tickLower);
            }

            if (flippedUpper) {
                ticks.clear(tickUpper);
            }
        }
    }

    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external lock returns (uint256 amount0, uint256 amount1) {
        require(amount > 0, "amount = 0");

        (, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: recipient,
                tickLower: tickLower,
                tickUpper: tickUpper,
                // 使用 SafeCast 进行的转化
                liquidityDelta: int256(uint256(amount)).toInt128()
            })
        );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        if (amount0 > 0) {
            IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        }
    }

    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external lock returns (uint128 amount0, uint128 amount1) {
        // amount0 和 amount1 是返回 requested 和 owed 中较小的
        Position.Info storage position = positions.get(
            msg.sender,
            tickLower,
            tickUpper
        );
        amount0 = amount0Requested > position.tokensOwed0
            ? position.tokensOwed0
            : amount0Requested;

        amount1 = amount1Requested > position.tokensOwed1
            ? position.tokensOwed1
            : amount1Requested;

        if (amount0 > 0) {
            position.tokensOwed0 -= amount0;
            IERC20(token0).transfer(recipient, amount0);
        }

        if (amount1 > 0) {
            position.tokensOwed1 -= amount1;
            IERC20(token1).transfer(recipient, amount1);
        }
    }

    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external lock returns (uint256 amount0, uint256 amount1) {
        (Position.Info storage position, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: msg.sender,
                tickLower: tickLower,
                tickUpper: tickUpper,
                // 使用 SafeCast 进行的转化(移除流动性， 所以是负数)
                liquidityDelta: -int256(uint256(amount)).toInt128()
            })
        );

        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            // 更新的代币 0 和 1 的仓位（collect函数要使用的， 转账后再减去相应的添加的 amount0, amount1）
            (position.tokensOwed0, position.tokensOwed1) = (
                position.tokensOwed0 + uint128(amount0),
                position.tokensOwed1 + uint128(amount1)
            );
        }
    }

    /**
     * @dev 2. Swap
     * @notice 检查函数的参数、初始化及更新 3 个 swap 的 struct
     * @notice 更新 SwapState: 计算 amountCalculated
     * @notice 更新 tick, price(sqrtPriceX96), liquidity, fee
     * @notice 计算 tokenIn 和 tokenOut： amount0 和 amount1 中， tokenIn = specified - remaining， tokenOut = calculated
     * @notice 转账：amount0, amount1: 正数是钱进本合约， 负数是钱转给用户
     */

    struct SwapCache {
        // swap 前的 liquidity
        uint128 liquidityStart;
    }

    struct SwapState {
        // 剩余要 swap in/out 的资产金额
        int256 amountSpecifiedRemaining;
        // 已经 swap 的资产金额（本合约要计算的， exactIn 就计算 AmountOut， exactOut 就计算 AmountIn）
        int256 amountCalculated;
        // 当前 sqrt(价格)
        uint160 sqrtPriceX96;
        // 与当前价格相关的 tick
        int24 tick;
        // tokenIn 的费用增长
        uint256 feeGrowthGlobalX128;
        // 当前流动性范围
        uint128 liquidity;
    }

    struct StepComputations {
        // 开始价格
        uint160 sqrtPriceStartX96;
        // 根据 swap 确定下个 tick
        int24 tickNext;
        // tickNext 是否已初始化
        bool initialized;
        // 下个 tick 的价格
        uint160 sqrtPriceNextX96;
        // 本次 swap 进账
        uint256 amountIn;
        // 本次 swap 出账
        uint256 amountOut;
        // 支付费用
        uint256 feeAmount;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified, // amountSpecified 交易指定的金额（>0 就是exactInput: 用户定义的进来的数量的话， 合约就会计算出去的代币数量）
        uint160 sqrtPriceLimitX96 // 达到这个价格限制， 交易就会停止
    ) external lock returns (int256 amount0, int256 amount1) {
        require(amountSpecified != 0);

        Slot0 memory slot0Start = slot0;

        // 检查 sqrtPriceLimitX96 是个有效的价格
        // token 1 | token 0
        // current tick
        // <--- 0 for 1  所以 price 是向左移动( sqrtPriceLimitX96 应该在 sqrtPriceCurrentX96 的左边)
        //      1 for 0 --->

        require(
            zeroForOne
                ? sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 &&
                    sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 &&
                    sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
            "Invalid sqrt price limit"
        );

        SwapCache memory cache = SwapCache({liquidityStart: liquidity});

        // true = 卖既定数量的代币
        // false = 买既定数量的代币
        bool exactInput = amountSpecified > 0;

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0Start.sqrtPriceX96, // 当前价格
            tick: slot0Start.tick,
            feeGrowthGlobalX128: zeroForOne
                ? feeGrowthGlobal0X128 // 跟踪 fee 的状态变量
                : feeGrowthGlobal1X128,
            liquidity: cache.liquidityStart
        });

        // 更新 SwapState: 计算 amountCalculated
        // 计算下个 tick => 计算下个 price
        while (
            // amountSpecifiedRemaining > 0 是 exactInput, < 0 是 exactOutput
            state.amountSpecifiedRemaining != 0 &&
            state.sqrtPriceX96 != sqrtPriceLimitX96
        ) {
            StepComputations memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            // 计算下个 tick
            (step.tickNext, step.initialized) = tickBitmap
                .nextInitializedTickWithinOneWord(
                    state.tick,
                    tickSpacing,
                    // zero for one --> price 下降 (增加代币0 的数量， 减少代币1 的数量， tick 会移向左边) --> lte （所以寻找的下一个刻度线小于或等于 current tick）
                    // one for zero --> price 上升 (减少代币0 的数量， 增加代币1 的数量， tick 会移向右边) --> gt （所以寻找的下一个刻度线大于或等于 current tick）
                    zeroForOne
                );

            // 确保 tick 在最大最小tick 之间
            if (step.tickNext < TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            } else if (step.tickNext > TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }

            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            (
                state.sqrtPriceX96,
                step.amountIn,
                step.amountOut,
                step.feeAmount
            ) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                // zero for one --> max(next, limit)  如果 sqrtPriceNextX96 在  sqrtPriceLimitX96 的左边， 则返回 sqrtPriceLimitX96 也就是两者中的最大值（否则返回的是 sqrtPriceNextX96， 也就是两者中的最下值）
                // one for zero --> min(next, limit)
                (
                    zeroForOne
                        ? step.sqrtPriceNextX96 < sqrtPriceLimitX96
                        : step.sqrtPriceNextX96 > sqrtPriceLimitX96
                )
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                fee
            );

            // 如果是 exactInput， 那么 amountSpecifiedRemaining > 0
            // 计算 state.amouontSpecifiedRemainning
            // amountSpecifiedRemaining 是一个内部变量，在执行swap期间，用于跟踪指定数量的代币（输入或输出）中仍有多少需要处理。
            if (exactInput) {
                // 减少到 0
                state.amountSpecifiedRemaining -= (step.amountIn +
                    step.feeAmount).toInt256();
                state.amountCalculated -= step.amountOut.toInt256();
            } else {
                // 增加到 0
                state.amountSpecifiedRemaining += step.amountOut.toInt256();
                state.amountCalculated += (step.amountIn + step.feeAmount)
                    .toInt256();
            }

            // 更新全局费用追踪器 - if state,liquidity > 0
            if (state.liquidity > 0) {
                // fee growth += fee amount * (1 << 128) / liquidity
                state.feeGrowthGlobalX128 += FullMath.mulDiv(
                    step.feeAmount,
                    FixedPoint128.Q128,
                    state.liquidity
                );
            }

            // 达到下个价格时改变 tick
            // step.sqrtPriceNextX96 是下个 tick 的价格， 如果这两者相等， 说明 swap 导致当前 tick 穿过下个 tick
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                if (step.initialized) {
                    // fee 是在 tokenIn 上收取的
                    // 如果是 oneForZero， 那么 feeGrowthGlobal0X128 不变
                    int128 liquidityNet = ticks.cross(
                        step.tickNext,
                        zeroForOne
                            ? state.feeGrowthGlobalX128
                            : feeGrowthGlobal0X128,
                        zeroForOne
                            ? feeGrowthGlobal1X128
                            : state.feeGrowthGlobalX128
                        // 第二种情况： tokenIn 是 token0， 所以 token1 不收取任何费用
                    );

                    // cross 会返回 liquidityNet(根据 trade 的方向, add 或 minus liquidity)
                    // 如果 trade 让价格向右移动，那么 liquidityNet 应该是正值， 如果 trade 让 price 向左移动， 则向流动性净值添加一个负值
                    if (zeroForOne) {
                        liquidityNet = -liquidityNet;
                    }

                    state.liquidity = liquidityNet < 0
                        ? state.liquidity - uint128(-liquidityNet)
                        : state.liquidity + uint128(liquidityNet);
                }
                // zeroForOne = true --> tickNext <= state.tick
                // if tickNext = state.tick --> nextInitializedTick = tickNext,  -1 获取下个tick
                // if tickNext < state.tick --> nextInitializedTick = tickNext, -1 获取下个 tick
                // 根据 nextInitializeTickWithinOneword, tick next 可能返回 current tick(所以要确保 nextTick < currentTick)
                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                // state.sqrtPriceX96 仍位于两个初始话的ticks 之间， 计算 tick
                // Recompute tick
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        // 更新 sqrtPriceX96 and tick
        // 如果 tick begin trade != tick after trade， 那么需要更新当前的价格
        if (state.tick != slot0Start.tick) {
            (slot0.sqrtPriceX96, slot0.tick) = (state.sqrtPriceX96, state.tick);
        } else {
            // 否则只更新价格
            // tick 没有移动， 但是存在 trade 所以存在 sqrtprice
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
        }

        // 更新流动性
        // 如果 trade 后， start liquidity != current liquidity after trade 就更新
        if (cache.liquidityStart != state.liquidity) {
            liquidity = state.liquidity;
        }

        // 更新全局费用
        if (zeroForOne) {
            // tokenIn 是 token0
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
        } else {
            // 否则 tokenIn 是 token1
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
        }

        // 设置 amount0 和 amount1
        (amount0, amount1) = zeroForOne == exactInput
            ? (
                amountSpecified - state.amountSpecifiedRemaining,
                state.amountCalculated
            )
            : (
                state.amountCalculated,
                amountSpecified - state.amountSpecifiedRemaining
            );

        // 转账
        // amount0, amount1: 正数是钱进本合约， 负数是钱转给用户
        if (zeroForOne) {
            if (amount1 < 0) {
                IERC20(token1).transfer(recipient, uint256(-amount1));
                IERC20(token0).transferFrom(
                    msg.sender,
                    address(this),
                    uint256(amount0)
                );
            }
        } else {
            if (amount0 < 0) {
                IERC20(token0).transfer(recipient, uint256(-amount0));
                IERC20(token1).transferFrom(
                    msg.sender,
                    address(this),
                    uint256(amount1)
                );
            }
        }
    }
}
