// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/OmniAccessControl.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/**
 * @title YieldAggregator
 * @dev Manages protocol liquidity and interacts with Uniswap V3 for yield optimization.
 */
contract YieldAggregator is OmniAccessControl {
    address public immutable usdc;
    address public immutable swapRouter;
    uint24 public constant poolFee = 3000; // 0.3%

    event YieldGenerated(address indexed token, uint256 amount);
    event FundsWithdrawn(address indexed token, address indexed to, uint256 amount);

    constructor(address _usdc, address _swapRouter) {
        require(_usdc != address(0), "Yield: zero usdc");
        require(_swapRouter != address(0), "Yield: zero router");
        usdc = _usdc;
        swapRouter = _swapRouter;
    }

    /**
     * @dev Swaps USDC for a target yield-bearing token (e.g., WETH or a stable variant).
     * In a real MVP, this would be used to rebalance or move funds into yield positions.
     */
    function deployLiquidity(address targetToken, uint256 amount) external onlyRole(OPERATOR_ROLE) returns (uint256 amountOut) {
        require(IERC20(usdc).balanceOf(address(this)) >= amount, "Yield: insufficient balance");
        
        IERC20(usdc).approve(swapRouter, amount);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: usdc,
            tokenOut: targetToken,
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        amountOut = ISwapRouter(swapRouter).exactInputSingle(params);
        emit YieldGenerated(targetToken, amountOut);
    }

    /**
     * @dev Emergency or scheduled withdrawal of funds back to the treasury/FeeDistributor.
     */
    function withdraw(address token, address to, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(to != address(0), "Yield: zero address");
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance >= amount, "Yield: amount exceeds balance");
        
        bool success = IERC20(token).transfer(to, amount);
        require(success, "Yield: transfer failed");
        
        emit FundsWithdrawn(token, to, amount);
    }

    /**
     * @dev Fallback to receive ETH if swapping from WETH or similar.
     */
    receive() external payable {}
}