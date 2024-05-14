// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CustomERC20Token is ERC20, ERC20Burnable, Ownable {
    ///////////////////
    ///// Errors //////
    ///////////////////

    error CustomERC20Token__OnlyMainEngineCanCall(address caller);

    /////////////////////
    // State Variables //
    /////////////////////
    address private immutable MAIN_ENGINE;

    modifier onlyMainEngine() {
        if (msg.sender != MAIN_ENGINE) {
            revert CustomERC20Token__OnlyMainEngineCanCall(msg.sender);
        }
        _;
    }

    ////////////////
    // Functions ///
    ////////////////

    constructor(string memory name, string memory symbol, address creator) ERC20(name, symbol) Ownable(creator) {
        MAIN_ENGINE = msg.sender;
    }

    function mint(address to, uint256 amount) public onlyMainEngine {
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyMainEngine {
        _burn(account, amount);
    }
}
