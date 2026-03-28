// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract OmniAccess {
    address public admin;
    mapping(address => bool) public operators;

    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event OperatorStatusChanged(address indexed operator, bool status);

    constructor() {
        admin = msg.sender;
        operators[msg.sender] = true;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "OmniAccess: caller is not admin");
        _;
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "OmniAccess: caller is not operator");
        _;
    }

    function setAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "OmniAccess: zero address");
        emit AdminChanged(admin, _newAdmin);
        admin = _newAdmin;
    }

    function setOperator(address _operator, bool _status) external onlyAdmin {
        operators[_operator] = _status;
        emit OperatorStatusChanged(_operator, _status);
    }
}