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
            (bondingCurve.currentBalance()).decimal(),
            ", token = ",
            (bondingCurve.currentSupply()).decimal()
        );
        info("Current price = ", (bondingCurve.currentPrice()).decimal());
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
        vm.assume(_reserveAmount > bondingCurve.currentBalance() * 10 / DECIMAL_PRECISION);
        vm.assume(_reserveAmount <= reserveToken.balanceOf(address(this)));

        _logState();

        //uint256 tokenAmount = bondingCurve.buy(_reserveAmount);
        try bondingCurve.buy(_reserveAmount) returns (uint256 tokenAmount) {
            logCallWithReturn("buy", _reserveAmount.decimal(), tokenAmount.decimal());
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
        // _tokenAmount = bound(_tokenAmount, 1, bondingCurve.currentSupply() * 99999 / 100000);
        // vm.assume(_tokenAmount > 0);
        // To avoid sales that return zero reserve tokens
        vm.assume(_tokenAmount > bondingCurve.currentSupply() * 10 / DECIMAL_PRECISION);
        vm.assume(_tokenAmount <= bondingCurve.currentSupply() * 99999 / 100000);
        vm.assume(_tokenAmount <= bondingCurve.balanceOf(address(this)));

        _logState();

        //uint256 reserveAmount = bondingCurve.sell(_tokenAmount);
        try bondingCurve.sell(_tokenAmount) returns (uint256 reserveAmount) {
            logCallWithReturn("sell", _tokenAmount.decimal(), reserveAmount.decimal());
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
}
