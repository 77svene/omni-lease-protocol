// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/OmniAccessControl.sol";
import "../core/LeaseRegistry.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IPricingOracle {
    function getLeasePrice(address collection, uint256 duration) external view returns (uint256);
}

interface IFeeDistributor {
    function distribute(address collection, uint256 amount) external;
}

interface IVault {
    function createLease(uint256 tokenId, address lessee, uint256 duration) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @title RentalEngine
 * @dev Orchestrates the rental process: payment, pricing, and lease creation.
 */
contract RentalEngine is OmniAccessControl {
    LeaseRegistry public immutable registry;
    IPricingOracle public oracle;
    IFeeDistributor public feeDistributor;
    IERC20 public immutable paymentToken;

    event Leased(address indexed collection, uint256 indexed tokenId, address indexed lessee, uint256 duration, uint256 price);

    constructor(address _registry, address _oracle, address _feeDistributor, address _paymentToken) {
        registry = LeaseRegistry(_registry);
        oracle = IPricingOracle(_oracle);
        feeDistributor = IFeeDistributor(_feeDistributor);
        paymentToken = IERC20(_paymentToken);
    }

    /**
     * @dev Updates the oracle address.
     */
    function setOracle(address _oracle) external onlyRole(ADMIN_ROLE) {
        require(_oracle != address(0), "RentalEngine: zero address");
        oracle = IPricingOracle(_oracle);
    }

    /**
     * @dev Updates the fee distributor address.
     */
    function setFeeDistributor(address _distributor) external onlyRole(ADMIN_ROLE) {
        require(_distributor != address(0), "RentalEngine: zero address");
        feeDistributor = IFeeDistributor(_distributor);
    }

    /**
     * @dev Executes a lease. 
     * 1. Calculates price via Oracle.
     * 2. Collects payment in USDC.
     * 3. Triggers Vault to mint Shadow NFT.
     * 4. Distributes fees.
     */
    function lease(address collection, uint256 tokenId, uint256 duration) external {
        address vaultAddr = registry.collectionToVault(collection);
        require(vaultAddr != address(0), "RentalEngine: collection not registered");
        
        uint256 price = oracle.getLeasePrice(collection, duration);
        require(price > 0, "RentalEngine: invalid price");

        // Collect payment
        require(paymentToken.transferFrom(msg.sender, address(this), price), "RentalEngine: payment failed");

        // Approve FeeDistributor to take the funds
        paymentToken.approve(address(feeDistributor), price);
        feeDistributor.distribute(collection, price);

        // Trigger Vault to create lease (mint Shadow NFT)
        IVault(vaultAddr).createLease(tokenId, msg.sender, duration);

        emit Leased(collection, tokenId, msg.sender, duration, price);
    }
}

interface IERC20_Approve {
    function approve(address spender, uint256 amount) external returns (bool);
}