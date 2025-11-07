pragma solidity ^0.8.24;

import {InvariantsBaseTest} from "./TestContracts/InvariantsBaseTest.t.sol";
import {console2} from "forge-std/Test.sol";

contract InvariantsPlayground is InvariantsBaseTest {
    function testInvariantReplay1() public {
        // Bonding curve balances
        // reserve = 2_500.000000221292925 ether, token = 3_750 ether
        // Current price = 1.00000000008851717 ether
        // Floor: reserve = 883.88347656142327 ether, token = 1_875 ether
        // Floor price = 0.707106781249138616 ether
        // Handler balances
        // reserve = 1_000_000_000_000 ether, token = 1_875 ether
        handler.buy(19_428_774_437.407119977249481052 ether); // -> 147_052_800.326392061201536915 ether, 73_563.181754073067134335 ether

        // Bonding curve balances
        // reserve = 19_428_776_937.407120198542406052 ether, token = 147_130_113.50814613426867125 ether
        // Current price = 198.077502363220252062 ether
        // Floor: reserve = 883.88347656142327 ether, token = 1_875 ether
        // Floor price = 0.707106781249138616 ether
        // Handler balances
        // reserve = 980_571_225_562.592880022750518948 ether, token = 147_054_675.326392061201536915 ether
        handler.buyFloorSellAndBurn(194287769375);
    }

    function testInvariantReplay2() public {
        handler.buyFloorSellAndBurn(9_544_810_980.229015165986948645 ether);
    }
}
