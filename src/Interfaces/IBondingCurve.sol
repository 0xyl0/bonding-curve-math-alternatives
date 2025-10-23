pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC5267.sol";

interface IBondingCurve is IERC20Metadata, IERC20Permit, IERC5267 {
    function reserveToken() external view returns (IERC20);
    function currentSupply() external view returns (uint256);
    function currentBalance() external view returns (uint256);

    function buy(uint256 _reserveAmount) external returns (uint256 tokenAmount);
    function sell(uint256 _tokenAmount) external returns (uint256 reserveAmount);

    function getPrice(uint256 _supply) external view returns (uint256);
    function currentPrice() external view returns (uint256);

    function validateBuy(uint256 _amount, uint256 _reserveAmount) external view returns (bool);
    function validateSell(uint256 _amount, uint256 _reserveAmount) external view returns (bool);
    function reserveRatioDeviation() external view returns (int256);
    function checkCurrentDeviation() external view returns (bool);
    function checkCurrentDeviation(uint256 _errorThreshold) external view returns (bool);
}
