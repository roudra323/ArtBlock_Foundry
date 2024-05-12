// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CustomERC20Token is ERC20, ERC20Burnable, Ownable {
    constructor(string memory name, string memory symbol, address creator) ERC20(name, symbol) Ownable(creator) {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
