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

    function buy(uint price, address who, uint val, bool send) internal {
        uint requested = wmul(val, price);
        uint keep = val;

        if (requested > token.balanceOf(this)) {
            requested = token.balanceOf(this);
            keep = wdiv(requested, price);
        }

        token.start();
        token.push(who, requested);
        token.stop();

        if (token.balanceOf(this) == 0) {
            endTime = time();
        } else if (collected < softCap && add(collected, keep) >= softCap) {
            endTime = time() + softCapTimeLimit;
        }

        collected = add(collected, keep);

        if (send) {
            exec(multisig, keep); // send collected ETH to multisig
        }

        // return excess ETH to the user
        uint refund = sub(val, keep);
        if(refund > 0 && send) {
            exec(who, refund);
        }
    }

    function() public payable stoppable note {

        require(time() >= startTime && time() < endTime);
        buy(per, msg.sender, msg.value, true);
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

    mapping (address => bool) public whitelist; // presale
    //mapping (address => bonusInfo) public deals;

    struct bonusInfo {
        uint next;
        uint floor;
        uint bonus; // price
    }
    mapping(uint => bonusInfo) public tranches;
    uint head;
    uint tail;
    uint size;

    uint presaleStartTime;
    uint preSaleCap;
    uint preCollected;

    function WhitelistSale(
        bytes32 symbol, 
        uint total_, 
        uint forSale_, 
        uint cap_, 
        uint softCap_, 
        uint timeLimit_, 
        uint softCapTimeLimit_,
        uint startTime_,
        address multisig_,
        uint presaleStartTime_,
        uint initPresalePrice,
        uint preSaleCap_) 
    StandardSale(
        symbol, 
        total_, 
        forSale_, 
        cap_, 
        softCap_, 
        timeLimit_, 
        softCapTimeLimit_,
        startTime_,
        multisig_) public {
        
        tranches[size] = bonusInfo(0, 0, initPresalePrice);
        size++;

        require(presaleStartTime_ < startTime_);
        presaleStartTime = presaleStartTime_;

        require(preSaleCap_ < softCap_);
        preSaleCap = preSaleCap_;
    }

    function setWhitelist(address who, bool what) public auth {
        whitelist[who] = what;
    }

    // because some times operators pre-pre-sell their token
    function preDistribute(address who, uint val) public auth {
        require(time() < presaleStartTime);
        preBuy(who, val, false);
    }

    function addTranch(uint floor_, uint bonus_) public auth {

        require(tranches[tail].floor < floor_);
        tranches[tail].next = size;
        tranches[size] = bonusInfo(0, floor_, bonus_);
        size++;
    }

    function preBuy(address who, uint val, bool send) internal {
        
        require(whitelist[msg.sender]);
        require(preCollected < preSaleCap);
        
        bool found = false;
        uint id = head;
        uint count = 0;
        while (!found && count < size) {
            found = tranches[id].floor >= val; // TODO
            if (!found) {
                id = tranches[id].next;
            }
            count++;
        }

        uint price = tranches[id].bonus;

        uint keep = val;
        if (add(val, preCollected) > preSaleCap) {
            keep = sub(preSaleCap, preCollected);
        }

        preCollected = add(preCollected, keep);

        buy(price, who, keep, send);

        // return excess ETH to the user
        uint refund = sub(val, keep);
        if(refund > 0 && send) {
            exec(who, refund);
        }
    }

    function() public payable stoppable note {

        require(time() >= presaleStartTime && time() < endTime);

        if (time() < startTime) {
            preBuy(msg.sender, msg.value, true);
        } else {
            buy(per, msg.sender, msg.value, true);
        }

    }
}
