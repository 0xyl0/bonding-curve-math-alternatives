pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {Test, console2} from "forge-std/Test.sol";

import {IBondingCurve} from "src/Interfaces/IBondingCurve.sol";
import {ABDKBondingCurve} from "src/ABDKBondingCurve.sol";

import {ERC20Mock} from "./TestContracts/ERC20Mock.sol";
import {InvariantsTestHandler} from "./TestContracts/InvariantsTestHandler.t.sol";

contract Invariants is Test {
    uint256 constant ALPHA = 0.01632993162 ether;
    uint256 constant BETA = 0.5 ether;
    uint256 constant INITIAL_SUPPLY = 3750 ether;
    uint256 constant INITIAL_FLOOR_SUPPLY = INITIAL_SUPPLY / 2;

    ERC20Mock reserveToken;
    address feeRecipient;
    address burnRecipient;
    IBondingCurve bondingCurve;
    InvariantsTestHandler handler;

    function setUp() public {
        reserveToken = new ERC20Mock("WETH", "WETH");
        feeRecipient = makeAddr("feeRecipient");
        burnRecipient = makeAddr("burnRecipient");

        bondingCurve = new ABDKBondingCurve(
            ALPHA,
            BETA,
            INITIAL_SUPPLY,
            INITIAL_FLOOR_SUPPLY,
            IERC20(reserveToken),
            "ABDK token",
            "TKN",
            feeRecipient,
            burnRecipient
        );
        // TODO: get rid of
        reserveToken.mint(address(bondingCurve), bondingCurve.virtualBalance() - bondingCurve.floorBalance());
        reserveToken.mint(burnRecipient, bondingCurve.floorBalance());

        handler = new InvariantsTestHandler(bondingCurve);
        vm.label(address(handler), "handler");
        targetContract(address(handler));

        // Mint some reserve tokens so that handler can buy
        reserveToken.mint(address(handler), 1e12 ether);
        // Make the initial supply available to the handler contract, so it can be sold too
        bondingCurve.transfer(address(handler), bondingCurve.balanceOf(address(this)));
    }

    function invariant_ReserveRatio() external view {
        assertTrue(bondingCurve.checkCurrentDeviation(), "Too much reserve ratio deviation");
    }

    function invariant_TokenBalances() external view {
        //assertEq(bondingCurve.totalSupply(), bondingCurve.virtualSupply() - bondingCurve.floorSupply(), "Wrong token supply");
        assertApproxEqAbs(
            bondingCurve.totalSupply(),
            bondingCurve.virtualSupply() - bondingCurve.floorSupply(),
            1e5,
            "Wrong token supply"
        );
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
