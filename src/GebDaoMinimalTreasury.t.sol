// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./GebDaoMinimalTreasury.sol";

contract GebDaoMinimalTreasuryTest is DSTest {
    GebDaoMinimalTreasury treasury;

    function setUp() public {
        treasury = new GebDaoMinimalTreasury();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
