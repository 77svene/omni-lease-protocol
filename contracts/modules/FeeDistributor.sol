// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/OmniAccessControl.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title FeeDistributor
 * @dev Handles the distribution of rental fees between the asset owner and the protocol treasury.
 * Default split: 95% to Owner, 5% to Treasury.
 */
contract FeeDistributor is OmniAccessControl {
    address public treasury;
    uint256 public protocolFeeBps = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10000;

    event FeesDistributed(address indexed token, address indexed owner, uint256 ownerAmount, uint256 treasuryAmount);
    event TreasuryUpdated(address indexed newTreasury);
    event FeeUpdated(uint256 newFeeBps);

    constructor(address _treasury) {
        require(_treasury != address(0), "FeeDistributor: zero treasury");
        treasury = _treasury;
    }

    /**
     * @dev Sets the protocol treasury address.
     */
    function setTreasury(address _treasury) external onlyRole(ADMIN_ROLE) {
        require(_treasury != address(0), "FeeDistributor: zero treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /**
     * @dev Sets the protocol fee in basis points.
     */
    function setProtocolFee(uint256 _feeBps) external onlyRole(ADMIN_ROLE) {
        require(_feeBps <= 2000, "FeeDistributor: fee too high"); // Max 20%
        protocolFeeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    /**
     * @dev Distributes the fee from a rental payment.
     * @param token The ERC20 token used for payment (e.g., USDC).
     * @param payer The user paying for the lease.
     * @param owner The NFT owner receiving the majority of the fee.
     * @param totalAmount The total amount paid by the renter.
     */
    function distribute(
        address token,
        address payer,
        address owner,
        uint256 totalAmount
    ) external onlyRole(OPERATOR_ROLE) {
        require(token != address(0), "FeeDistributor: zero token");
        require(owner != address(0), "FeeDistributor: zero owner");
        require(totalAmount > 0, "FeeDistributor: zero amount");

        uint256 treasuryAmount = (totalAmount * protocolFeeBps) / BPS_DENOMINATOR;
        uint256 ownerAmount = totalAmount - treasuryAmount;

        // Pull funds from payer
        bool successPayer = IERC20(token).transferFrom(payer, address(this), totalAmount);
        require(successPayer, "FeeDistributor: transfer from payer failed");

        // Push to treasury
        if (treasuryAmount > 0) {
            bool successTreasury = IERC20(token).transfer(treasury, treasuryAmount);
            require(successTreasury, "FeeDistributor: transfer to treasury failed");
        }

        // Push to owner
        bool successOwner = IERC20(token).transfer(owner, ownerAmount);
        require(successOwner, "FeeDistributor: transfer to owner failed");

        emit FeesDistributed(token, owner, ownerAmount, treasuryAmount);
    }

    /**
     * @dev Emergency withdrawal of stuck tokens.
     */
    function rescueTokens(address token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        IERC20(token).transfer(msg.sender, amount);
    }
}