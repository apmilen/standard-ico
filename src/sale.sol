pragma solidity ^0.4.17;

import "ds-token/token.sol";
import "ds-auth/auth.sol";
import "ds-math/math.sol";
import "ds-note/note.sol";

contract StandardSale is DSAuth, DSMath, DSNote {

    DSToken token;

    uint total;
    uint forSale;

    uint cap;
    uint softCap;

    uint timeLimit;
    uint softCapTimeLimit;
    uint start;
    uint end;

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
        uint start_,
        address multisig_) {
        
        token = new DSToken(symbol);

        total = total_;
        forSale = forSale_;
        cap = cap_;
        softCap = softCap_;
        timeLimit = timeLimit_;
        softCapTimeLimit = softCapTimeLimit_;
        start = start_;
        end = start + timeLimit;

        multisig = multisig_;

        per = wdiv(total, cap);

        token.mint(total);
        token.push(sub(total, forSale), multisig);
        token.stop();
    }

    function time() returns (uint) {
        return block.timestamp;
    }

    // can't set start after sale has started
    function setStart(uint start_) auth {
        require(time() < start);
        start = start_;
        end = start + timeLimit;
    }

    function buy(uint price) {
        uint requested = wmul(msg.value, price);

        if (requested > token.balanceOf(this)) {

        }
    }

    function() payable stoppable note {

        require(time() > start && time() < end);
        buy();
    }
}
