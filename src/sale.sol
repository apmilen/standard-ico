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
            // because you can hit softCap before sale starts
            var x = time() >= startTime ? time() : startTime;
            endTime =  x + softCapTimeLimit;
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


contract TwoStageSale is StandardSale {

    mapping (address => bool) public presale;

    struct priceInfo {
        uint next;
        uint floor;
        uint price;
    }
    mapping(uint => priceInfo) public tranches;
    uint public size;

    uint public presaleStartTime;
    uint public preSaleCap;
    uint public preCollected;

    function TwoStageSale(
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
        
        tranches[size] = priceInfo(0, 0, initPresalePrice);
        size++;

        require(presaleStartTime_ < startTime_);
        presaleStartTime = presaleStartTime_;

        preSaleCap = preSaleCap_;
    }

    function setPresale(address who, bool what) public auth {
        presale[who] = what;
    }

    // can't set startTime after presale has started
    function setStartTime(uint startTime_) public auth {
        require(time() < presaleStartTime);
        startTime = startTime_;
        endTime = startTime + timeLimit;
    }

    // because some times operators pre-pre-sell their token
    function preDistribute(address who, uint val) public auth {
        require(time() < presaleStartTime);
        require(add(preCollected, val) <= preSaleCap);
        preBuy(who, val, false);
    }

    function addTranch(uint floor_, uint price_) public auth {

        require(tranches[size - 1].floor < floor_);
        tranches[size - 1].next = size;
        tranches[size] = priceInfo(0, floor_, price_);
        size++;
    }

    function preBuy(address who, uint val, bool send) internal {
        
        bool found = false;
        uint id = 0;
        uint count = 0;
        uint prev = 0;
        while (!found) {
            count++;

            if (tranches[id].floor > val) {
                found = true;
                id = prev;
            } else if (tranches[id].floor == val || count == size) {
                found = true;
            } else {
                prev = id;
                id = tranches[id].next;
            }

        }

        uint price = tranches[id].price;

        preCollected = add(preCollected, val);

        buy(price, who, val, send);
    }

    function() public payable stoppable note {

        require(time() >= presaleStartTime && time() < endTime);

        if (time() < startTime) {
            require(presale[msg.sender]);

            uint keep = msg.value;
            if (add(keep, preCollected) > preSaleCap) {
                keep = sub(preSaleCap, preCollected);
            }

            preBuy(msg.sender, keep, true);

            // return excess ETH to the user
            uint refund = sub(msg.value, keep);
            if(refund > 0) {
                exec(msg.sender, refund);
            }
        } else {
            buy(per, msg.sender, msg.value, true);
        }

    }
}
