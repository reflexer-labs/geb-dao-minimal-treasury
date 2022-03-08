// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.7;

import "./auth/GebAuth.sol";

abstract contract TokenLike {
    function transfer(address, uint256) external virtual;
}

/**
* @notice   Minimal treasury for the community DAO
*           Allows for delegating control of the treasury (fixed amount per epoch)
*           Governance can update allowance or revoke rights at any time
*           Increases in allowance take effect only in next epoch, decreases immediately
**/
contract GebDaoMinimalTreasury is GebAuth {
    // --- State vars ---
    // Token kept in the treasury
    TokenLike immutable public token;
    // delegate, can spend allowance every epoch
    address public treasuryDelegate;
    // duration of each epoch (seconds)
    uint256 public epochLength;
    // amount that can be spent each epoch
    uint256 public delegateAllowance;
    // amount left to spend in current epock
    uint256 public delegateLeftoverToSpend;
    // current epoch start (Unix timestamp)
    uint256 public epochStart;

    // --- Constructor ---
    /**
     * @notice Constructor
     * @param _token Token to be used
     * @param _delegate Delegate
     * @param _epochLength Duration of each epoch (seconds)
     * @param _delegateAllowance Amount that can be spent by the delegate each epoch
     */
    constructor(
        address _token,
        address _delegate,
        uint256 _epochLength,
        uint256 _delegateAllowance
    ) public {
        require(_epochLength > 0, "GebDAOMinimalTreasury/invalid-epoch");
        require(_token != address(0), "GebDAOMinimalTreasury/invalid-epoch");
        token = TokenLike(_token);
        treasuryDelegate = _delegate;
        epochLength = _epochLength;
        delegateAllowance = _delegateAllowance;
        epochStart = now;
        delegateLeftoverToSpend = _delegateAllowance;
    }
    // --- SafeMath ---
    function subtract(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "MultiAccountingEngine/sub-underflow");
    }

    // --- Boolean Logic ---
    function either(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := or(x, y)}
    }

    // --- Admin functions ---
    /**
    * @notice Modify an int256 parameter
    * @param parameter The name of the parameter to change
    * @param val The new value for the parameter
    **/
    function modifyParameters(bytes32 parameter, uint256 val) external isAuthorized {
        if (parameter == "epochLength") {
          require(val > 0, "GebDAOMinimalTreasury/invalid-epochLength");
          epochLength = val;
        }
        else if (parameter == "delegateAllowance") {
          delegateAllowance = val;
          if (val < delegateLeftoverToSpend)
            delegateLeftoverToSpend = val;
        }
        else revert("GebDAOMinimalTreasury/modify-unrecognized-param");
    }

    /**
    * @notice Modify an int256 parameter
    * @param parameter The name of the parameter to change
    * @param val The new value for the parameter
    **/
    function modifyParameters(bytes32 parameter, address val) external isAuthorized {
        if (parameter == "treasuryDelegate") {
          treasuryDelegate = val;
        }
        else revert("GebDAOMinimalTreasury/modify-unrecognized-param");
    }

    // --- Delegate functions ---

    /**
    * @notice Updates epoch info.
    *         Balance not used in previous epochs should not be available
    **/
    modifier updateEpoch() {
        uint256 epochFinish = epochStart + epochLength;
        if (now > epochFinish) {
            delegateLeftoverToSpend = delegateAllowance;
            if (now - epochFinish > epochLength) {
                uint256 epochsElapsed = (now - epochFinish) / epochLength;
                epochStart = (epochsElapsed * epochLength) + epochFinish;
            } else
                epochStart = epochFinish;
        }
        _;
    }

    /**
     * @notice Transfer tokens from treasury to dst
     * @param dst The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     */
    function transferERC20(address dst, uint256 amount) external updateEpoch {
        require(msg.sender == treasuryDelegate || authorizedAccounts[msg.sender] == 1, "GebDAOMinimalTreasury/unauthorized");
        if (msg.sender == treasuryDelegate) {
            delegateLeftoverToSpend = subtract(delegateLeftoverToSpend, amount); // reverts if lower allowance
        }
        token.transfer(dst, amount);
    }
}
