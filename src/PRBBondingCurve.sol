pragma solidity ^0.8.24;

import { SD59x18, wrap, unwrap } from "prb-math/SD59x18.sol";
import "./BaseBondingCurve.sol";

import "forge-std/console2.sol";

contract PRBBondingCurve is BaseBondingCurve {
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
        return uint256(wrap(int256(_exponent)).mul(wrap(int256(_base)).log2()).exp2().unwrap());
    }
}
