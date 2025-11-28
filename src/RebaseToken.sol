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

import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin-contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author @Max
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in reword
 * @notice The interest rate can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__IntersetRateCanNotIncrease();

    /*//////////////////////////////////////////////////////////////
                                 EVENT
    //////////////////////////////////////////////////////////////*/
    event InterestRateSet(
        uint256 indexed oldInterestRate,
        uint256 indexed newInterestRate
    );

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private constant PRECISION = 1e18; // 1 ether

    bytes32 private constant MINT_AND_BURN_ROLE =
        keccak256("MINT_AND_BURN_ROLE");

    uint256 private interestRate = 5e10; // 0.000005% per day

    mapping(address user => uint256 rate) private userRateMap;

    mapping(address user => uint256 lastUpdateTimestamp)
        private userLastUpdateTimestampMap;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/

    function grantMintAndBurnRole(address _to) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _to);
    }
    function revokeMintAndBurnRole(address _to) external onlyOwner {
        _revokeRole(MINT_AND_BURN_ROLE, _to);
    }

    /**
     *
     * @param _newInterestRate The new interest rate
     * @notice Set the new interest rate
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate > interestRate) {
            revert RebaseToken__IntersetRateCanNotIncrease();
        }
        interestRate = _newInterestRate;
    }

    /**
     * @param _to The address to mint the interest to
     * @param _amount The amount of interest to mint
     * @notice Mint interest to the user
     * because the rebase token will not update user balance with time,
     * so the `mint` function have to mint the interest to the user
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintInterest(_to);
        userRateMap[_to] = interestRate;
        _mint(_to, _amount);
    }

    /**
     * @param _from The address to burn the interest from
     * @param _amount The amount of interest to burn
     * @notice Burn interest from the user
     * because the rebase token will not update user balance with time,
     * so the `burn` function have to burn the interest from the user
     * and update the user's last update timestamp
     * and burn the interest from the user
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        // option to quit the protocl
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintInterest(_from);
        _burn(_from, _amount);
    }

    /**
     *
     * @param _to The address to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @notice Transfer tokens to a user
     * because the rebase token will not update user balance with time,
     * so the `transfer` function have to mint the interest to the user
     * and update the user's last update timestamp
     * and transfer the tokens to the user
     */
    function transfer(
        address _to,
        uint256 _amount
    ) public override returns (bool) {
        _mintInterest(msg.sender);
        _mintInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_to) == 0) {
            userRateMap[_to] = userRateMap[msg.sender];
        }
        return super.transfer(_to, _amount);
    }

    /**
     *
     * @param _from The address to transfer the tokens from
     * @param _to The address to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @notice Transfer tokens from a user to another user
     * because the rebase token will not update user balance with time,
     * so the `transferFrom` function have to mint the interest to the user
     * and update the user's last update timestamp
     * and transfer the tokens from the user to the other user
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public virtual override returns (bool) {
        _mintInterest(_from);
        _mintInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        if (balanceOf(_to) == 0) {
            userRateMap[_to] = userRateMap[_from];
        }
        return super.transferFrom(_from, _to, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/
    function _calculateUserAccumulatedInterest(
        address _user
    ) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp -
            userLastUpdateTimestampMap[_user];
        if (timeElapsed == 0 || userRateMap[_user] == 0) {
            return PRECISION;
        }
        uint256 fractionalInterest = (timeElapsed * userRateMap[_user]);
        return PRECISION + fractionalInterest;
    }

    /**
     * @dev Internal function to calculate and mint accrued interest to the user
     * @dev Update user rate at the time of calling
     * @param _user The address of the user
     */
    function _mintInterest(address _user) internal {
        // calculate the interest to mint
        uint256 principalBalance = super.balanceOf(_user);
        uint256 allBalance = balanceOf(_user);
        uint256 balanceIncrease = allBalance - principalBalance;

        // update the user's last update timestamp
        userLastUpdateTimestampMap[_user] = block.timestamp;

        // mint the interest to the user
        _mint(_user, balanceIncrease);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW & PURE FUNCITONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the total balance of a user
     * @param _user The address of the user
     * @return The total balance of the user
     */
    function balanceOf(address _user) public view override returns (uint256) {
        uint256 principalBalance = super.balanceOf(_user);
        uint256 growthFactor = _calculateUserAccumulatedInterest(_user); // 1e18 + fractionalInterest
        return (principalBalance * growthFactor) / PRECISION;
    }

    /**
     * @notice Get the interest rate of a user
     * @param _user The address of the user
     * @return The interest rate of the user
     */
    function getUserRate(address _user) external view returns (uint256) {
        return userRateMap[_user];
    }

    /**
     * @notice Get the interest rate of the protocal
     * @return The interest rate of the protocal
     */
    function getInterestRate() external view returns (uint256) {
        return interestRate;
    }

    /**
     * @param _user The address of the user
     * @return The last update timestamp of the user
     */
    function getUserLastUpdateTimestamp(
        address _user
    ) external view returns (uint256) {
        return userLastUpdateTimestampMap[_user];
    }

    /**
     * @param _user The address of the user
     * @return The principal balance of the user
     */
    function getUserPrincipalBalance(
        address _user
    ) external view returns (uint256) {
        return super.balanceOf(_user);
    }
}
