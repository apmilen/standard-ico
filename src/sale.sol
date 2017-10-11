pragma solidity ^0.4.17;

import "ds-token/token.sol";
import "ds-auth/auth.sol";
import "ds-math/math.sol";
import "ds-note/note.sol";
import "ds-exec/exec.sol";
import "ds-stop/stop.sol";

contract StandardSale is DSNote, DSStop, DSMath, DSExec {

    DSToken public token;

    uint public total;
    uint public forSale;

    uint public cap;
    uint public softCap;

    uint public timeLimit;
    uint public softCapTimeLimit;
    uint public startTime;
    uint public endTime;

    address public multisig;

    uint public per; // Token per ETH
    uint public collected;

    function StandardSale(
        bytes32 symbol, 
        uint total_, 
        uint forSale_, 
        uint cap_, 
        uint softCap_, 
        uint timeLimit_, 
        uint softCapTimeLimit_,
        uint startTime_,
        address multisig_) public {
        
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

        per = wdiv(forSale, cap);

        token.mint(total);
        token.push(multisig, sub(total, forSale));
        token.stop();
    }

    function time() internal returns (uint) {
        return block.timestamp;
    }

    // can't set startTime after sale has started
    function setStartTime(uint startTime_) public auth {
        require(time() < startTime);
        startTime = startTime_;
        endTime = startTime + timeLimit;
    }

    function buy(uint price) internal {
        uint requested = wmul(msg.value, price);
        uint keep = msg.value;

        if (requested > token.balanceOf(this)) {
            requested = token.balanceOf(this);
            keep = wdiv(requested, price);
            endTime = time();
        }

        if (collected < softCap && add(collected, keep) >= softCap) {
            endTime = time() + softCapTimeLimit;
        }

        collected = add(collected, keep);

        token.start();
        token.push(msg.sender, requested);
        token.stop();

        exec(multisig, keep); // send collected ETH to multisig

        // return excess ETH to the user
        uint refund = sub(msg.value, keep);
        if(refund > 0) {
            exec(msg.sender, refund);
        }
    }

    function() public payable stoppable note {

        require(time() >= startTime && time() < endTime);
        buy(per);
    }

    function finalize() public auth {
        require(time() >= endTime);

        // enable transfer
        token.start();

        // transfer undistributed Token
        token.push(multisig, token.balanceOf(this));

        // owner -> multisig
        token.setOwner(multisig);
    }

    // because sometimes people get a little too excited and send the wrong token
    function transferTokens(address dst, uint wad, address tkn_) public auth {
        ERC20 tkn = ERC20(tkn_);
        tkn.transfer(dst, wad);
    }
}


contract WhitelistSale is StandardSale {

    mapping (address => bool) public whitelist;

    struct bonusInfo {
        uint next;
        uint line;
        uint bonus;
    }
    mapping(uint => bonusInfo) public tranches;
    uint head;
    uint size;

    function setWhitelist(address who, bool what) public auth {
        whitelist[who] = what;
    }

    // TODO
    //function preDistribute(){}

    function addTranch(uint line_, uint bonus_) public auth {

        uint id = head;
        uint prevId = 0;
        uint count = 0;
        while(tranches[id].line < line_ && count < size) {
            prevId = id;
            id = tranches[id].next;
            count++;
        }

        tranches[size] = bonusInfo(id, line_, bonus_);
        tranches[prevId].next = size;

        if (count == 0) {
            head = size;
        }

        size++;
    }

    function removeTranch(uint axe) public auth {
        uint id = head;

        while (tranches[id].next != axe) {
            id = tranches[id].next;
        }

        tranches[id].next = tranches[axe].next;
        delete tranches[axe];
    }

    function() public payable stoppable note {

        require(time() < endTime);

        if (time() < startTime && whitelist[msg.sender]) {
            bool found = false;
            uint id = head;
            while (!found) {
                found = tranches[id].line >= msg.value;
                if (!found) {
                    id = tranches[id].next;
                }
            }
            buy(tranches[id].bonus);
        } else {
            buy(per);
        }

    }
}
