// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.30;

import {IRebaseToken} from "./interface/IRebaseToken.sol";

/**
 * @title Vault
 * @author @Max
 * @notice 1. the Contract will keep the address of RebaseToken (parse in constructor)
 * @notice 2. impl deposit function -Accept ETH from user -Mint RebaseToken to user
 * @notice 3. impl redeem function -burn RebaseToken -Sent ETH to user
 * @notice 4. impl a mechanism to add ETH Reward to the Vault
 */
contract Vault {
    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IRebaseToken private immutable REBASE_TOKEN;

    /*//////////////////////////////////////////////////////////////
                                 EVENT
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed user, uint256 amount);

    event Redeem(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERROR
    //////////////////////////////////////////////////////////////*/
    error Vault__RedeemFailed();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(IRebaseToken _rebaseToken) {
        REBASE_TOKEN = _rebaseToken;
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint RebaseToken to the user
     */
    function deposit() external payable {
        REBASE_TOKEN.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Burn RebaseToken and send ETH to the user
     * @param _amount The amount of RebaseToken to burn
     */
    function redeem(uint256 _amount) external {
        REBASE_TOKEN.burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW AND PURE FUNCITONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the address of the RebaseToken
     * @return The address of the RebaseToken
     */
    function getRebaseToken() external view returns (address) {
        return address(REBASE_TOKEN);
    }
}
