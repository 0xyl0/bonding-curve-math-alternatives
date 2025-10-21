// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {IBondingCurve} from "../src/Interfaces/IBondingCurve.sol";
import {ABDKBondingCurve} from "../src/ABDKBondingCurve.sol";
import {PRBBondingCurve} from "../src/PRBBondingCurve.sol";

contract BondingCurveTest is Test {
    //ABDKBondingCurve public abdkBondingCurve;

    function setUp() public {
        //abdkBondingCurve = new ABDKBondingCurve(2 ether, 0.5 ether, 1000 ether);
    }

    function logState(IBondingCurve _bc) internal view {
        console2.log(_bc.currentSupply(), "Current supply");
        console2.log(_bc.currentBalance(), "Current balance");
        console2.log(_bc.currentPrice(), "Current price");
    }

    function logDeviation(IBondingCurve _bc) internal view {
        int256 d = _bc.reserveRatioDeviation();
        if (d >= 0) {
            console2.log(uint256(d), "reserveRatioDeviation");

        } else {
            console2.log(uint256(-d), "-reserveRatioDeviation");
        }
    }

    function _testSimple(IBondingCurve _bc, uint256 _runs, uint256 _maxTokenDeviation, uint256 _maxReserveDeviation, uint256 _rrDeviation) internal {
        console2.log("-- before --");
        logState(_bc);
        logDeviation(_bc);

        uint256 initialReserveAmount = 500 ether;
        uint256 initialTokenAmount = _bc.buy(initialReserveAmount);
        console2.log(initialTokenAmount, "initialTokenAmount");
        uint256 reserveAmount;
        uint256 tokenAmount = initialTokenAmount;
        for (uint256 i = 0; i < _runs; i++) {
            reserveAmount = _bc.sell(tokenAmount);
            tokenAmount = _bc.buy(reserveAmount);
        }
        reserveAmount = _bc.sell(tokenAmount);

        console2.log("-- after --");
        logState(_bc);
        logDeviation(_bc);

        assertApproxEqAbs(initialTokenAmount, tokenAmount, _maxTokenDeviation, "Too much token deviation");
        assertApproxEqAbs(initialReserveAmount, reserveAmount, _maxReserveDeviation, "Too much reserve deviation");
        assertTrue(_bc.checkCurrentDeviation(_rrDeviation), "Too much reserve ratio deviation");
    }

    function _testFuzzBuy(IBondingCurve _bc, uint256 _x) internal {
        _bc.buy(_x);

        assert(_bc.checkCurrentDeviation());
    }

    function _testFuzzSell(IBondingCurve _bc, uint256 _x) internal {
        _bc.sell(_x);

        assert(_bc.checkCurrentDeviation());
    }

    // -- ABDK --

    function testABDKSimple() public {
        ABDKBondingCurve abdkBondingCurve = new ABDKBondingCurve(2 ether, 0.5 ether, 1000 ether);

        _testSimple(IBondingCurve(abdkBondingCurve), 10000, 1e5, 1e7, 100);
    }

    function testABDKFuzzBuy(uint256 _initialSupply, uint256 _x) public {
        // TODO: what is the min?
        //_initialSupply = bound(_initialSupply, 1, 1e9 ether);
        _initialSupply = bound(_initialSupply, 0.0001 ether, 1e9 ether);
        _x = bound(_x, 1, 1e9 ether);

        ABDKBondingCurve abdkBondingCurve = new ABDKBondingCurve(2 ether, 0.5 ether, _initialSupply);

        _testFuzzBuy(IBondingCurve(abdkBondingCurve), _x);
    }

    function testABDKFuzzSell(uint256 _initialSupply, uint256 _x) public {
        // TODO: min/max values
        //_initialSupply = bound(_initialSupply, 1, 1e9 ether);
        _initialSupply = bound(_initialSupply, 0.0001 ether, 1e9 ether);
        //_x = bound(_x, 1, _initialSupply);
        _x = bound(_x, 1, _initialSupply * 99999 / 100000);

        ABDKBondingCurve abdkBondingCurve = new ABDKBondingCurve(2 ether, 0.5 ether, _initialSupply);

        _testFuzzSell(IBondingCurve(abdkBondingCurve), _x);
    }

    // -- PRB --

    function testPRBSimple() public {
        PRBBondingCurve prbBondingCurve = new PRBBondingCurve(2 ether, 0.5 ether, 1000 ether);

        _testSimple(IBondingCurve(prbBondingCurve), 10000, 1e9, 1e12, 1e6);
    }

    function testPRBFuzz_Buy(uint256 _initialSupply, uint256 _x) public {
        // TODO: what is the min?
        //_initialSupply = bound(_initialSupply, 1, 1e9 ether);
        _initialSupply = bound(_initialSupply, 0.0001 ether, 1e9 ether);
        _x = bound(_x, 1, 1e9 ether);

        PRBBondingCurve prbBondingCurve = new PRBBondingCurve(2 ether, 0.5 ether, _initialSupply);

        _testFuzzBuy(IBondingCurve(prbBondingCurve), _x);
    }

    function testPRBFuzzSell(uint256 _initialSupply, uint256 _x) public {
        // TODO: min/max values
        //_initialSupply = bound(_initialSupply, 1, 1e9 ether);
        _initialSupply = bound(_initialSupply, 0.0001 ether, 1e9 ether);
        //_x = bound(_x, 1, _initialSupply);
        _x = bound(_x, 1, _initialSupply * 99999 / 100000);

        PRBBondingCurve prbBondingCurve = new PRBBondingCurve(2 ether, 0.5 ether, _initialSupply);

        _testFuzzSell(IBondingCurve(prbBondingCurve), _x);
    }
}
