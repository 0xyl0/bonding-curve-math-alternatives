pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {IBondingCurve} from "./Interfaces/IBondingCurve.sol";

import "forge-std/console2.sol";

// TODO: make sure rounding errors favour the system, not the user
// TODO: events

abstract contract BaseBondingCurve is IBondingCurve, ERC20Permit {
    uint256 public constant DECIMAL_PRECISION = 1e18;
    uint256 public constant ERROR_THRESHOLD = 1e12;
    uint256 public constant FEE_PERCENTAGE = 5e14; // 0.05%

    // The bonding curve is defined as: p = A * s^B
    uint256 public immutable A; // alpha (coefficient) in the bonding curve
    uint256 public immutable B; // beta (exponent) in the bonding curve

    IERC20 public immutable reserveToken;
    address public immutable FEE_RECIPIENT;
    address public immutable BURN_RECIPIENT;

    // The supply corresponding to the current state of the curve, i.e., the x axis of the current point
    // It's equal to the real total supply minus the floor supply
    //uint256 public virtualSupply;
    // The reserve balance corresponding to the current state of the curve, i.e., the y axis of the current point
    // It's equal to the real balance of this contract minus the floor balance
    uint256 public virtualBalance;
    // The supply corresponding to the current floor price point of the curve
    // It's equal to the total supply burnt through `buyFloorSellAndBurn` and `floorSellAndBurn`
    uint256 public floorSupply;
    // The reserve balance corresponding to the current floor price point of the curve
    // It's equal to the total reserve sent to `BURN_RECIPIENT`
    uint256 public floorBalance;

    constructor(
        uint256 _alpha,
        uint256 _beta,
        uint256 _supply,
        uint256 _floorSupply,
        IERC20 _reserveToken,
        string memory _name,
        string memory _symbol,
        address _feeRecipient,
        address _burnRecipient
    ) ERC20(_name, _symbol) ERC20Permit(_name) {
        require(_floorSupply <= _supply, "Floor cannot be above current state");

        A = _alpha;
        B = _beta;
        reserveToken = _reserveToken;
        FEE_RECIPIENT = _feeRecipient;
        BURN_RECIPIENT = _burnRecipient;

        // init pool
        //virtualSupply = _supply;
        floorSupply = _floorSupply;
        uint256 initialBalance = _supply * getPrice(_supply) / (B + DECIMAL_PRECISION);
        uint256 initialFloorBalance = _floorSupply * getPrice(_floorSupply) / (B + DECIMAL_PRECISION);
        assert(initialFloorBalance <= initialFloorBalance);
        virtualBalance = initialBalance;
        floorBalance = initialFloorBalance;

        // token operations
        _mint(msg.sender, _supply - _floorSupply);
        // TODO:
        //reserveToken.transferFrom(msg.sender, address(this), initialBalance - initialFloorBalance);
        //reserveToken.transferFrom(msg.sender, BURN_RECIPIENT, initialFloorBalance);
    }

    function buy(uint256 _reserveAmount, uint256 _minTokenAmount) external returns (uint256, uint256) {
        require(_reserveAmount > 0, "Zero amount");

        uint256 initialVirtualSupply = virtualSupply();
        uint256 initialVirtualBalance = virtualBalance;

        uint256 tokenAmount = _calcBuyAmount(_reserveAmount, initialVirtualSupply, initialVirtualBalance);
        uint256 tokenFeeAmount = getTokenBuyFee(tokenAmount);
        uint256 tokenNetAmount = tokenAmount - tokenFeeAmount;

        require(tokenNetAmount >= _minTokenAmount, "Min amount not reached");

        //virtualSupply = initialVirtualSupply + tokenAmount;
        virtualBalance = initialVirtualBalance + _reserveAmount;

        _mint(msg.sender, tokenNetAmount);
        _mint(FEE_RECIPIENT, tokenFeeAmount);
        reserveToken.transferFrom(msg.sender, address(this), _reserveAmount);

        return (tokenNetAmount, tokenFeeAmount);
    }

    function _calcBuyAmount(uint256 _reserveAmount, uint256 _supply, uint256 _balance) internal view returns (uint256) {
        require(_reserveAmount > 0, "Zero amount");

        //uint256 gasLeft = gasleft();
        uint256 tokenAmount = _supply
            * (pow(
                    DECIMAL_PRECISION + _reserveAmount * DECIMAL_PRECISION / _balance,
                    DECIMAL_PRECISION * DECIMAL_PRECISION / (B + DECIMAL_PRECISION)
                )
                - DECIMAL_PRECISION) / DECIMAL_PRECISION;
        //console2.log(gasLeft - gasleft(), "gas used by math");

        return tokenAmount;
    }

    function sell(uint256 _tokenAmount, uint256 _minReserveAmount) external returns (uint256, uint256) {
        uint256 tokenFeeAmount = getTokenSellFee(_tokenAmount);
        uint256 tokenNetAmount = _tokenAmount - tokenFeeAmount;

        uint256 initialVirtualSupply = virtualSupply();
        uint256 initialVirtualBalance = virtualBalance;
        uint256 reserveAmount = _calcSellAmount(tokenNetAmount, initialVirtualSupply, initialVirtualBalance);
        require(reserveAmount >= _minReserveAmount, "Min amount not reached");

        //virtualSupply = initialVirtualSupply - tokenNetAmount;
        virtualBalance = initialVirtualBalance - reserveAmount;

        _burn(msg.sender, tokenNetAmount);
        _transfer(msg.sender, FEE_RECIPIENT, tokenFeeAmount);
        reserveToken.transfer(msg.sender, reserveAmount);

        return (reserveAmount, tokenFeeAmount);
    }

    function _calcSellAmount(uint256 _tokenAmount, uint256 _supply, uint256 _balance) internal view returns (uint256) {
        require(_tokenAmount > 0, "Zero amount");

        //uint256 gasLeft = gasleft();
        uint256 reserveAmount = _balance
            * (DECIMAL_PRECISION
                - pow(DECIMAL_PRECISION - _tokenAmount * DECIMAL_PRECISION / _supply, B + DECIMAL_PRECISION))
            / DECIMAL_PRECISION;
        //console2.log(gasLeft - gasleft(), "gas used by math");

        return reserveAmount;
    }

    // For now this function is permissionless as it benefits the system.
    // Eventually we may protect it so it can be called from another contract to integrate it with other actions,
    // to prevent accidents.
    function floorSellAndBurn(uint256 _tokenAmount) external returns (uint256) {
        uint256 initialFloorSupply = floorSupply;
        uint256 initialFloorBalance = floorBalance;
        uint256 reserveAmount = _calcBuyOut(_tokenAmount, initialFloorSupply, initialFloorBalance);

        uint256 newFloorSupply = initialFloorSupply + _tokenAmount;
        require(newFloorSupply <= virtualSupply(), "Floor can surpass virtual state");
        uint256 newFloorBalance = initialFloorBalance + reserveAmount;
        assert(newFloorBalance <= virtualBalance);
        floorSupply = newFloorSupply;
        floorBalance = newFloorBalance;

        _burn(msg.sender, _tokenAmount);
        reserveToken.transfer(BURN_RECIPIENT, reserveAmount);

        return reserveAmount;
    }

    // For now this function is permissionless as it benefits the system.
    // Eventually we may protect it so it can be called from another contract to integrate it with other actions,
    // to prevent accidents.
    function buyFloorSellAndBurn(uint256 _reserveAmount, uint256 _minTokenAmount) external returns (uint256, uint256) {
        // Buy at the current price
        uint256 initialVirtualSupply = virtualSupply();
        uint256 initialVirtualBalance = virtualBalance;
        uint256 tokenBurnAmount = _calcBuyAmount(_reserveAmount, initialVirtualSupply, initialVirtualBalance);
        require(tokenBurnAmount >= _minTokenAmount, "Min amount not reached");

        //virtualSupply = initialVirtualSupply + tokenBurnAmount;
        virtualBalance = initialVirtualBalance + _reserveAmount;

        // Sell at the floor price
        uint256 initialFloorSupply = floorSupply;
        uint256 initialFloorBalance = floorBalance;
        uint256 sellReserveAmount = _calcBuyOut(tokenBurnAmount, initialFloorSupply, initialFloorBalance);
        assert(sellReserveAmount < _reserveAmount);

        floorSupply = initialFloorSupply + tokenBurnAmount;
        floorBalance = initialFloorBalance + sellReserveAmount;

        // We don't mint new tokens as they are "immediately burnt"
        reserveToken.transferFrom(msg.sender, address(this), _reserveAmount - sellReserveAmount);
        reserveToken.transferFrom(msg.sender, BURN_RECIPIENT, sellReserveAmount);

        return (tokenBurnAmount, sellReserveAmount);
    }

    function _calcBuyOut(uint256 _tokenAmount, uint256 _supply, uint256 _balance) internal view returns (uint256) {
        require(_tokenAmount > 0, "Zero amount");

        /*
        console2.log(_balance, "_balance");
        console2.log(_supply, "_supply");
        console2.log(_tokenAmount, "_tokenAmount");
        */
        //uint256 gasLeft = gasleft();
        uint256 reserveAmount = _balance
            * (pow(DECIMAL_PRECISION + _tokenAmount * DECIMAL_PRECISION / _supply, B + DECIMAL_PRECISION)
                - DECIMAL_PRECISION) / DECIMAL_PRECISION;
        //console2.log(gasLeft - gasleft(), "gas used by math");

        return reserveAmount;
    }

    function virtualSupply() public view returns (uint256) {
        return floorSupply + totalSupply();
    }

    function getPrice(uint256 _supply) public view returns (uint256) {
        return A * pow(_supply, B) / DECIMAL_PRECISION;
    }

    function currentPrice() external view returns (uint256) {
        return getPrice(virtualSupply());
    }

    function floorPrice() external view returns (uint256) {
        return getPrice(floorSupply);
    }

    function getTokenBuyFee(uint256 _tokenAmount) public pure returns (uint256 _tokenFeeAmount) {
        return _tokenAmount * FEE_PERCENTAGE / DECIMAL_PRECISION;
    }

    function getTokenSellFee(uint256 _tokenAmount) public pure returns (uint256 _tokenFeeAmount) {
        return _tokenAmount * FEE_PERCENTAGE / DECIMAL_PRECISION;
    }

    function reserveRatioDeviation() external view returns (int256) {
        return _reserveRatioDeviation(virtualSupply(), virtualBalance);
    }

    function checkCurrentDeviation() external view returns (bool) {
        return checkCurrentDeviation(ERROR_THRESHOLD);
    }

    function checkCurrentDeviation(uint256 _errorThreshold) public view returns (bool) {
        return _validatePosition(virtualSupply(), virtualBalance, _errorThreshold);
    }

    function _reserveRatioDeviation(uint256 _supply, uint256 _balance) internal view returns (int256) {
        return
            (int256(_supply * getPrice(_supply)) - int256((B + DECIMAL_PRECISION) * _balance))
                / int256(DECIMAL_PRECISION);
    }

    function _validatePosition(uint256 _supply, uint256 _balance, uint256 _errorThreshold)
        internal
        view
        returns (bool)
    {
        int256 deviation = _reserveRatioDeviation(_supply, _balance);
        uint256 absoluteDiff = deviation > 0 ? uint256(deviation) : uint256(-deviation);

        //console2.log(absoluteDiff * DECIMAL_PRECISION / _balance, "absoluteDiff * DECIMAL_PRECISION / _balance");
        if (absoluteDiff * DECIMAL_PRECISION / _balance < _errorThreshold) return true;
        return false;
    }

    // Unimplemented functions
    function pow(uint256 _base, uint256 _exponent) public pure virtual returns (uint256);

    // ERC20 functions

    function transfer(address recipient, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        _requireValidRecipient(recipient);
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override(ERC20, IERC20)
        returns (bool)
    {
        _requireValidRecipient(recipient);
        return super.transferFrom(sender, recipient, amount);
    }

    function _requireValidRecipient(address _recipient) internal view {
        require(
            _recipient != address(0) && _recipient != address(this),
            "BoldToken: Cannot transfer tokens directly to the Bold token contract or the zero address"
        );
    }

    function nonces(address owner) public view virtual override(IERC20Permit, ERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }
}
