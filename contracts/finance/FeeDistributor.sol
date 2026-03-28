// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/OmniAccess.sol";

/**
 * @title FeeDistributor
 * @dev Manages the 3-way split of rental fees: Owner (80%), Protocol (10%), LPs (10%).
 * Percentages are configurable by admin.
 */
contract FeeDistributor is OmniAccess {
    uint256 public constant BASIS_POINTS = 10000;
    
    uint256 public ownerShare = 8000;    // 80%
    uint256 public protocolShare = 1000; // 10%
    uint256 public lpShare = 1000;       // 10%
    
    address public protocolTreasury;
    address public lpPool;

    event FeesDistributed(address indexed owner, uint256 ownerAmount, uint256 protocolAmount, uint256 lpAmount);
    event SharesUpdated(uint256 owner, uint256 protocol, uint256 lp);

    constructor(address _protocolTreasury, address _lpPool) {
        require(_protocolTreasury != address(0), "FeeDistributor: zero treasury");
        require(_lpPool != address(0), "FeeDistributor: zero lp pool");
        protocolTreasury = _protocolTreasury;
        lpPool = _lpPool;
    }

    function setShares(uint256 _owner, uint256 _protocol, uint256 _lp) external onlyAdmin {
        require(_owner + _protocol + _lp == BASIS_POINTS, "FeeDistributor: total must be 10000");
        ownerShare = _owner;
        protocolShare = _protocol;
        lpShare = _lp;
        emit SharesUpdated(_owner, _protocol, _lp);
    }

    function setTreasury(address _treasury) external onlyAdmin {
        require(_treasury != address(0), "FeeDistributor: zero address");
        protocolTreasury = _treasury;
    }

    function setLPPool(address _lpPool) external onlyAdmin {
        require(_lpPool != address(0), "FeeDistributor: zero address");
        lpPool = _lpPool;
    }

    /**
     * @dev Distributes incoming ETH fees.
     * @param _owner The NFT owner receiving the bulk of the fee.
     */
    function distribute(address _owner) external payable {
        require(msg.value > 0, "FeeDistributor: no value");
        require(_owner != address(0), "FeeDistributor: zero owner");

        uint256 oAmount = (msg.value * ownerShare) / BASIS_POINTS;
        uint256 pAmount = (msg.value * protocolShare) / BASIS_POINTS;
        uint256 lAmount = msg.value - oAmount - pAmount; // Remainder to LP to avoid dust

        (bool s1, ) = payable(_owner).call{value: oAmount}("");
        require(s1, "FeeDistributor: owner transfer failed");

        (bool s2, ) = payable(protocolTreasury).call{value: pAmount}("");
        require(s2, "FeeDistributor: protocol transfer failed");

        (bool s3, ) = payable(lpPool).call{value: lAmount}("");
        require(s3, "FeeDistributor: lp transfer failed");

        emit FeesDistributed(_owner, oAmount, pAmount, lAmount);
    }

    receive() external payable {
        // Default behavior: treat as protocol revenue if no owner specified
        (bool s, ) = payable(protocolTreasury).call{value: msg.value}("");
        require(s, "FeeDistributor: default transfer failed");
    }
}