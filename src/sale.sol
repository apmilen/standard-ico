pragma solidity ^0.4.17;

import "ds-token/token.sol";
import "ds-auth/auth.sol";
import "ds-math/math.sol";
import "ds-note/note.sol";
import "ds-exec/exec.sol";
import "ds-stop/stop.sol";

contract StandardSale is DSNote, DSStop, DSMath, DSExec {

    DSToken token;

    uint total;
    uint forSale;

    uint cap;
    uint softCap;

    uint timeLimit;
    uint softCapTimeLimit;
    uint startTime;
    uint endTime;

    address multisig;

    uint per; // Token per ETH
    uint sold;

    function StandardSale(
        bytes32 symbol, 
        uint total_, 
        uint forSale_, 
        uint cap_, 
        uint softCap_, 
        uint timeLimit_, 
        uint softCapTimeLimit_,
        uint startTime_,
        address multisig_) {
        
        token = new DSToken(symbol);

        total = total_;
        forSale = forSale_;
        cap = cap_;
        softCap = softCap_;
        timeLimit = timeLimit_;
        softCapTimeLimit = softCapTimeLimit_;
        startTime = startTime_;
        endTime = startTime + timeLimit;

        multisig = multisig_;

        per = wdiv(total, cap);

        token.mint(total);
        token.push(multisig, sub(total, forSale));
        token.stop();
    }

    function time() returns (uint) {
        return block.timestamp;
    }

    // can't set start after sale has started
    function setStartTime(uint startTime_) auth {
        require(time() < startTime);
        startTime = startTime_;
        endTime = startTime + timeLimit;
    }

    function buy(uint price) {
        uint requested = wmul(msg.value, price);

        if (requested > token.balanceOf(this)) {

        }
    }

    function() payable stoppable note {

        require(time() > startTime && time() < endTime);
    }
}
