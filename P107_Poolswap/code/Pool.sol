// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;
import './interfaces/IUniswapV3Pool.sol';
import './interfaces/pool/IPool.sol';

import './NoDelegateCall.sol';

// 优化溢出和下溢 安全的数学操作
import './libraries/LowGasSafeMath.sol';

import './libraries/SafeCast.sol';
import './libraries/Tick.sol';
import './libraries/TickBitmap.sol';
import './libraries/Position.sol';
import './libraries/Oracle.sol';

import './libraries/FullMath.sol';
import './libraries/FixedPoint128.sol';
import './libraries/TransferHelper.sol';
import './libraries/TickMath.sol';
import './libraries/LiquidityMath.sol';
import './libraries/SqrtPriceMath.sol';
import './libraries/SwapMath.sol';

import './interfaces/IUniswapV3PoolDeployer.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IERC20Minimal.sol';
import './interfaces/callback/IUniswapV3MintCallback.sol';
import './interfaces/callback/IUniswapV3SwapCallback.sol';
import './interfaces/callback/IUniswapV3FlashCallback.sol';

interface IMintCallback {
    function mintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}

interface ISwapCallback {
    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}

interface IPool {
    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function fee() external view returns (uint24);

    function tickLower() external view returns (int24);

    function tickUpper() external view returns (int24);

    function sqrtPriceX96() external view returns (uint160);

    function tick() external view returns (int24);

    function liquidity() external view returns (uint128);

    function initialize(
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) external;

