// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    uint256 private _nextTokenId = 0;

    constructor() ERC20("TestToken", "TK") {}

    function mint(address recipient, uint256 quantity) public payable {
        _mint(recipient, quantity);
    }
}
