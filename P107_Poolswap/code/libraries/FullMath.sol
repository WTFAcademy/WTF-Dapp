// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

///@title 完整数学库
library FullMath {
    ///@notice 以全精度计算下限(a×b÷分母)。如果结果溢出 uint256 或分母 == 0，则抛出异常
    ///@param a 被乘数
    ///@param b 乘数
    ///@param 分母 除数
    ///@return result 256位结果
    ///@dev 在 MIT 许可下归功于 Remco Bloemen https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        //512 位乘法 [prod1 prod0] = a *b
        //计算 mod 2**256 和 mod 2**256 -1 的乘积
        //然后用中国剩余定理重构
        //512 位结果。结果存储在两个256中
        //变量使得product = prod1 *2**256 + prod0
        uint256 prod0; //产品的最低有效 256 位
        uint256 prod1; //产品的最高有效 256 位
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        //处理非溢出情况，256 x 256 除法
        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        //确保结果小于 2**256。
        //还可以防止分母 == 0
        require(denominator > prod1);

        //////////////////////////////////////////////////////////////////////////////////////
        //512 除以 256。
        //////////////////////////////////////////////////////////////////////////////////////

        //通过从 [prod1 prod0] 中减去余数来使除法精确
        //使用 mulmod 计算余数
        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        //从 512 位数字中减去 256 位数字
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        //分母中二的因数幂
        //计算分母的二除数的最大幂。
        //始终 >= 1。
        uint256 twos = denominator & denominator;
        //分母除以二的幂
        assembly {
            denominator := div(denominator, twos)
        }

        //将 [prod1 prod0] 除以 2 的因数
        assembly {
            prod0 := div(prod0, twos)
        }
        //将位从 prod1 移入 prod0。为此我们需要
        //翻转 `twos`，使其变为 2**256 /twos。
        //如果twos为零，那么它就变成1
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        //反转分母 mod 2**256
        //现在分母是奇数，它有一个倒数
        //模 2**256，使得分母 *inv = 1 mod 2**256。
        //从正确的种子开始计算逆矩阵
        //四位正确。即分母 *inv = 1 mod 2**4
        uint256 inv = (3 * denominator) ^ 2;
        //现在使用牛顿-拉夫森迭代来提高精度。
        //感谢 Hensel 的提升引理，这也适用于模块化
        //算术，在每一步中将正确的位加倍。
        inv *= 2 - denominator * inv; // 逆模 2**8
        inv *= 2 - denominator * inv; // 逆模 2**16
        inv *= 2 - denominator * inv; // 逆模 2**32
        inv *= 2 - denominator * inv; // 逆模 2**64
        inv *= 2 - denominator * inv; // 逆模 2**128
        inv *= 2 - denominator * inv; //逆模 2**256

        //因为除法现在是精确的，所以我们可以除以乘法
        //分母的模逆。这将为我们提供
        //正确结果模 2**256。由于预条件保证
        //结果小于2**256，这是最终结果。
        //我们不需要计算结果和 prod1 的高位
        //不再需要。
        result = prod0 * inv;
        return result;
    }

    ///@notice 以全精度计算 ceil(a×b÷分母)。如果结果溢出 uint256 或分母 == 0，则抛出异常
    ///@param a 被乘数
    ///@param b 乘数
    ///@param 分母 除数
    ///@return result 256位结果
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }
}