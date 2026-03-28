// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title TimeLockLogic
 * @dev Logic for managing time-bound utility rights and expiration.
 */
library TimeLockLogic {
    struct LeasePeriod {
        uint256 startTime;
        uint256 endTime;
        bool isActive;
    }

    /**
     * @dev Validates if a lease is currently active based on block timestamp.
     */
    function isLeaseValid(LeasePeriod memory lease) internal view returns (bool) {
        if (!lease.isActive) return false;
        return (block.timestamp >= lease.startTime && block.timestamp <= lease.endTime);
    }

    /**
     * @dev Calculates the remaining duration of a lease.
     */
    function remainingTime(LeasePeriod memory lease) internal view returns (uint256) {
        if (block.timestamp >= lease.endTime) return 0;
        return lease.endTime - block.timestamp;
    }

    /**
     * @dev Extends a lease period by a given duration.
     */
    function extendLease(LeasePeriod storage lease, uint256 duration) internal {
        require(lease.isActive, "TimeLock: lease not active");
        lease.endTime += duration;
    }

    /**
     * @dev Creates a new lease period starting now.
     */
    function createLease(uint256 duration) internal view returns (LeasePeriod memory) {
        return LeasePeriod({
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            isActive: true
        });
    }
}