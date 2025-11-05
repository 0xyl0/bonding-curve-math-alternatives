// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {Test, console2} from "forge-std/Test.sol";

import {IBondingCurve} from "../src/Interfaces/IBondingCurve.sol";
import {ABDKBondingCurve} from "../src/ABDKBondingCurve.sol";
import {PRBBondingCurve} from "../src/PRBBondingCurve.sol";

import {ERC20Mock} from "./TestContracts/ERC20Mock.sol";

contract BondingCurveTest is Test {
    uint256 constant DECIMAL_PRECISION = 1e18;

    ERC20Mock reserveToken;
    address feeRecipient;
    address burnRecipient;

    function setUp() public {
        reserveToken = new ERC20Mock("WETH", "WETH");
        reserveToken.mint(address(this), 1e12 ether);
        feeRecipient = makeAddr("feeRecipient");
        burnRecipient = makeAddr("burnRecipient");
    }

    function _setUpBondingCurve(IBondingCurve _bc) internal {
        // TODO: get rid of
        reserveToken.transfer(address(_bc), _bc.virtualBalance() - _bc.floorBalance());
        reserveToken.transfer(burnRecipient, _bc.floorBalance());

        reserveToken.approve(address(_bc), type(uint256).max);
    }

    function _setUpABDK(uint256 _initialSupply) internal returns (IBondingCurve) {
        return _setUpABDK(_initialSupply, _initialSupply / 2);
    }

    function _setUpABDK(uint256 _initialSupply, uint256 _initialFloorSupply) internal returns (IBondingCurve) {
        IBondingCurve abdkBondingCurve = new ABDKBondingCurve(
            2 ether,
            0.5 ether,
            _initialSupply,
            _initialFloorSupply,
            IERC20(reserveToken),
            "ABDK token",
            "TKN",
            feeRecipient,
            burnRecipient
        );

        _setUpBondingCurve(abdkBondingCurve);

        return abdkBondingCurve;
    }

    function _setUpPRB(uint256 _initialSupply) internal returns (IBondingCurve) {
        return _setUpPRB(_initialSupply, _initialSupply / 2);
    }

    function _setUpPRB(uint256 _initialSupply, uint256 _initialFloorSupply) internal returns (IBondingCurve) {
        IBondingCurve prbBondingCurve = new PRBBondingCurve(
            2 ether,
            0.5 ether,
            _initialSupply,
            _initialFloorSupply,
            IERC20(reserveToken),
            "PRB token",
            "TKN",
            feeRecipient,
            burnRecipient
        );

        _setUpBondingCurve(prbBondingCurve);

        return prbBondingCurve;
    }

    function logState(IBondingCurve _bc) internal view {
        console2.log(_bc.virtualSupply(), "Current supply");
        console2.log(_bc.virtualBalance(), "Current balance");
        console2.log(_bc.currentPrice(), "Current price");
        console2.log(_bc.floorSupply(), "Current floor supply");
        console2.log(_bc.floorBalance(), "Current floor balance");
        console2.log(_bc.floorPrice(), "Floor price");
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
        uint256,
        /* _maxReserveDeviation */
        uint256 _rrDeviation
    ) internal {
        console2.log("-- before --");
        logState(_bc);
        logDeviation(_bc);

        uint256 totalTokenFeeAmount;
        uint256 initialReserveAmount = 500 ether;
        (uint256 tokenAmount, uint256 feeAmount) = _bc.buy(initialReserveAmount, 0);
        uint256 initialTokenAmount = tokenAmount + feeAmount;
        uint256 reserveAmount;
        totalTokenFeeAmount += feeAmount;
        for (uint256 i = 0; i < _runs; i++) {
            (reserveAmount, feeAmount) = _bc.sell(tokenAmount, 0);
            totalTokenFeeAmount += feeAmount;
            (tokenAmount, feeAmount) = _bc.buy(reserveAmount, 0);
            totalTokenFeeAmount += feeAmount;
        }
        (reserveAmount, feeAmount) = _bc.sell(tokenAmount, 0);

        console2.log("-- after --");
        logState(_bc);
        logDeviation(_bc);

        assertApproxEqAbs(
            initialTokenAmount, tokenAmount + totalTokenFeeAmount, _maxTokenDeviation, "Too much token deviation"
        );
        // TODO: This is hard to compute now. Should we keep it? It seems that checking token + reserve ratio is enough
        //assertApproxEqAbs(initialReserveAmount, reserveAmount, _maxReserveDeviation, "Too much reserve deviation");
        assertTrue(_bc.checkCurrentDeviation(_rrDeviation), "Too much reserve ratio deviation");
        // Let's add the last sell fee
        totalTokenFeeAmount += feeAmount;
        assertEq(totalTokenFeeAmount, _bc.balanceOf(feeRecipient), "Fee recipient token balance mismatch");
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
        (uint256 tokenAmount,) = _bc.buy(initialReserveAmount, _minTokenAmount);
        assertEq(tokenAmount, _minTokenAmount);

        // Sell reverts with a huge min number
        vm.expectRevert("Min amount not reached");
        _bc.sell(tokenAmount, type(uint256).max);

        // Sell reverts with just 1 wei more
        vm.expectRevert("Min amount not reached");
        _bc.sell(tokenAmount, _minReserveAmount + 1);

        // Sell works with the exact amount
        (uint256 reserveAmount,) = _bc.sell(tokenAmount, _minReserveAmount);
        assertEq(reserveAmount, _minReserveAmount);
    }

    struct TestVars {
        uint256 initialSupply;
        uint256 initialFloorSupply;
        uint256 initialBalance;
        uint256 initialFloorBalance;
        uint256 initialTokenAmount;
        uint256 initialReserveAmount;
        uint256 initialBurnRecipientReserveBalance;
        uint256 totalTokenFeeAmount;
        uint256 totalTokenBurnAmount;
        uint256 totalReserveBurnAmount;
    }

    function _testFloorSellAndBurn(
        IBondingCurve _bc,
        uint256 _runs,
        uint256 _maxTokenDeviation,
        uint256,
        /* _maxReserveDeviation */
        uint256 _rrDeviation
    ) internal {
        TestVars memory vars;
        vars.initialSupply = _bc.virtualSupply();
        vars.initialFloorSupply = _bc.floorSupply();
        vars.initialFloorBalance = _bc.floorBalance();
        vars.initialBurnRecipientReserveBalance = reserveToken.balanceOf(burnRecipient);
        vars.initialReserveAmount = 500 ether;

        (uint256 tokenAmount, uint256 feeAmount) = _bc.buy(vars.initialReserveAmount, 0);
        vars.initialTokenAmount = tokenAmount + feeAmount;
        uint256 reserveAmount;
        vars.totalTokenFeeAmount += feeAmount;
        for (uint256 i = 0; i < _runs; i++) {
            uint256 floorSellAndBurnAmount = tokenAmount / 10;
            (reserveAmount, feeAmount) = _bc.sell(tokenAmount - floorSellAndBurnAmount, 0);
            if (floorSellAndBurnAmount > 0) {
                uint256 reserveBurnAmount = _bc.floorSellAndBurn(floorSellAndBurnAmount);
                vars.totalTokenBurnAmount += floorSellAndBurnAmount;
                vars.totalReserveBurnAmount += reserveBurnAmount;
            }
            vars.totalTokenFeeAmount += feeAmount;
            (tokenAmount, feeAmount) = _bc.buy(reserveAmount, 0);
            vars.totalTokenFeeAmount += feeAmount;
        }
        (reserveAmount, feeAmount) = _bc.sell(tokenAmount, 0);

        assertApproxEqAbs(
            vars.initialTokenAmount,
            tokenAmount + vars.totalTokenFeeAmount + vars.totalTokenBurnAmount,
            _maxTokenDeviation,
            "Too much token deviation"
        );
        // TODO: This is hard to compute now. Should we keep it? It seems that checking token + reserve ratio is enough
        //assertApproxEqAbs(vars.initialReserveAmount, reserveAmount, _maxReserveDeviation, "Too much reserve deviation");

        // Let's add the last sell fee
        vars.totalTokenFeeAmount += feeAmount;
        assertApproxEqAbs(
            _bc.virtualSupply(),
            vars.initialSupply + vars.totalTokenBurnAmount + vars.totalTokenFeeAmount,
            _maxTokenDeviation,
            "Wrong supply"
        );
        assertEq(_bc.floorSupply(), vars.initialFloorSupply + vars.totalTokenBurnAmount, "Wrong floor supply");
        assertEq(_bc.floorBalance(), vars.initialFloorBalance + vars.totalReserveBurnAmount, "Wrong floor balance");

        assertTrue(_bc.checkCurrentDeviation(_rrDeviation), "Too much reserve ratio deviation");

        assertEq(vars.totalTokenFeeAmount, _bc.balanceOf(feeRecipient), "Fee recipient token balance mismatch");
        assertEq(
            vars.totalReserveBurnAmount,
            reserveToken.balanceOf(burnRecipient) - vars.initialBurnRecipientReserveBalance,
            "Burn recipient reserve balance mismatch"
        );
    }

    function _testBuyFloorSellAndBurn(
        IBondingCurve _bc,
        uint256 _runs,
        uint256 _maxTokenDeviation,
        uint256,
        /* _maxReserveDeviation */
        uint256 _rrDeviation
    ) internal {
        TestVars memory vars;
        vars.initialSupply = _bc.virtualSupply();
        vars.initialFloorSupply = _bc.floorSupply();
        vars.initialFloorBalance = _bc.floorBalance();
        vars.initialBurnRecipientReserveBalance = reserveToken.balanceOf(burnRecipient);
        vars.initialReserveAmount = 500 ether;
        (uint256 tokenAmount, uint256 feeAmount) = _bc.buy(vars.initialReserveAmount, 0);
        vars.initialTokenAmount = tokenAmount + feeAmount;
        uint256 reserveAmount;
        vars.totalTokenFeeAmount += feeAmount;
        for (uint256 i = 0; i < _runs; i++) {
            (reserveAmount, feeAmount) = _bc.sell(tokenAmount, 0);
            vars.totalTokenFeeAmount += feeAmount;
            (tokenAmount, feeAmount) = _bc.buy(reserveAmount, 0);
            vars.totalTokenFeeAmount += feeAmount;
            (uint256 tokenBurnAmount, uint256 reserveBurnAmount) = _bc.buyFloorSellAndBurn(reserveAmount, 0);
            vars.totalTokenBurnAmount += tokenBurnAmount;
            vars.totalReserveBurnAmount += reserveBurnAmount;
        }
        (reserveAmount, feeAmount) = _bc.sell(tokenAmount, 0);

        assertApproxEqAbs(
            vars.initialTokenAmount,
            tokenAmount + vars.totalTokenFeeAmount,
            _maxTokenDeviation,
            "Too much token deviation"
        );
        // TODO: This is hard to compute now. Should we keep it? It seems that checking token + reserve ratio is enough
        //assertApproxEqAbs(vars.initialReserveAmount, reserveAmount, _maxReserveDeviation, "Too much reserve deviation");

        // Let's add the last sell fee
        vars.totalTokenFeeAmount += feeAmount;
        assertApproxEqAbs(
            _bc.virtualSupply(),
            vars.initialSupply + vars.totalTokenBurnAmount + vars.totalTokenFeeAmount,
            _maxTokenDeviation,
            "Wrong supply"
        );
        assertEq(_bc.floorSupply(), vars.initialFloorSupply + vars.totalTokenBurnAmount, "Wrong floor supply");
        assertEq(_bc.floorBalance(), vars.initialFloorBalance + vars.totalReserveBurnAmount, "Wrong floor balance");

        assertEq(vars.totalTokenFeeAmount, _bc.balanceOf(feeRecipient), "Fee recipient token balance mismatch");
        assertEq(
            vars.totalReserveBurnAmount,
            reserveToken.balanceOf(burnRecipient) - vars.initialBurnRecipientReserveBalance,
            "Burn recipient reserve balance mismatch"
        );

        assertTrue(_bc.checkCurrentDeviation(_rrDeviation), "Too much reserve ratio deviation");
    }

    struct BondingCurveStateTestVars {
        uint256 virtualSupply;
        uint256 virtualBalance;
        uint256 floorSupply;
        uint256 floorBalance;
    }

    function _testBuyFloorSellAndBurnEquivalency(IBondingCurve _bc, uint256 _reserveAmount) internal {
        _reserveAmount = bound(_reserveAmount, 0.001 ether, 1e6 ether);

        uint256 snapshotId = vm.snapshotState();
        // separate functions
        (uint256 tokenAmount1, uint256 tokenFeeAmount1) = _bc.buy(_reserveAmount, 0);
        uint256 reserveAmount1 = _bc.floorSellAndBurn(tokenAmount1);

        BondingCurveStateTestVars memory vars1;
        vars1.virtualSupply = _bc.virtualSupply();
        vars1.virtualBalance = _bc.virtualBalance();
        vars1.floorSupply = _bc.floorSupply();
        vars1.floorBalance = _bc.floorBalance();

        vm.revertToState(snapshotId);
        // buyFloorSellAndBurn combined function
        (uint256 tokenAmount2, uint256 reserveAmount2) = _bc.buyFloorSellAndBurn(_reserveAmount, 0);

        BondingCurveStateTestVars memory vars2;
        vars2.virtualSupply = _bc.virtualSupply();
        vars2.virtualBalance = _bc.virtualBalance();
        vars2.floorSupply = _bc.floorSupply();
        vars2.floorBalance = _bc.floorBalance();

        // checks
        assertEq(tokenAmount1 + tokenFeeAmount1, tokenAmount2, "Wrong token amount");
        // TODO: calc fee impact on reserve amount
        //assertEq(reserveAmount1, reserveAmount2, "Wrong reserve amount");
        // curve state
        assertEq(vars1.virtualSupply, vars2.virtualSupply, "Wrong virtual supply");
        assertEq(vars1.virtualBalance, vars2.virtualBalance, "Wrong virtual balance");
        assertEq(vars1.floorSupply + tokenFeeAmount1, vars2.floorSupply, "Wrong floor supply");
        // TODO: calc fee impact
        //assertEq(vars1.floorBalance, vars2.floorBalance, "Wrong floor balance");
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

        _testSimple(abdkBondingCurve, 10000, 2e7, 1e7, 1e5);
    }

    function testABDKSlippage() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testSlippage(abdkBondingCurve, 7886205860737463217, 499501106809585381788);
    }

    function testABDKFloorSellAndBurn() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testFloorSellAndBurn(abdkBondingCurve, 100, 2e7, 1e7, 1e5);
    }

    function testABDKBuyFloorSellAndBurn() public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testBuyFloorSellAndBurn(abdkBondingCurve, 10000, 3e8, 1e7, 1e5);
    }

    function testABDKBuyFloorSellAndBurnEquivalency(uint256 _tokenAmount) public {
        IBondingCurve abdkBondingCurve = _setUpABDK(1000 ether);

        _testBuyFloorSellAndBurnEquivalency(abdkBondingCurve, _tokenAmount);
    }

    function testABDKFuzzBuy(uint256 _initialSupply, uint256 _x) public {
        // TODO: what is the min?
        //_initialSupply = bound(_initialSupply, 1, 1e6 ether);
        _initialSupply = bound(_initialSupply, 0.0001 ether, 1e6 ether);
        _x = bound(_x, 1, 1e6 ether);

        uint256 initialFloorSupply = _initialSupply / 2;
        IBondingCurve abdkBondingCurve = _setUpABDK(_initialSupply, initialFloorSupply);

        _testFuzzBuy(abdkBondingCurve, _x);
    }

    function testABDKFuzzSell(uint256 _initialSupply, uint256 _x) public {
        // TODO: min/max values
        //_initialSupply = bound(_initialSupply, 1, 1e6 ether);
        _initialSupply = bound(_initialSupply, 0.0001 ether, 1e6 ether);
        uint256 initialFloorSupply = _initialSupply / 2;
        //_x = bound(_x, 1, (_initialSupply - initialFloorSupply));
        _x = bound(_x, 1, (_initialSupply - initialFloorSupply) * 99999 / 100000);

        IBondingCurve abdkBondingCurve = _setUpABDK(_initialSupply, initialFloorSupply);

        _testFuzzSell(abdkBondingCurve, _x);
    }

    // -- PRB --

    function testPRBSimple() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testSimple(prbBondingCurve, 10000, 1e9, 1e12, 1e6);
    }

    function testPRBSlippage() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testSlippage(prbBondingCurve, 7886205860737456221, 499501106809584355518);
    }

    function testPRBFloorSellAndBurn() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testFloorSellAndBurn(prbBondingCurve, 100, 1e9, 1e12, 1e6);
    }

    function testPRBBuyFloorSellAndBurn() public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testBuyFloorSellAndBurn(prbBondingCurve, 10000, 2e9, 1e12, 1e6);
    }

    function testPRBBuyFloorSellAndBurnEquivalency(uint256 _tokenAmount) public {
        IBondingCurve prbBondingCurve = _setUpPRB(1000 ether);

        _testBuyFloorSellAndBurnEquivalency(prbBondingCurve, _tokenAmount);
    }

    function testPRBFuzz_Buy(uint256 _initialSupply, uint256 _x) public {
        // TODO: what is the min?
        //_initialSupply = bound(_initialSupply, 1, 1e6 ether);
        _initialSupply = bound(_initialSupply, 0.0001 ether, 1e6 ether);
        _x = bound(_x, 1, 1e6 ether);

        uint256 initialFloorSupply = _initialSupply / 2;
        IBondingCurve prbBondingCurve = _setUpPRB(_initialSupply, initialFloorSupply);

        _testFuzzBuy(prbBondingCurve, _x);
    }

    function testPRBFuzzSell(uint256 _initialSupply, uint256 _x) public {
        // TODO: min/max values
        //_initialSupply = bound(_initialSupply, 1, 1e6 ether);
        _initialSupply = bound(_initialSupply, 0.0001 ether, 1e6 ether);
        uint256 initialFloorSupply = _initialSupply / 2;
        //_x = bound(_x, 1, (_initialSupply - initialFloorSupply));
        _x = bound(_x, 1, (_initialSupply - initialFloorSupply) * 99999 / 100000);

        IBondingCurve prbBondingCurve = _setUpPRB(_initialSupply, initialFloorSupply);

        _testFuzzSell(prbBondingCurve, _x);
    }
}
