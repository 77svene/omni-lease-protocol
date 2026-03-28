// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/OmniAccessControl.sol";

interface IVaultStorage {
    function lockAsset(uint256 tokenId, address owner) external;
    function unlockAsset(uint256 tokenId, address owner) external;
    function isLocked(uint256 tokenId) external view returns (bool);
}

interface IShadowFactory {
    function mintShadow(address collection, address to, uint256 tokenId, uint256 expiry) external returns (address);
    function burnShadow(address collection, uint256 tokenId) external;
}

interface IPricingOracle {
    function getLeasePrice(address collection, uint256 duration) external view returns (uint256);
}

interface IFeeDistributor {
    function distribute(address collection, uint256 amount, address lister) external;
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract RentalEngine is OmniAccessControl {
    struct Lease {
        address lessee;
        address collection;
        uint256 tokenId;
        uint256 expiry;
        bool active;
    }

    IERC20 public immutable paymentToken;
    IPricingOracle public oracle;
    IFeeDistributor public feeDistributor;
    IShadowFactory public shadowFactory;
    mapping(address => IVaultStorage) public vaults;
    
    // collection => tokenId => Lease
    mapping(address => mapping(uint256 => Lease)) public activeLeases;

    event Leased(address indexed collection, uint256 indexed tokenId, address indexed lessee, uint256 expiry);
    event Returned(address indexed collection, uint256 indexed tokenId);

    constructor(address _paymentToken, address _oracle, address _feeDistributor, address _shadowFactory) {
        paymentToken = IERC20(_paymentToken);
        oracle = IPricingOracle(_oracle);
        feeDistributor = IFeeDistributor(_feeDistributor);
        shadowFactory = IShadowFactory(_shadowFactory);
    }

    function setVault(address collection, address vault) external onlyRole(OPERATOR_ROLE) {
        vaults[collection] = IVaultStorage(vault);
    }

    function lease(address collection, uint256 tokenId, uint256 duration, address lister) external {
        require(duration > 0 && duration <= 30 days, "Engine: invalid duration");
        require(!activeLeases[collection][tokenId].active, "Engine: already leased");
        
        uint256 price = oracle.getLeasePrice(collection, duration);
        require(paymentToken.transferFrom(msg.sender, address(this), price), "Engine: payment failed");

        // Lock in vault
        vaults[collection].lockAsset(tokenId, lister);

        // Mint Shadow
        uint256 expiry = block.timestamp + duration;
        shadowFactory.mintShadow(collection, msg.sender, tokenId, expiry);

        activeLeases[collection][tokenId] = Lease({
            lessee: msg.sender,
            collection: collection,
            tokenId: tokenId,
            expiry: expiry,
            active: true
        });

        // Distribute fees
        paymentToken.approve(address(feeDistributor), price);
        feeDistributor.distribute(collection, price, lister);

        emit Leased(collection, tokenId, msg.sender, expiry);
    }

    function terminateLease(address collection, uint256 tokenId, address lister) external {
        Lease storage l = activeLeases[collection][tokenId];
        require(l.active, "Engine: not active");
        require(block.timestamp >= l.expiry, "Engine: not expired");

        l.active = false;
        shadowFactory.burnShadow(collection, tokenId);
        vaults[collection].unlockAsset(tokenId, lister);

        emit Returned(collection, tokenId);
    }
}