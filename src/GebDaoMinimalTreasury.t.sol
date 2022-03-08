// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "./GebDaoMinimalTreasury.sol";

abstract contract Hevm {
    function warp(uint) virtual public;
    function roll(uint) virtual public;
}

contract Delegate {
    function delegateTransferERC20(GebDaoMinimalTreasury treasury, address dst, uint amount) public {
        treasury.delegateTransferERC20(dst, amount);
    }
}

contract GebDaoMinimalTreasuryTest is DSTest {
    GebDaoMinimalTreasury treasury;
    Delegate delegate;
    DSToken token;
    uint256 epochLength = 4 weeks;
    uint256 allowance   = 100 ether;
    uint256 initialTreasuryBalance = 1e6 ether;

    Hevm hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        delegate = new Delegate();
        token = new DSToken("name", "symbol");
        treasury = new GebDaoMinimalTreasury(
            address(token),
            address(delegate),
            epochLength,
            allowance
        );

        token.mint(address(treasury), initialTreasuryBalance);
    }

    function test_constructor() public {
        assertEq(address(treasury.token()), address(token));
        assertEq(address(treasury.treasuryDelegate()), address(delegate));
        assertEq(treasury.epochLength(), epochLength);
        assertEq(treasury.delegateAllowance(), allowance);
        assertEq(treasury.epochStart(), now);
        assertEq(treasury.delegateLeftoverToSpend(), allowance);
    }

    function test_constructor_no_delegate() public {
        treasury = new GebDaoMinimalTreasury(
            address(token),
            address(0),
            epochLength,
            allowance
        );

        assertEq(address(treasury.token()), address(token));
        assertEq(address(treasury.treasuryDelegate()), address(0));
        assertEq(treasury.epochLength(), epochLength);
        assertEq(treasury.delegateAllowance(), allowance);
        assertEq(treasury.epochStart(), now);
        assertEq(treasury.delegateLeftoverToSpend(), allowance);
    }

    function test_constructor_no_allowance() public {
        treasury = new GebDaoMinimalTreasury(
            address(token),
            address(delegate),
            epochLength,
            0
        );

        assertEq(address(treasury.token()), address(token));
        assertEq(address(treasury.treasuryDelegate()), address(delegate));
        assertEq(treasury.epochLength(), epochLength);
        assertEq(treasury.delegateAllowance(), 0);
        assertEq(treasury.epochStart(), now);
        assertEq(treasury.delegateLeftoverToSpend(), 0);
    }

    function testFail_constructor_invalid_token() public {
        treasury = new GebDaoMinimalTreasury(
            address(0),
            address(delegate),
            epochLength,
            allowance
        );
    }

    function testFail_constructor_invalid_epoch_length() public {
        treasury = new GebDaoMinimalTreasury(
            address(token),
            address(delegate),
            0,
            allowance
        );
    }

    modifier removeAuth() {
        treasury.removeAuthorization(address(this));
        _;
    }

    function test_modify_parameters_epochLength() public {
        treasury.modifyParameters("epochLength", 1 weeks);
        assertEq(treasury.epochLength(), 1 weeks);
    }

    function testFail_modify_parameters_uint_unauthed() public removeAuth {
        treasury.modifyParameters("epochLength", 1 weeks);
    }

    function testFail_modify_parameters_invalid_epochLength() public {
        treasury.modifyParameters("epochLength", 0);
    }

    function test_modify_parameters_delegateAllowance_lower() public {
        treasury.modifyParameters("delegateAllowance", 1 ether);
        assertEq(treasury.delegateAllowance(), 1 ether);
        assertEq(treasury.delegateLeftoverToSpend(), 1 ether);
    }

    function test_modify_parameters_delegateAllowance_higher() public {
        treasury.modifyParameters("delegateAllowance", 1000 ether);
        assertEq(treasury.delegateAllowance(), 1000 ether);
        assertEq(treasury.delegateLeftoverToSpend(), allowance);
    }

    function test_modify_parameters_delegate() public {
        treasury.modifyParameters("treasuryDelegate", address(0x1));
        assertEq(treasury.treasuryDelegate(), address(0x1));
    }

    function testFail_modify_parameters_address_unauthed() public removeAuth {
        treasury.modifyParameters("treasuryDelegate", address(0x1));
    }

    function test_transfer_ERC20_admin() external {
        uint transferAmount = allowance * 2;
        treasury.transferERC20(address(token), address(0xfab), transferAmount);
        assertEq(token.balanceOf(address(treasury)), initialTreasuryBalance - transferAmount);
        assertEq(token.balanceOf(address(0xfab)), transferAmount);
    }

    function testFail_transfer_ERC20_admin_unauthed() external removeAuth {
        uint transferAmount = 2;
        treasury.transferERC20(address(token), address(0xfab), transferAmount);
    }

    function test_transfer_ERC20_delegate() external {
        uint transferAmount = allowance;
        delegate.delegateTransferERC20(treasury, address(0xfab), transferAmount);
        assertEq(token.balanceOf(address(treasury)), initialTreasuryBalance - transferAmount);
        assertEq(treasury.delegateLeftoverToSpend(), 0);
        assertEq(token.balanceOf(address(0xfab)), transferAmount);
    }

    function testFail_transfer_ERC20_delegate_over_allowance() external {
        uint transferAmount = allowance + 1;
        delegate.delegateTransferERC20(treasury, address(0xfab), transferAmount);
    }

    function test_transfer_ERC20_delegate_multiple_epochs() external {
        uint transferAmount = allowance;
        for (uint i; i < 10; i++) {
            hevm.warp(now + epochLength + 1);
            delegate.delegateTransferERC20(treasury, address(0xfab), transferAmount);
            emit log_named_uint("epochStart", treasury.epochStart());
        }

        assertEq(token.balanceOf(address(treasury)), initialTreasuryBalance - transferAmount * 10);
        assertEq(treasury.delegateLeftoverToSpend(), 0);
        assertEq(token.balanceOf(address(0xfab)), transferAmount * 10);
    }

    function test_transfer_ERC20_delegate_multiple_epochs_no_spending_in_between() external {
        uint transferAmount = allowance;
        for (uint i; i < 10; i++) {
            hevm.warp(now + 1 + epochLength * 3);
            delegate.delegateTransferERC20(treasury, address(0xfab), transferAmount);
            emit log_named_uint("epochStart", treasury.epochStart());
        }

        assertEq(token.balanceOf(address(treasury)), initialTreasuryBalance - transferAmount * 10);
        assertEq(treasury.delegateLeftoverToSpend(), 0);
        assertEq(token.balanceOf(address(0xfab)), transferAmount * 10);
    }

    function testFail_transfer_ERC20__delegate_unauthed() external removeAuth {
        treasury.delegateTransferERC20(address(0xfab), 1);
    }
}
