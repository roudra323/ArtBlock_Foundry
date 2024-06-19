// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CustomERC20Token - A Custom ERC20 Token with minting and burning capabilities
 * @notice This contract allows for the creation of a custom ERC20 token with the ability to mint and burn tokens.
 * @dev The contract uses OpenZeppelin's ERC20, ERC20Burnable, and Ownable contracts.
 */
contract CustomERC20Token is ERC20, ERC20Burnable, Ownable {
    ///////////////////
    ///// Errors //////
    ///////////////////

    /**
     * @notice Error to indicate that a function can only be called by the main engine.
     * @param caller The address that attempted to call the function.
     */
    error CustomERC20Token__OnlyMainEngineCanCall(address caller);

    /////////////////////
    // State Variables //
    /////////////////////

    /**
     * @notice The address of the main engine allowed to mint and burn tokens.
     */
    address private immutable MAIN_ENGINE;

    ////////////////////
    ///// Modifiers ////
    ////////////////////

    /**
     * @notice Modifier to restrict access to functions to only the main engine.
     */
    modifier onlyMainEngine() {
        if (msg.sender != MAIN_ENGINE) {
            revert CustomERC20Token__OnlyMainEngineCanCall(msg.sender);
        }
        _;
    }

    ////////////////
    // Functions ///
    ////////////////

    /**
     * @notice Constructor to initialize the token with a name, symbol, and main engine address.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param creator The address of the contract creator.
     */
    constructor(string memory name, string memory symbol, address creator) ERC20(name, symbol) Ownable(creator) {
        MAIN_ENGINE = msg.sender;
    }

    /**
     * @notice Mints new tokens to a specified address.
     * @dev This function can only be called by the main engine. The amount is specified in the smallest unit
     * (considering 18 decimals).
     * @param to The address to receive the minted tokens.
     * @param amount The amount of tokens to mint (specified in the smallest unit, e.g., 1 token = 10^18 units).
     */
    function mint(address to, uint256 amount) public onlyMainEngine {
        _mint(to, amount);
    }

    /**
     * @notice Burns tokens from a specified address.
     * @dev This function can only be called by the main engine. The amount is specified in the smallest unit
     * (considering 18 decimals).
     * @param account The address from which tokens will be burned.
     * @param amount The amount of tokens to burn (specified in the smallest unit, e.g., 1 token = 10^18 units).
     */
    function burnFrom(address account, uint256 amount) public override onlyMainEngine {
        _burn(account, amount);
    }

    /**
     * @notice Returns the number of decimals used to get its user representation.
     * @dev This function overrides the ERC20 decimals function to return 18, meaning the token has 18 decimal places.
     * @return The number of decimals (18).
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
