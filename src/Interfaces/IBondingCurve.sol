pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC5267.sol";

interface IBondingCurve is IERC20Metadata, IERC20Permit, IERC5267 {
    function FEE_PERCENTAGE() external view returns (uint256);
    function FEE_RECIPIENT() external view returns (address);
    function BURN_RECIPIENT() external view returns (address);

    function reserveToken() external view returns (IERC20);
    function virtualSupply() external view returns (uint256);
    function virtualBalance() external view returns (uint256);
    function floorSupply() external view returns (uint256);
    function floorBalance() external view returns (uint256);

    function buy(uint256 _reserveAmount, uint256 _minTokenAmount)
        external
        returns (uint256 tokenAmount, uint256 tokenFeeAmount);
    function sell(uint256 _tokenAmount, uint256 _minReserveAmount)
        external
        returns (uint256 reserveAmount, uint256 tokenFeeAmount);
    function floorSellAndBurn(uint256 _tokenAmount) external returns (uint256 reserveAmount);
    function buyFloorSellAndBurn(uint256 _reserveAmount, uint256 _minTokenAmount)
        external
        returns (uint256 tokenAmount, uint256 sellReserveAmount);

    function getBuyAmount(uint256 _reserveAmount) external view returns (uint256 tokenAmount);
    function getBuyAmount(uint256 _reserveAmount, uint256 _supply, uint256 _balance)
        external
        view
        returns (uint256 tokenAmount);
    function getSellAmount(uint256 _tokenAmount) external view returns (uint256 reserveAmount);
    function getSellAmount(uint256 _tokenAmount, uint256 _supply, uint256 _balance)
        external
        view
        returns (uint256 reserveAmount);
    function getSellAmountFromFloorUpwards(uint256 _tokenAmount) external view returns (uint256 reserveAmount);
    function getSellAmountFromFloorUpwards(uint256 _tokenAmount, uint256 _supply, uint256 _balance)
        external
        view
        returns (uint256 reserveAmount);

    function getPrice(uint256 _supply) external view returns (uint256);
    function currentPrice() external view returns (uint256);
    function floorPrice() external view returns (uint256);

    function getTokenBuyFee(uint256 _tokenAmount) external view returns (uint256 tokenFeeAmount);
    function getTokenSellFee(uint256 _tokenAmount) external view returns (uint256 tokenFeeAmount);
    function getTokenAmountMinusFee(uint256 _tokenAmount) external view returns (uint256 tokenNetAmount);

    function reserveRatioDeviation() external view returns (int256);
    function checkCurrentDeviation() external view returns (bool);
    function checkCurrentDeviation(uint256 _errorThreshold) external view returns (bool);
}
