pragma solidity ^0.4.17;

import "ds-test/test.sol";
import "ds-exec/exec.sol";
import "ds-token/token.sol";

import "./sale.sol";

contract StandardSaleUser is DSExec {

    StandardSale sale;
    DSToken token;

    function StandardSaleUser(StandardSale sale_) public {
        sale = sale_;
        token = sale.token();
    }

    function() public payable {}

    function doBuy(uint wad) public {
        exec(sale, wad);
    }

    function doTransfer(address to, uint256 amount) public returns (bool) {
        return token.transfer(to, amount);
    }
}

contract TokenOwner {

    DSToken token;

    function setToken(DSToken token_) public {
        token = token_;
    }

    function doStop() public {
        token.stop();
    }

    function() public payable {}
}

contract TestableStandardSale is StandardSale {

    function TestableStandardSale(
        bytes32 symbol, 
        uint total, 
        uint forSale, 
        uint cap, 
        uint softCap, 
        uint timeLimit, 
        uint softCapTimeLimit,
        uint startTime,
        address multisig)
    StandardSale(
        symbol, 
        total, 
        forSale, 
        cap, 
        softCap, 
        timeLimit, 
        softCapTimeLimit,
        startTime,
        multisig) public {
        localTime = now;
    }

    uint public localTime;

    function time() internal returns (uint) {
        return localTime;
    }

    function addTime(uint extra) public {
        localTime += extra;
    }
}

contract StandardSaleTest is DSTest, DSExec {
    TestableStandardSale sale;
    DSToken token;
    TokenOwner owner;

    StandardSaleUser user1;
    StandardSaleUser user2;


    function setUp() {
        owner = new TokenOwner();
        sale = new TestableStandardSale(
            "TKN",
            10000 ether,
            8000 ether,
            1000 ether,
            900 ether,
            5 days,
            1 days,
            now + 1,
            owner);
        token = sale.token();

        owner.setToken(token);

        user1 = new StandardSaleUser(sale);
        exec(user1, 600 ether);

        user2 = new StandardSaleUser(sale);
        exec(user2, 600 ether);

    }

    function testSaleToken() public {
        assertEq(token.balanceOf(sale), 8000 ether);
    }

    function testOwnerToken() public {
        assertEq(token.balanceOf(owner), 2000 ether);
    }


    function testPublicBuy() public {
        sale.addTime(1 days);

        user1.doBuy(19 ether);
        assertEq(token.balanceOf(user1), 200000 * 19 ether);
        assertEq(owner.balance, 19 ether);

        exec(sale, 11 ether);
        assertEq(token.balanceOf(this), 200000 * 11 ether);
        assertEq(owner.balance, 30 ether);
    }

    function testClaimTokens() public {
        DSToken test = new DSToken("TST");
        test.mint(1 ether);
        test.push(sale, 1 ether);
        assertEq(test.balanceOf(this), 0);
        sale.transferTokens(this, 1 ether, test);
    }

    // TODO: testFailClaimTokens

    function testBuyManyTimes() public {
        exec(sale, 100 ether);
        assertEq(token.balanceOf(this), 200000 * 100 ether);

        exec(sale, 200 ether);
        assertEq(token.balanceOf(this), 200000 * 300 ether);

        exec(sale, 200 ether);
        assertEq(token.balanceOf(this), 200000 * 500 ether);
    }


    function testPostponeStartTime() public {

        assertEq(sale.startTime(), now );
        assertEq(sale.endTime(), now + 14 days);

        sale.setStartTime(now + 2 days);

        assertEq(sale.startTime(), now + 2 days);
        assertEq(sale.endTime(), now + 16 days);
    }

    function testHitSoftCap() public {
        exec(sale, 20000 ether);

        assertEq(sale.endTime(), now + 24 hours);
    }

    function testFinalize() public {

        // sell 30000 ether, remains 10000 ether
        exec(sale, 30000 ether);

        sale.addTime(14 days);

        assertEq(token.balanceOf(sale), 10000 * 200000 * 1 ether);
        assertEq(token.balanceOf(owner), ( (10 ** 11) * 84 / 100 ) * 1 ether + 40000 * 200000 ether);

        sale.finalize();

        assertEq(token.balanceOf(sale), 0 );
        assertEq(token.balanceOf(owner), ( (10 ** 11) * 84 / 100 + 10000 * 200000) * 1 ether + 40000 * 200000 ether);

        assertEq(owner.balance, 30000 ether);

    }

    function testTokenOwnershipAfterFinalize() public {

        sale.addTime(14 days);

        sale.finalize();
        owner.doStop();
    }

    function testTransferAfterFinalize() public {
        user1.doBuy(1 ether);
        assertEq(token.balanceOf(user1), 200000 * 1 ether);

        sale.addTime(14 days);
        sale.finalize();

        assert(user1.doTransfer(user2, 200000 * 1 ether));

        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), 200000 * 1 ether);

    }

    function testBuyExceedHardLimit() public {

        exec(sale, 39900 ether);

        // one 100 ether left, 200 ether will return
        user1.doBuy(300 ether);

        assertEq(token.balanceOf(user1), 200000 * 100 ether);
        assertEq(user1.balance, 500 ether);

        assertEq(sale.endTime(), now);
    }

    function testFailTransferBeforeFinalize() public {
        user1.doBuy(1 ether);
        assert(user1.doTransfer(user2, 200000 * 1 ether));
    }

    function testEndTimeAfterSoftLimit() public {

        // normal sell is 14 days
        assertEq(sale.endTime(), now + 14 days);

        // hit soft limit
        exec(sale, 20000 ether);
        assertEq(token.balanceOf(this), 200000 * 20000 ether);

        // 24 hours left for sell
        assertEq(sale.endTime(), now + 24 hours);
    }

    function testFailSoftLimit() public {

        exec(sale, 60000 ether);

        sale.addTime(24 hours);

        // sell is finished
        exec(sale, 1 ether);
    }

    function testFailHardLimit() public {

        // hit hard limit
        exec(sale, 40000 ether);

        // sell is finished
        exec(sale, 1 ether);
    }

    // tries to buy more than 500 eth
    function testFailUserBuyTooMuch() public {
        user1.doBuy(501 ether);
    }


    function testFailStartTooEarly() public {
        sale = new TestableStandardSale(
            "TKN",
            10000 ether,
            8000 ether,
            1000 ether,
            900 ether,
            5 days,
            1 days,
            now + 1,
            owner);
        exec(sale, 10 ether);
    }

    function testFailBuyAfterClose() public {
        sale.addTime(14 days);
        exec(sale, 10 ether);
    }
}
