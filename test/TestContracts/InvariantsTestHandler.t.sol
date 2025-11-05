pragma solidity 0.8.24;

import {console2} from "forge-std/Test.sol";

import {IBondingCurve} from "src/Interfaces/IBondingCurve.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {StringFormatting} from "../Utils/StringFormatting.sol";
import {BaseHandler} from "./BaseHandler.sol";

contract InvariantsTestHandler is BaseHandler {
    using StringFormatting for uint256;
    uint256 constant DECIMAL_PRECISION = 1e18;

    IBondingCurve bondingCurve;
    ERC20Mock reserveToken;

    constructor(IBondingCurve _bc) {
        bondingCurve = _bc;
        reserveToken = ERC20Mock(address(_bc.reserveToken()));
        reserveToken.approve(address(_bc), type(uint256).max);
    }

    function _logState() internal view {
        info("Bonding curve balances");
        info(
            "reserve = ",
            (bondingCurve.virtualBalance()).decimal(),
            ", token = ",
            (bondingCurve.virtualSupply()).decimal()
        );
        info("Current price = ", (bondingCurve.currentPrice()).decimal());
        info(
            "Floor: reserve = ",
            (bondingCurve.floorBalance()).decimal(),
            ", token = ",
            (bondingCurve.floorSupply()).decimal()
        );
        info("Floor price = ", (bondingCurve.floorPrice()).decimal());
        info("Handler balances");
        info(
            "reserve = ",
            (reserveToken.balanceOf(address(this))).decimal(),
            ", token = ",
            (bondingCurve.balanceOf(address(this))).decimal()
        );
    }

    function buy(uint256 _reserveAmount) external {
        // _reserveAmount = vm.bound(_reserveAmount, 1, 1e6 ether);
        // vm.assume(_reserveAmount > 0);
        // To avoid purchases that return zero tokens
        vm.assume(_reserveAmount > bondingCurve.virtualBalance() * 10 / DECIMAL_PRECISION);
        vm.assume(_reserveAmount <= reserveToken.balanceOf(address(this)));

        _logState();

        //uint256 tokenAmount = bondingCurve.buy(_reserveAmount, 0);
        try bondingCurve.buy(_reserveAmount, 0) returns (uint256 tokenNetAmount, uint256 tokenFeeAmount) {
            logCallWithTwoReturns("buy", _reserveAmount.decimal(), tokenNetAmount.decimal(), tokenFeeAmount.decimal());
            //assertGt(tokenAmount, 0, "Should get tokens on buy");
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            logCall("buy", _reserveAmount.decimal());
            info(reason);
            revert();
        } catch (bytes memory reason) {
            // catch failing assert()
            logCall("buy", _reserveAmount.decimal());
            console2.logBytes(reason);
            revert();
        }
    }

    function sell(uint256 _tokenAmount) external {
        // _tokenAmount = bound(_tokenAmount, 1, bondingCurve.virtualSupply() * 99999 / 100000);
        // vm.assume(_tokenAmount > 0);
        // To avoid sales that return zero reserve tokens
        vm.assume(_tokenAmount > bondingCurve.virtualSupply() * 10 / DECIMAL_PRECISION);
        vm.assume(_tokenAmount <= bondingCurve.virtualSupply() * 99999 / 100000);
        vm.assume(_tokenAmount <= bondingCurve.balanceOf(address(this)));

        _logState();

        //uint256 reserveAmount = bondingCurve.sell(_tokenAmount, 0);
        try bondingCurve.sell(_tokenAmount, 0) returns (uint256 reserveAmount, uint256 tokenFeeAmount) {
            logCallWithTwoReturns("sell", _tokenAmount.decimal(), reserveAmount.decimal(), tokenFeeAmount.decimal());
            //assertGt(reserveAmount, 0, "Should get reserve tokens on sell");
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            logCall("sell", _tokenAmount.decimal());
            info(reason);
            revert();
        } catch (bytes memory reason) {
            // catch failing assert()
            logCall("sell", _tokenAmount.decimal());
            console2.logBytes(reason);
            revert();
        }
    }

    function floorSellAndBurn(uint256 _tokenAmount) external {
        // _tokenAmount = bound(_tokenAmount, 1, bondingCurve.virtualSupply() * 99999 / 100000);
        // vm.assume(_tokenAmount > 0);
        // To avoid sales that return zero reserve tokens
        vm.assume(_tokenAmount > bondingCurve.virtualSupply() * 10 / DECIMAL_PRECISION);
        vm.assume(_tokenAmount <= bondingCurve.virtualSupply() - bondingCurve.floorSupply()); // * 99999 / 100000);
        vm.assume(_tokenAmount <= bondingCurve.balanceOf(address(this)));

        _logState();

        try bondingCurve.floorSellAndBurn(_tokenAmount) returns (uint256 reserveAmount) {
            logCallWithReturn("floorSellAndBurn", _tokenAmount.decimal(), reserveAmount.decimal());
            //assertGt(tokenAmount, 0, "Should get tokens on buy");
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            logCall("floorSellAndBurn", _tokenAmount.decimal());
            info(reason);
            revert();
        } catch (bytes memory reason) {
            // catch failing assert()
            logCall("floorSellAndBurn", _tokenAmount.decimal());
            console2.logBytes(reason);
            revert();
        }
    }

    function buyFloorSellAndBurn(uint256 _reserveAmount) external {
        // To avoid purchases that return zero tokens
        vm.assume(_reserveAmount > bondingCurve.virtualBalance() * 10 / DECIMAL_PRECISION);
        vm.assume(_reserveAmount <= reserveToken.balanceOf(address(this)));

        _logState();

        try bondingCurve.buyFloorSellAndBurn(_reserveAmount, 0) returns (
            uint256 tokenAmount, uint256 sellReserveAmount
        ) {
            logCallWithTwoReturns(
                "buyFloorSellAndBurn", _reserveAmount.decimal(), tokenAmount.decimal(), sellReserveAmount.decimal()
            );
            //assertGt(tokenAmount, 0, "Should get tokens on buy");
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            logCall("buyFloorSellAndBurn", _reserveAmount.decimal());
            info(reason);
            revert();
        } catch (bytes memory reason) {
            // catch failing assert()
            logCall("buyFloorSellAndBurn", _reserveAmount.decimal());
            console2.logBytes(reason);
            revert();
        }
    }
}
