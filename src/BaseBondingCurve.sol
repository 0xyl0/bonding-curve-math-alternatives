pragma solidity ^0.8.24;

import {IBondingCurve} from "./Interfaces/IBondingCurve.sol";

import "forge-std/console2.sol";

abstract contract BaseBondingCurve is IBondingCurve {
    uint256 public constant DECIMAL_PRECISION = 1e18;
    uint256 public constant ERROR_THRESHOLD = 1e12;

    // The bonding curve is defined as: p = A * s^B
    uint256 public immutable A; // alpha (coefficient) in the bonding curve
    uint256 public immutable B; // beta (exponent) in the bonding curve

    uint256 public currentSupply;
    uint256 public currentBalance;

    constructor(uint256 _alpha, uint256 _beta, uint256 _supply) {
        A = _alpha;
        B = _beta;
        // init pool
        currentSupply = _supply;
        currentBalance = _supply * getPrice(_supply) / (B + DECIMAL_PRECISION);
    }

    function buy(uint256 _reserveAmount) external returns (uint256) {
        uint256 tokenAmount = currentSupply
            * (
                pow(
                    DECIMAL_PRECISION + _reserveAmount * DECIMAL_PRECISION / currentBalance,
                    DECIMAL_PRECISION * DECIMAL_PRECISION / (B + DECIMAL_PRECISION)
                ) - DECIMAL_PRECISION
            ) / DECIMAL_PRECISION;

        currentSupply += tokenAmount;
        currentBalance += _reserveAmount;

        return tokenAmount;
    }

    function sell(uint256 _tokenAmount) external returns (uint256) {
        uint256 reserveAmount = currentBalance
            * (
                DECIMAL_PRECISION
                    - pow(DECIMAL_PRECISION - _tokenAmount * DECIMAL_PRECISION / currentSupply, B + DECIMAL_PRECISION)
            ) / DECIMAL_PRECISION;

        currentSupply -= _tokenAmount;
        currentBalance -= reserveAmount;

        return reserveAmount;
    }

    function getPrice(uint256 _supply) public view returns (uint256) {
        return A * pow(_supply, B) / DECIMAL_PRECISION;
    }

    function currentPrice() external view returns (uint256) {
        return getPrice(currentSupply);
    }

    function _validatePosition(uint256 _supply, uint256 _balance, uint256 _errorThreshold)
        internal
        view
        returns (bool)
    {
        int256 deviation = _reserveRatioDeviation(_supply, _balance);
        uint256 absoluteDiff = deviation > 0 ? uint256(deviation) : uint256(-deviation);

        //console2.log(absoluteDiff * DECIMAL_PRECISION / _balance, "absoluteDiff * DECIMAL_PRECISION / _balance");
        if (absoluteDiff * DECIMAL_PRECISION / _balance < _errorThreshold) return true;
        return false;
    }

    function validateBuy(uint256 _tokenAmount, uint256 _reserveAmount) external view returns (bool) {
        uint256 newSupply = currentSupply + _tokenAmount;
        uint256 newBalance = currentBalance + _reserveAmount;
        return _validatePosition(newSupply, newBalance, ERROR_THRESHOLD);
    }

    function validateSell(uint256 _tokenAmount, uint256 _reserveAmount) external view returns (bool) {
        uint256 newSupply = currentSupply - _tokenAmount;
        uint256 newBalance = currentBalance - _reserveAmount;
        return _validatePosition(newSupply, newBalance, ERROR_THRESHOLD);
    }

    function _reserveRatioDeviation(uint256 _supply, uint256 _balance) internal view returns (int256) {
        return (int256(_supply * getPrice(_supply)) - int256((B + DECIMAL_PRECISION) * _balance))
            / int256(DECIMAL_PRECISION);
    }

    function reserveRatioDeviation() external view returns (int256) {
        return _reserveRatioDeviation(currentSupply, currentBalance);
    }

    function checkCurrentDeviation() external view returns (bool) {
        return checkCurrentDeviation(ERROR_THRESHOLD);
    }

    function checkCurrentDeviation(uint256 _errorThreshold) public view returns (bool) {
        return _validatePosition(currentSupply, currentBalance, _errorThreshold);
    }

    // Unimplemented functions
    function pow(uint256 _base, uint256 _exponent) public pure virtual returns (uint256);
}
