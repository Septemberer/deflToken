// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LToken is ERC20 {
    constructor(uint256 initSupply) ERC20("LToken", "LTT") {
        _mint(msg.sender, initSupply);
    }
}
