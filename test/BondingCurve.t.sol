// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {Test, console2} from "forge-std/Test.sol";

import {IBondingCurve} from "../src/Interfaces/IBondingCurve.sol";
import {ABDKBondingCurve} from "../src/ABDKBondingCurve.sol";
import {PRBBondingCurve} from "../src/PRBBondingCurve.sol";

import {ERC20Mock} from "./TestContracts/ERC20Mock.sol";

contract BondingCurveTest is Test {
    ERC20Mock reserveToken;

    function setUp() public {
        reserveToken = new ERC20Mock("WETH", "WETH");
        reserveToken.mint(address(this), 1e12 ether);
    }

    function _setUpBondingCurve(IBondingCurve _bc) internal {
        // TODO: get rid of
        reserveToken.transfer(address(_bc), _bc.currentBalance());
        reserveToken.approve(address(_bc), type(uint256).max);
    }

    function _setUpABDK(uint256 _initialSupply) internal returns (IBondingCurve) {
        IBondingCurve abdkBondingCurve =
            new ABDKBondingCurve(2 ether, 0.5 ether, _initialSupply, IERC20(reserveToken), "ABDK token", "TKN");

        _setUpBondingCurve(abdkBondingCurve);

        return abdkBondingCurve;
    }

    function _setUpPRB(uint256 _initialSupply) internal returns (IBondingCurve) {
        IBondingCurve prbBondingCurve =
            new PRBBondingCurve(2 ether, 0.5 ether, _initialSupply, IERC20(reserveToken), "ABDK token", "TKN");

        _setUpBondingCurve(prbBondingCurve);

        return prbBondingCurve;
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

    function _testSimple(
        IBondingCurve _bc,
        uint256 _runs,
        uint256 _maxTokenDeviation,
        uint256 _maxReserveDeviation,
        uint256 _rrDeviation
    ) internal {
        console2.log("-- before --");
        logState(_bc);
        logDeviation(_bc);

        uint256 initialReserveAmount = 500 ether;
        uint256 initialTokenAmount = _bc.buy(initialReserveAmount, 0);
        //console2.log(initialTokenAmount, "initialTokenAmount");
        uint256 reserveAmount;
        uint256 tokenAmount = initialTokenAmount;
        for (uint256 i = 0; i < _runs; i++) {
            reserveAmount = _bc.sell(tokenAmount, 0);
            tokenAmount = _bc.buy(reserveAmount, 0);
        }
        reserveAmount = _bc.sell(tokenAmount, 0);

        console2.log("-- after --");
        logState(_bc);
        logDeviation(_bc);

        assertApproxEqAbs(initialTokenAmount, tokenAmount, _maxTokenDeviation, "Too much token deviation");
        assertApproxEqAbs(initialReserveAmount, reserveAmount, _maxReserveDeviation, "Too much reserve deviation");
        assertTrue(_bc.checkCurrentDeviation(_rrDeviation), "Too much reserve ratio deviation");
    }

    function _testSlippage(IBondingCurve _bc, uint256 _minTokenAmount, uint256 _minReserveAmount) internal {
        uint256 initialReserveAmount = 500 ether;
        // Reverts with a huge min number
        vm.expectRevert("Min amount not reached");
        _bc.buy(initialReserveAmount, type(uint256).max);

        // Buy reverts with just 1 wei more
        vm.expectRevert("Min amount not reached");
        _bc.buy(initialReserveAmount, _minTokenAmount + 1);

        // Buy works with the exact amount
        uint256 tokenAmount = _bc.buy(initialReserveAmount, _minTokenAmount);
        assertEq(tokenAmount, _minTokenAmount);

        // Sell reverts with a huge min number
        vm.expectRevert("Min amount not reached");
        _bc.sell(tokenAmount, type(uint256).max);

        // Sell reverts with just 1 wei more
        vm.expectRevert("Min amount not reached");
        _bc.sell(tokenAmount, _minReserveAmount + 1);

        // Sell works with the exact amount
        uint256 reserveAmount = _bc.sell(tokenAmount, _minReserveAmount);
        assertEq(reserveAmount, _minReserveAmount);
    }

    function _testOptimistic(IBondingCurve _bc, uint256 _tokenAmount, uint256 _reserveAmount) internal {
        uint256 initialReserveAmount = 500 ether;

        _bc.optimisticBuy(initialReserveAmount, _tokenAmount);
        assertTrue(_bc.checkCurrentDeviation());

        _bc.optimisticSell(_tokenAmount, _reserveAmount);
        assertTrue(_bc.checkCurrentDeviation());
    }

    function _testValidate(IBondingCurve _bc, uint256 _tokenAmount, uint256 _reserveAmount) internal {
        uint256 initialReserveAmount = 500 ether;

        bool result = _bc.validateBuy(initialReserveAmount, _tokenAmount);
        assertTrue(result, "Validate Buy failed");

        uint256 tokenAmount = _bc.buy(initialReserveAmount, _tokenAmount);
        assertEq(tokenAmount, _tokenAmount);
        assertTrue(_bc.checkCurrentDeviation());

        result = _bc.validateSell(tokenAmount, _reserveAmount);
        assertTrue(result, "Validate Sell failed");

        uint256 reserveAmount = _bc.sell(tokenAmount, _reserveAmount);
        assertEq(reserveAmount, _reserveAmount);
        assertTrue(_bc.checkCurrentDeviation());
    }

    function _testFuzzBuy(IBondingCurve _bc, uint256 _x) internal {
        _bc.buy(_x, 0);

        assertTrue(_bc.checkCurrentDeviation(), "Too much reserve ratio deviation");
    }

    function _testFuzzSell(IBondingCurve _bc, uint256 _x) internal {
        _bc.sell(_x, 0);

        assertTrue(_bc.checkCurrentDeviation(), "Too much reserve ratio deviation");
    }

    // -- ABDK --

    function testABDKSimple() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testSimple(abdkBondingCurve, 10000, 1e5, 1e7, 100);
    }

    function testABDKSlippage() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testSlippage(abdkBondingCurve, 7890150936205566000, 499999999999999927854);
    }

    function testABDKOptimistic() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testOptimistic(abdkBondingCurve, 7890150936205566000, 499999999999999927854);
    }

    function testABDKValidate() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testValidate(abdkBondingCurve, 7890150936205566000, 499999999999999927854);
    }

    function testABDKFuzzBuy(uint256 _initialSupply, uint256 _x) public {
        // TODO: what is the min?
        //_initialSupply = bound(_initialSupply, 1, 1e6 ether);
        _initialSupply = bound(_initialSupply, 0.0001 ether, 1e6 ether);
        _x = bound(_x, 1, 1e6 ether);

        IBondingCurve abdkBondingCurve = _setUpABDK(_initialSupply);

        _testFuzzBuy(abdkBondingCurve, _x);
    }

    function testABDKFuzzSell(uint256 _initialSupply, uint256 _x) public {
        // TODO: min/max values
        //_initialSupply = bound(_initialSupply, 1, 1e6 ether);
        _initialSupply = bound(_initialSupply, 0.0001 ether, 1e6 ether);
        //_x = bound(_x, 1, _initialSupply);
        _x = bound(_x, 1, _initialSupply * 99999 / 100000);

        IBondingCurve abdkBondingCurve = _setUpABDK(_initialSupply);

        _testFuzzSell(abdkBondingCurve, _x);
    }

    // -- PRB --

    function testPRBSimple() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testSimple(prbBondingCurve, 10000, 1e9, 1e12, 1e6);
    }

    function testPRBSlippage() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testSlippage(prbBondingCurve, 7890150936205559000, 499999999999998773590);
    }

    function testPRBOptimistic() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testOptimistic(prbBondingCurve, 7890150936205559000, 499999999999998773590);
    }

    function testPRBValidate() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testValidate(prbBondingCurve, 7890150936205559000, 499999999999998773590);
    }

    function testPRBFuzz_Buy(uint256 _initialSupply, uint256 _x) public {
        // TODO: what is the min?
        //_initialSupply = bound(_initialSupply, 1, 1e6 ether);
        _initialSupply = bound(_initialSupply, 0.0001 ether, 1e6 ether);
        _x = bound(_x, 1, 1e6 ether);

        IBondingCurve prbBondingCurve = _setUpPRB(_initialSupply);

        _testFuzzBuy(prbBondingCurve, _x);
    }

    function testPRBFuzzSell(uint256 _initialSupply, uint256 _x) public {
        // TODO: min/max values
        //_initialSupply = bound(_initialSupply, 1, 1e6 ether);
        _initialSupply = bound(_initialSupply, 0.0001 ether, 1e6 ether);
        //_x = bound(_x, 1, _initialSupply);
        _x = bound(_x, 1, _initialSupply * 99999 / 100000);

        IBondingCurve prbBondingCurve = _setUpPRB(_initialSupply);

        _testFuzzSell(prbBondingCurve, _x);
    }
}