    event Mint(
        address sender,
        address indexed owner,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    function mint(
        address recipient,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    event Collect(
        address indexed owner,
        address recipient,
        uint128 amount0,
        uint128 amount1
    );

    function collect(
        address recipient
    ) external returns (uint128 amount0, uint128 amount1);

    event Burn(
        address indexed owner,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    function burn(
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

abstract contract Pool is IPool, NoDelegateCall {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;
    // tick 元数据管理的库
    using Tick for mapping(int24 => Tick.Info);
    // tick 位图槽位的库
    using TickBitmap for mapping(int16 => uint256);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using Oracle for Oracle.Observation[65535];        // Oracle 相关操作的库

    // 记录 token0 的每单位流动性所获取的手续费
    uint256 public  feeGrowthGlobal0X128;
    // 记录 token1 的每单位流动性所获取的手续费
    uint256 public  feeGrowthGlobal1X128;

    int24 public   tickSpacing;

    address  public _factory;
    // address public   factory;

    address public   _token0;

    address public   _token1;

    uint24 public   _fee;


    int24 public   _tickSpacing;
    // 表示每个 tick 能接受的最大流动性
    uint128 public   _maxLiquidityPerTick;
    // 记录了池子当前可用的流动性
    uint128 public  liquidity_;

    int24 public _tickLower;
    int24 public _tickUpper;
    struct ProtocolFees {
        uint128 token0;
        uint128 token1;
    }

    ProtocolFees private  protocolFees;
    // 记录了一个 tick 包含的元数据，这里只会包含所有 Position 的 lower/upper ticks
    // 记录池子里每个 tick 的详细信息，key 为 tick 的序号，value 就是详细信息。
    mapping(int24 => Tick.Info) public ticks;
    // tick 位图，因为这个位图比较长（一共有 887272x2 个位），大部分的位不需要初始化
    // 因此分成两级来管理，每 256 位为一个单位，一个单位称为一个 word
    //  记录已初始化的 tick 的位图。
    mapping(int16 => uint256) private  tickBitmap;
    
    mapping(bytes32 => Position.Info) private  positions_;
    // 使用数据记录 Oracle 的值
    Oracle.Observation[65535] private  observations;

    struct Slot0 {
        // 这个值代表的是 token0 和 token1 数量比例的平方根，经过放大以获得更高的精度。
        uint160 sqrtPriceX96;
        // 记录了当前价格对应的价格点
        int24 tick;
        // 记录了最近一次 Oracle 记录在 Oracle 数组中的索引位置
        uint16 observationIndex;
        // 已经存储的 Oracle 数量
        uint16 observationCardinality;
        // 可用的 Oracle 空间，此值初始时会被设置为 1，后续根据需要来可以扩展
        uint16 observationCardinalityNext;
        // 协议费率
        uint8 feeProtocol;
        // 记录池子的锁定状态
        bool unlocked;
    }

    Slot0 public  slot0;

    function factory() external view override returns (address) {
        return _factory;
    }

    function token0() external view override returns (address) {
        return _token0;
    }

    function token1() external view override returns (address) {
        return _token1;
    }

    function fee() external view override returns (uint24) {
        return _fee;
    }

    function tickLower() external view override returns (int24) {
        return _tickLower;
    }

    function tickUpper() external view override returns (int24) {
        return _tickUpper;
    }

    function sqrtPriceX96() external view override returns (uint160) {
        return slot0.sqrtPriceX96;
    }

    function tick() external view override returns (int24) {
        return slot0.tick;
    }

    function liquidity() external view  returns (uint128) {
        return liquidity_;
    }

    function checkTicks(int24 tickLower, int24 tickUpper) private pure {
        require(tickLower < tickUpper, 'TLU');
        require(tickLower >= TickMath.MIN_TICK, 'TLM');
        require(tickUpper <= TickMath.MAX_TICK, 'TUM');
    }

    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    function positions(
        int8 positionType
    )
        external
        view
        
        returns (uint128 _liquidity, uint128 tokensOwed0, uint128 tokensOwed1)
    {
        bytes32 key = bytes32(uint256(uint8(positionType)));
        _liquidity = positions_[key].liquidity;
        tokensOwed0 = positions_[key].tokensOwed0;
        tokensOwed1 = positions_[key].tokensOwed1;
    }

    // 初始化 slot0 状态
    function initialize(
        uint160 sqrtPriceX96, 
        int24 tickLower_, 
        int24 tickUpper_
        ) external override {
        require(slot0.sqrtPriceX96 == 0, 'AI');

        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        (uint16 cardinality, uint16 cardinalityNext) = observations.initialize(_blockTimestamp());

        slot0 = Slot0({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            observationIndex: 0,
            observationCardinality: cardinality,
            observationCardinalityNext: cardinalityNext,
            feeProtocol: 0,
            unlocked: true
        });

        // emit Initialize(sqrtPriceX96, tick);
    }
    // 添加流动性
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external  returns (uint256 amount0, uint256 amount1) {
        require(amount > 0);
        (, int256 amount0Int, int256 amount1Int) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: recipient,
                    tickLower: _tickLower,
                    tickUpper: _tickUpper,
                    liquidityDelta: int128(amount)
                })
            );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);
        if (amount0 > 0) require(balance0Before.add(amount0) <= balance0(), 'M0');
        if (amount1 > 0) require(balance1Before.add(amount1) <= balance1(), 'M1');

        emit Mint(msg.sender, recipient, amount, amount0, amount1);
    }
    // 提取收益
    function collect(
        address recipient,
        int8 positionType
    ) external  returns (uint128 amount0, uint128 amount1) {

    }

    struct ModifyPositionParams {
        // 流动性的接收者地址
        address owner;
        // 区间价格下限的 tick 序号
        int24 tickLower;
        // 区间价格上限的 tick 序号
        int24 tickUpper;
        // 待添加的流动性数量
        int128 liquidityDelta;
    }

    function _modifyPosition(ModifyPositionParams memory params)
        private
        noDelegateCall
        returns (
            Position.Info storage position,
            int256 amount0,
            int256 amount1
        )
    {
        // 检查Tick的上下限是否符合边界条件
        checkTicks(params.tickLower, params.tickUpper);
        // 从storage位置转存到内存中，后续访问可节省gas
        Slot0 memory _slot0 = slot0; // SLOAD for gas optimization
        // 第一步核心操作，更新 position 的数据
        position = _updatePosition(
            params.owner,
            params.tickLower,
            params.tickUpper,
            params.liquidityDelta,
            _slot0.tick
        );
        // 计算三种情况下 amount0 和 amount1 的值，即 x token 和 y token 的数量
        if (params.liquidityDelta != 0) {
            if (_slot0.tick < params.tickLower) {
                // 当前报价低于传递的范围；流动性只能通过从左到右交叉而进入范围内，需要提供更多token0
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            } else if (_slot0.tick < params.tickUpper) {
                // // 当前报价在传递的范围内
                uint128 liquidityBefore = liquidity_; // SLOAD for gas optimization

                // 更新预言机相关状态数据
                (slot0.observationIndex, slot0.observationCardinality) = observations.write(
                    _slot0.observationIndex,
                    _blockTimestamp(),
                    _slot0.tick,
                    liquidityBefore,
                    _slot0.observationCardinality,
                    _slot0.observationCardinalityNext
                );
                // 计算当前价格到价格区间上限之间需支付的amount0
                amount0 = SqrtPriceMath.getAmount0Delta(
                    _slot0.sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
                // 计算从价格区间下限到当前价格之间需支付的amount1
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    _slot0.sqrtPriceX96,
                    params.liquidityDelta
                );
                // 当前有效头寸的总流动性增加
                liquidity_ = LiquidityMath.addDelta(liquidityBefore, params.liquidityDelta);
            } else {
                // 当前报价高于传递的范围；流动性只能通过从右到左交叉而进入范围内，需要提供更多token1
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            }
        }
    }

    /// @dev Gets and updates a position with the given liquidity delta
    /// @param owner the owner of the position
    /// @param tickLower the lower tick of the position's tick range
    /// @param tickUpper the upper tick of the position's tick range
    /// @param tick the current tick, passed to avoid sloads
    function _updatePosition(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,   // liquidityDelta 是需要增加或减少的流动性，该值为正数则表示要增加流动性，负数则是要减少流动性。
        int24 tick                      //tick 是当前激活的 tick，即 slot0 中保存的 tick 
    ) private returns (Position.Info storage position) {
        // 获取用户的流动性头寸
        position = positions_.get(owner, tickLower, tickUpper);

        uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128; // SLOAD for gas optimization
        uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128; // SLOAD for gas optimization

        // 根据传入的参数修改 Position 对应的 lower/upper tick 中
        // 的数据，这里可以是增加流动性，也可以是移出流动性
        bool flippedLower;
        bool flippedUpper;
        if (liquidityDelta != 0) {
            uint32 time = _blockTimestamp();
            // 预言机相关数据
            (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) =
                observations.observeSingle(
                    time,
                    0,
                    slot0.tick,
                    slot0.observationIndex,
                    liquidity_,
                    slot0.observationCardinality
                );

            // 更新 lower tikc 和 upper tick
            // fippedX 变量表示是此 tick 的引用状态是否发生变化，即
            // 被引用 -> 未被引用 或
            // 未被引用 -> 被引用
            // 后续需要根据这个变量的值来更新 tick 位图
            // 更新tickLower的数据
            flippedLower = ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                secondsPerLiquidityCumulativeX128,
                tickCumulative,
                time,
                false,
                _maxLiquidityPerTick
            );

            // 更新tickUpper的数据
            flippedUpper = ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                secondsPerLiquidityCumulativeX128,
                tickCumulative,
                time,
                true,
                _maxLiquidityPerTick
            );
            // 如果一个 tick 第一次被引用，或者移除了所有引用
            // 那么更新 tick 位图
            if (flippedLower) {
                // 在tick位图中翻转lower tick的状态
                tickBitmap.flipTick(tickLower, tickSpacing);
            }
            if (flippedUpper) {
                tickBitmap.flipTick(tickUpper, tickSpacing);
            }
        }
        // 计算增长的手续费
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            ticks.getFeeGrowthInside(tickLower, tickUpper, tick, _feeGrowthGlobal0X128, _feeGrowthGlobal1X128);
        // 更新头寸元数据
        position.update(liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

        // 如果移除了对 tick 的引用，那么清除之前记录的元数据
        // 清理不再需要用到的tick数据
        if (liquidityDelta < 0) {
            if (flippedLower) {
                ticks.clear(tickLower);
            }
            if (flippedUpper) {
                ticks.clear(tickUpper);
            }
        }
    }


