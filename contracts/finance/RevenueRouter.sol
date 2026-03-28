// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/OmniAccess.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
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
 * @title RevenueRouter
 * @dev Converts rental fees into protocol-standard currency using Uniswap V3.
 */
contract RevenueRouter is OmniAccess {
    ISwapRouter public immutable swapRouter;
    address public immutable WETH;
    address public targetToken; // e.g., USDC or protocol token
    uint24 public constant poolFee = 3000; // 0.3%

    event RevenueRouted(address indexed tokenIn, uint256 amountIn, uint256 amountOut);
    event TargetTokenUpdated(address indexed newTarget);

    constructor(address _swapRouter, address _weth, address _targetToken) {
        require(_swapRouter != address(0), "Router: zero swapRouter");
        require(_targetToken != address(0), "Router: zero targetToken");
        swapRouter = ISwapRouter(_swapRouter);
        WETH = _weth;
        targetToken = _targetToken;
    }

    function setTargetToken(address _newTarget) external onlyAdmin {
        require(_newTarget != address(0), "Router: zero target");
        targetToken = _newTarget;
        emit TargetTokenUpdated(_newTarget);
    }

    /**
     * @dev Swaps collected fees to the target token.
     * @param _tokenIn The token to swap from.
     * @param _amountIn The amount of tokenIn to swap.
     * @param _minAmountOut Slippage protection.
     */
    function routeRevenue(
        address _tokenIn,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) external onlyOperator returns (uint256 amountOut) {
        require(_amountIn > 0, "Router: zero amount");
        
        if (_tokenIn == targetToken) {
            IERC20(_tokenIn).transfer(msg.sender, _amountIn);
            return _amountIn;
        }

        IERC20(_tokenIn).approve(address(swapRouter), _amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: targetToken,
            fee: poolFee,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: _minAmountOut,
            sqrtPriceLimitX96: 0
        });

        amountOut = swapRouter.exactInputSingle(params);
        emit RevenueRouted(_tokenIn, _amountIn, amountOut);
    }

    /**
     * @dev Emergency withdraw for stuck tokens.
     */
    function rescueTokens(address _token, uint256 _amount) external onlyAdmin {
        IERC20(_token).transfer(admin, _amount);
    }
}