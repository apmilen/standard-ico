pragma solidity ^0.4.17;

import "ds-test/test.sol";

import "./StandardIco.sol";

contract StandardSaleTest is DSTest {
    StandardIco ico;

    function setUp() {
        ico = new StandardIco();
    }

    function testFail_basic_sanity() {
        assertTrue(false);
    }

    function test_basic_sanity() {
        assertTrue(true);
    }
}