    // 移除流动性时的处理方式并不是直接把两种 token 资产转给用户，而是先累加到 tokensOwed0 和 tokensOwed1，代表这是欠用户的资产，其中也包括该头寸已赚取到的手续费。
    // 之后，用户其实是要通过 collect 函数来提取 tokensOwed0 和 tokensOwed1 里的资产。
    function burn(
        uint128 amount
    ) external  returns (uint256 amount0, uint256 amount1) {
        (Position.Info storage position, int256 amount0Int, int256 amount1Int) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: msg.sender,
                    tickLower: _tickLower,
                    tickUpper: _tickUpper,
                    liquidityDelta: int128(amount)   // 移除流动性需转为负数
                })
            );
        // 将负数转为正数
        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            (position.tokensOwed0, position.tokensOwed1) = (
                position.tokensOwed0 + uint128(amount0),
                position.tokensOwed1 + uint128(amount1)
            );
        }

        emit Burn(msg.sender,  uint128(amount), amount0, amount1);
    }

    struct SwapCache {
        // 转入token的协议费用
        uint8 feeProtocol;
        // swap开始时的流动性
        uint128 liquidityStart;
        // 当前块的时间戳
        uint32 blockTimestamp;
        // 刻度累加器的当前值，仅在经过初始化的刻度时计算
        int56 tickCumulative;
        // 每个流动性累加器的当前秒值，仅在经过初始化的刻度时计算
        uint160 secondsPerLiquidityCumulativeX128;
        // 是否计算并缓存了上面两个累加器
        bool computedLatestObservation;
    }

    // 交换的顶层状态，交换的结果在最后被记录在存储中
        struct SwapState {
        // 在输入/输出资产中要交换的剩余金额
        int256 amountSpecifiedRemaining;
        // 已交换出/输入的输出/输入资产的数量
        int256 amountCalculated;
        // 当前价格的平方根
        uint160 sqrtPriceX96;
        // 与当前价格相关的tick
        int24 tick;
        // 输入token的全局费用增长
        uint256 feeGrowthGlobalX128;
        // 作为协议费支付的输入token数量
        uint128 protocolFee;
        // 当前流动性在一定范围内
        uint128 liquidity;
    }

    struct StepComputations {
        // 步骤开始时的价格
        uint160 sqrtPriceStartX96;
        // 根据当前刻度的交易方向的下一个刻度
        int24 tickNext;
        // 下一个tick是否初始化过（有流动性）
        bool initialized;
        // token0的下一个tick平方根价格
        uint160 sqrtPriceNextX96;
        // 这个步骤多少被交易注入的量，这一步消耗多少
        uint256 amountIn;
        // 多少金额被交易输出
        uint256 amountOut;
        // 多少费用需要被被支付，做市商费用
        uint256 feeAmount;
    }
    /// 兑换
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {
        require(amountSpecified != 0, 'AS');
        // 将交易前的元数据保存在内存中，后续的访问通过 `MLOAD` 完成，节省 gas
        Slot0 memory slot0Start = slot0;

        require(slot0Start.unlocked, 'LOK');
        require(
            zeroForOne
                ? sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
            'SPL'
        );
        // 防止交易过程中回调到合约中其他的函数中修改状态变量
        slot0.unlocked = false;
        // 将交易前的元数据保存在内存中，后续的访问通过 `MLOAD` 完成，节省 gas
        SwapCache memory cache =
            SwapCache({
                liquidityStart: liquidity_,
                blockTimestamp: _blockTimestamp(),
                feeProtocol: zeroForOne ? (slot0Start.feeProtocol % 16) : (slot0Start.feeProtocol >> 4),
                secondsPerLiquidityCumulativeX128: 0,
                tickCumulative: 0,
                computedLatestObservation: false
            });
        // 判断是否指定了 tokenIn 的数量
        bool exactInput = amountSpecified > 0;
        // 保存交易过程中计算所需的中间变量，这些值在交易的步骤中可能会发生变化
        SwapState memory state =
            SwapState({
                amountSpecifiedRemaining: amountSpecified,
                amountCalculated: 0,
                sqrtPriceX96: slot0Start.sqrtPriceX96,
                tick: slot0Start.tick,
                feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
                protocolFee: 0,
                liquidity: cache.liquidityStart
            });

        // 当剩余可交易金额为零，或交易后价格达到了限定的价格之后才退出循环
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
            // 缓存每一次循环的状态变量
            StepComputations memory step;
            // 交易的起始价格
            step.sqrtPriceStartX96 = state.sqrtPriceX96;
            // 通过 tick 位图找到下一个已初始化的 tick，即下一个流动性边界点
            (step.tickNext, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                tickSpacing,
                zeroForOne
            );

            // 通过位图找到下一个可以选的交易价格，这里可能是下一个流动性的边界，也可能还是在本流动性中
            if (step.tickNext < TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            } else if (step.tickNext > TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }

            // 将上一步找到的下一个 tick 转为根号价格
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            // 在当前价格和下一口价格之间计算交易结果，返回最新价格、消耗的 amountIn、输出的 amountOut 和手续费 feeAmount
            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                _fee
            );
            // 此时的剩余可交易金额为正数，需减去消耗的输入 amountIn 和手续费 feeAmount
            if (exactInput) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
                // 此时该值表示 tokenOut 的累加值，结果为负数
                state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
            } else {
                // 此时的剩余可交易金额为负数，需加上输出的 amountOut
                state.amountSpecifiedRemaining += step.amountOut.toInt256();
                // 此时该值表示 tokenIn 的累加值，结果为正数
                state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
            }

            //如果开启了协议费用，则计算所欠金额，减少feeAmount，并增加protocolFee
            if (cache.feeProtocol > 0) {
                uint256 delta = step.feeAmount / cache.feeProtocol;
                step.feeAmount -= delta;
                state.protocolFee += uint128(delta);
            }

           //更新全局协议费用
            if (state.liquidity > 0)
                state.feeGrowthGlobalX128 += FullMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);

            // 如果达到了下一个价格，则需要移动 tick
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                // 如果 tick 已经初始化，则需要执行 tick 的转换
                if (step.initialized) {

                    if (!cache.computedLatestObservation) {
                        (cache.tickCumulative, cache.secondsPerLiquidityCumulativeX128) = observations.observeSingle(
                            cache.blockTimestamp,
                            0,
                            slot0Start.tick,
                            slot0Start.observationIndex,
                            cache.liquidityStart,
                            slot0Start.observationCardinality
                        );
                        cache.computedLatestObservation = true;
                    }
                    // 转换到下一个 tick
                    int128 liquidityNet =
                        ticks.cross(
                            step.tickNext,
                            (zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128),
                            (zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128),
                            cache.secondsPerLiquidityCumulativeX128,
                            cache.tickCumulative,
                            cache.blockTimestamp
                        );
                    // 根据交易方向增加/减少相应的流动性
                    if (zeroForOne) liquidityNet = -liquidityNet;
                    // 更新流动性
                    state.liquidity = LiquidityMath.addDelta(state.liquidity, liquidityNet);
                }
                // 更新 tick
                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                // 如果不需要移动 tick，则根据最新价格换算成最新的 tick
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        //如果价格变动则更新价格变动并写入 oracle tick
        if (state.tick != slot0Start.tick) {
            (uint16 observationIndex, uint16 observationCardinality) =
                observations.write(
                    slot0Start.observationIndex,
                    cache.blockTimestamp,
                    slot0Start.tick,
                    cache.liquidityStart,
                    slot0Start.observationCardinality,
                    slot0Start.observationCardinalityNext
                );
            (slot0.sqrtPriceX96, slot0.tick, slot0.observationIndex, slot0.observationCardinality) = (
                state.sqrtPriceX96,
                state.tick,
                observationIndex,
                observationCardinality
            );
        } else {
            //否则只更新价格
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
        }

        //如果流动性发生变化则更新
        if (cache.liquidityStart != state.liquidity) liquidity_ = state.liquidity;

        //更新全局费用增长，如有必要，更新协议费用
        //溢出是可以接受的，协议必须在达到 type(uint128).max 费用之前撤回
        if (zeroForOne) {
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
            if (state.protocolFee > 0) protocolFees.token0 += state.protocolFee;
        } else {
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
            if (state.protocolFee > 0) protocolFees.token1 += state.protocolFee;
        }
        // 确定最终用户支付的 token 数和得到的 token 数
        (amount0, amount1) = zeroForOne == exactInput
            ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
            : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);

        //// 扣除用户需要支付的 token
        if (zeroForOne) {
            // 将 tokenOut 支付给用户，前面说过 tokenOut 记录的是负数
            if (amount1 < 0) TransferHelper.safeTransfer(_token1, recipient, uint256(-amount1));

            uint256 balance0Before = balance0();
            // 还是通过回调的方式，扣除用户需要支持的 token
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            // 校验扣除是否成功
            require(balance0Before.add(uint256(amount0)) <= balance0(), 'IIA');
        } else {
            if (amount0 < 0) TransferHelper.safeTransfer(_token0, recipient, uint256(-amount0));

            uint256 balance1Before = balance1();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            require(balance1Before.add(uint256(amount1)) <= balance1(), 'IIA');
        }
        // 记录日志
        emit Swap(msg.sender, recipient, amount0, amount1, state.sqrtPriceX96, state.liquidity, state.tick);
        // 解除防止重入的锁
        slot0.unlocked = true;
    }

    /// @dev 获取 token0 余额
    ///@dev 该函数经过了 Gas 优化，以避免除了 returndatasize 之外的冗余 extcodesize 检查
    function balance0() private view returns (uint256) {
        (bool success, bytes memory data) =
            _token0.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev 获取 token1 余额
    ///@dev 该函数经过了 Gas 优化，以避免除了 returndatasize 之外的冗余 extcodesize 检查
    ///查看
    function balance1() private view returns (uint256) {
        (bool success, bytes memory data) =
            _token1.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

}