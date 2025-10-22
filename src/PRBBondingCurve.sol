pragma solidity ^0.8.24;

import {wrap, unwrap, pow as SD59x18_pow} from "prb-math/SD59x18.sol";
import "./BaseBondingCurve.sol";

import "forge-std/console2.sol";

contract PRBBondingCurve is BaseBondingCurve {
    constructor(
        uint256 _alpha,
        uint256 _beta,
        uint256 _supply,
        IERC20 _reserveToken,
        string memory _name,
        string memory _symbol
    ) BaseBondingCurve(_alpha, _beta, _supply, _reserveToken, _name, _symbol) {}

    function pow(uint256 _base, uint256 _exponent) public pure override returns (uint256) {
        // Internally uses 2 ^ (_exponent * log_2(_base))
        return uint256(SD59x18_pow(wrap(int256(_base)), wrap(int256(_exponent))).unwrap());
    }
}
