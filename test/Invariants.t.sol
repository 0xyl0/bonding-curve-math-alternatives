pragma solidity ^0.8.24;

import {InvariantsBaseTest} from "./TestContracts/InvariantsBaseTest.t.sol";

contract Invariants is InvariantsBaseTest {
    function invariant_ReserveRatio() external view {
        assertTrue(bondingCurve.checkCurrentDeviation(), "Too much reserve ratio deviation");
    }

    function invariant_TokenBalances() external view {
        assertEq(
            bondingCurve.totalSupply(), bondingCurve.virtualSupply() - bondingCurve.floorSupply(), "Wrong token supply"
        );
        assertEq(bondingCurve.virtualSupply(), handler.virtualSupply(), "Wrong virtual supply");
        assertEq(
            bondingCurve.totalSupply(),
            bondingCurve.balanceOf(address(handler)) + bondingCurve.balanceOf(feeRecipient),
            "Wrong total balances"
        );
        // Eventuall this will became Gt
        assertEq(
            reserveToken.balanceOf(address(bondingCurve)),
            bondingCurve.virtualBalance() - bondingCurve.floorBalance(),
            "Wrong reserve balance"
        );
        assertEq(
            reserveToken.balanceOf(address(burnRecipient)), bondingCurve.floorBalance(), "Wrong reserve floor balance"
        );
    }
}
