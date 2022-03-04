// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.7;

import "./auth/GebAuth.sol";

abstract contract TokenLike {
    function transfer(address, uint256) external virtual;
}

// @notice Minimal treasury for the community DAO
contract GebDaoMinimalTreasury is GebAuth {

    /**
     * @notice Transfer tokens from treasury to dst
     * @param token The address to transfer tokens from
     * @param dst The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     */
    function transferERC20(address token, address dst, uint256 amount) external isAuthorized {
        TokenLike(token).transfer(dst, amount);
    }

    /**
     * @notice Transfer ether from treasury to dst
     * @param dst The address to transfer tokens to
     * @param value The ETH value to transfer
     */
    function transferEther(address dst, uint256 value) external isAuthorized {
        (bool success, ) = dst.call{value: value}("");
        require(success);
    }

    /**
     * @notice Perform arbitrary calls from the treasury
     * @param target The address to send the call to
     * @param value The ETH value to transfer
     * @param data Input raw data for the call
     */
    function externalCall(address target, uint256 value, bytes calldata data) external isAuthorized {
        (bool success, ) = target.call{value: value}(data);
        require(success);
    }

    receive() external payable {}
}
