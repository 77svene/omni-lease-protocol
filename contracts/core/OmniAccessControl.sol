// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract OmniAccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    mapping(bytes32 => mapping(address => bool)) private _roles;
    uint256 private _adminCount;

    event RoleGranted(bytes32 indexed role, address indexed account);
    event RoleRevoked(bytes32 indexed role, address indexed account);

    constructor() {
        _roles[ADMIN_ROLE][msg.sender] = true;
        _adminCount = 1;
        emit RoleGranted(ADMIN_ROLE, msg.sender);
    }

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "AccessControl: account lacks role");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function grantRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        require(account != address(0), "AccessControl: zero address");
        if (!_roles[role][account]) {
            _roles[role][account] = true;
            if (role == ADMIN_ROLE) _adminCount++;
            emit RoleGranted(role, account);
        }
    }

    function revokeRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        require(_roles[role][account], "AccessControl: role not assigned");
        if (role == ADMIN_ROLE) {
            require(_adminCount > 1, "AccessControl: last admin");
            require(account != msg.sender, "AccessControl: use renounce for self");
            _adminCount--;
        }
        _roles[role][account] = false;
        emit RoleRevoked(role, account);
    }

    function renounceRole(bytes32 role) external {
        require(_roles[role][msg.sender], "AccessControl: role not assigned");
        if (role == ADMIN_ROLE) {
            require(_adminCount > 1, "AccessControl: last admin");
            _adminCount--;
        }
        _roles[role][msg.sender] = false;
        emit RoleRevoked(role, msg.sender);
    }
}