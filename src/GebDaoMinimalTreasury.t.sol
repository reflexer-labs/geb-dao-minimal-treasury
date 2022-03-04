// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "./GebDaoMinimalTreasury.sol";

contract Target {
    uint256 public calls;
    function arbitraryCall() external payable {
        calls++;
    }
}

contract GebDaoMinimalTreasuryTest is DSTest {
    GebDaoMinimalTreasury treasury;

    function setUp() public {
        treasury = new GebDaoMinimalTreasury();
    }

    modifier removeAuth() {
        treasury.removeAuthorization(address(this));
        _;
    }

    function testTransferERC20() external {
        DSToken token = new DSToken("name", "symbol");
        token.mint(address(treasury), 1000 ether);
        assertEq(token.balanceOf(address(treasury)), 1000 ether);
        treasury.transferERC20(address(token), address(0xfab), 1000 ether);
        assertEq(token.balanceOf(address(treasury)), 0);
        assertEq(token.balanceOf(address(0xfab)), 1000 ether);
    }

    function testFailTransferERC20Unauthorized() external removeAuth {
        DSToken token = new DSToken("name", "symbol");
        token.mint(address(treasury), 1000 ether);
        assertEq(token.balanceOf(address(treasury)), 1000 ether);
        treasury.transferERC20(address(token), address(0xfab), 1000 ether);
    }

    function testTransferEther() external {
        address(treasury).transfer(100 ether);
        assertEq(address(treasury).balance, 100 ether);
        treasury.transferEther(address(0xfab), 100 ether);
        assertEq(address(treasury).balance, 0);
        assertEq(address(0xfab).balance, 100 ether);
    }

    function testFailTransferEtherUnauthorized() external removeAuth {
        address(treasury).transfer(100 ether);
        assertEq(address(treasury).balance, 100 ether);
        treasury.transferEther(address(0xfab), 100 ether);
    }

    function testExternalCall() external {
        Target target = new Target();
        assertEq(target.calls(), 0);
        address(treasury).transfer(100 ether);

        treasury.externalCall(
            address(target),
            100 ether,
            abi.encodePacked(Target.arbitraryCall.selector)
        );
        assertEq(target.calls(), 1);
    }

    function testFailExternalCallUnauthorized() external removeAuth {
        Target target = new Target();
        assertEq(target.calls(), 0);
        address(treasury).transfer(100 ether);

        treasury.externalCall(
            address(target),
            100 ether,
            abi.encodePacked(Target.arbitraryCall.selector)
        );
    }
}
