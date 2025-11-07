pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {IBondingCurve} from "src/Interfaces/IBondingCurve.sol";
import {ABDKBondingCurve} from "src/ABDKBondingCurve.sol";

import {ERC20Mock} from "./ERC20Mock.sol";
import {InvariantsTestHandler} from "./InvariantsTestHandler.t.sol";

contract InvariantsBaseTest is Test {
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
}
