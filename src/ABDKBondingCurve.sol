pragma solidity ^0.8.24;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "./BaseBondingCurve.sol";

import "forge-std/console2.sol";

contract ABDKBondingCurve is BaseBondingCurve {
    using ABDKMath64x64 for uint256;
    using ABDKMath64x64 for int128;

    constructor(uint256 _alpha, uint256 _beta, uint256 _supply) BaseBondingCurve(_alpha, _beta, _supply) {}

    function pow(uint256 _base, uint256 _exponent) public pure override returns (uint256) {
        // _base ^ _exponent = 2 ^ (_exponent * log_2(_base))
        /*
        console2.log("-- pow --");
        console2.log(toUint(fromUint(_base)), "from -> to base");
        console2.log(toUint(fromUint(_exponent)), "from -> to exp");
        console2.log(toUint(ABDKMath64x64.log_2(fromUint(_base))), "log");
        console2.log(toUint(fromUint(_exponent).mul(ABDKMath64x64.log_2(fromUint(_base)))), "exp");
        console2.log(toUint(ABDKMath64x64.exp_2(fromUint(_exponent).mul(ABDKMath64x64.log_2(fromUint(_base))))), "return");
        */
        return toUint(ABDKMath64x64.exp_2(fromUint(_exponent).mul(ABDKMath64x64.log_2(fromUint(_base)))));
    }

    function fromUint (uint256 x) internal pure returns (int128) {
        unchecked {
            require (x <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
            uint256 i1 = x / DECIMAL_PRECISION;
            uint256 i2 = i1 << 64;
            // DECIMAL_PRECISION < 0xFFFFFFFFFFFFFFFF, so this is fine:
            uint256 d = ((x - i1 * DECIMAL_PRECISION) << 64) / DECIMAL_PRECISION;
            /*
            console2.log(x, "fromUint x");
            console2.log(i1, "i1");
            console2.logBytes32(bytes32(i2));
            console2.log(x - i1 * DECIMAL_PRECISION, "x-i1 * DECIMAL_PRECISION");
            console2.log(d, "d");
            console2.logBytes32(bytes32(d));
            */
            return int128 (int256 (i2) + int256(d));
        }
    }

    function toUint (int128 x) internal pure returns (uint256) {
        unchecked {
            require (x >= 0);
            uint256 y = uint256(uint128 (x));
            uint256 i1 = y >> 64;
            uint256 i2 = i1 * DECIMAL_PRECISION;
            uint256 d = (y - (i1 << 64)) * DECIMAL_PRECISION >> 64;
            /*
            console2.log(y, "toUint x");
            console2.logBytes32(bytes32(y));
            console2.log(i2, "i2");
            console2.log(y-(i1<<64), "y-i1");
            console2.log(d, "d");
            */
            return i2 + d;
        }
    }
}
