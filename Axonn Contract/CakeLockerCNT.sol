// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
}

contract CakeLockerCNT {
    address public AxnAddress;
    address public CakeAddress;
    address private owner;

    receive() external payable {}

    constructor() {
        owner = msg.sender;
    }

    function send(address _user, uint256 _percAmt) external payable {
        require(msg.sender == AxnAddress, "Unauthorized");
        require(_percAmt > 0, "Invalid amount");

        IERC20 token = IERC20(CakeAddress);
        uint256 bal = token.balanceOf(address(this));
        if (bal > 0) {
            bool success = token.transfer(_user, (bal * _percAmt) / 100);
            require(success, "Token transfer failed");
        }

        IERC20 token1 = IERC20(AxnAddress);
        uint256 bal1 = token1.balanceOf(address(this));
        if (bal1 > 0) {
            bool success1 = token1.transfer(_user, (bal1 * _percAmt) / 100);
            require(success1, "Token transfer failed");
        }
    }

    function setProject(address _project, address _CakeAddress) external {
        require(msg.sender == owner, "already set");
        AxnAddress = _project;
        CakeAddress = _CakeAddress;
    }
}
