// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
}

contract CommunityIncentiveCNT {
    address public AxnAddress;
    address private owner;

    receive() external payable {}

    constructor() {
        owner = msg.sender;
    }

    function send(address _user, uint256 _amt) external payable {
        require(msg.sender == AxnAddress, "Unauthorized");

        IERC20 token = IERC20(AxnAddress);
        uint256 bal = token.balanceOf(address(this));
        require(bal >= _amt, "Insufficient token balance");
        bool success = token.transfer(_user, _amt);
        require(success, "Token transfer failed");
    }

    function setProject(address _project) external {
        require(AxnAddress == address(0), "already set");
        AxnAddress = _project;
    }
}
