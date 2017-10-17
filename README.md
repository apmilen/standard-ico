
This repository contains two standard [Dappsys](http://dappsys.info)-driven token sale contracts. The first one is a standard hard-capped and fixed-price token sale with a time limit and optional soft-cap. The second one adds in a whitelisted presale period where the sale operator can add a series of tranches (in terms of volume) that offer a better price than the public sale. Both contracts accept raw ETH (i.e. not ERC20 Wrapped-ETH) via the fallback function. 

# NOTICE

This software is distributed **without warranty**. I do accept liability for anyone's token sale. If you don't perform the necessary steps to register your token with the proper authorities, that's entirely your own fault. Please follow the law when selling financial instruments to the public.

# Reference

## IMPORTANT NOTE ON NUMERICAL TYPES

The contract assumes that any user-provided `uint` type that refers to an amount of tokens (e.g. a balance, the total supply, the number for sale, etc), ETH (e.g. `msg.value`), or a price (e.g. the token price per ETH during the presale) is a [Dappsys standard](https://blog.dapphub.com/ds-math/) `Wad` type. This means the contract assumes you will be representing a decimal number with 18 digits of precision as an integer. For example:

12 tokens would be 12000000000000000000

3.14159265 tokens would be 3141592650000000000

It is very important that you create a proper Wad type number when providing data that references tokens or prices. Otherwise the token sale might work very differently that you are expecting. For example:

If you intend to create a presale period that offers tokens for a price of 8 tokens per ETH, but you create a `TwoStageSale` that sets `initPresalePrice` to `8` instead of `8000000000000000000`, the actual price would actually be 0.000000000000000008 tokens per ETH!

## StandardSale

### Set up

The `StandardSale` contract is initialized with 9 parameters, in this order:

* **bytes32 symbol**

The symbol for the token you are making (e.g. "TKN" or "MKR"). You can optionally add a name once the token sale has completed and has been `finalized` by calling the `setName` function on the token. 

* **uint total**

This is the total number of tokens that will be created. This number includes those that will be sold and those that will be sent off to the sale's administrators. This parameter expects a Wad type.

* **uint forSale**

This is the number of tokens that will be sold. This parameter expects a Wad type.

* **uint cap**

This is the total amount of ETH that will be accepted before terminating the sale. This number is divided by the `forSale` parameter to create the `per` state variable, which is the number of tokens sold per ETH. This means that `per` is the price. The system subtracts `forSale` from `total` and sends the remaining tokens to the `multisig` address, assuming they will be used at some later time.

* **uint softCap**

This is the total amount of ETH that needs to be accepted before changing the end time of the sale. When `softCap` ETH has been collected, the end time of the sale will change to `softCapTimeLimit` seconds into the future. For example:

Suppose `softCapTimeLimit` is `1 day` and the sale time limit is `5 days`. If the sale starts on October 1st, then it will end on October 6th. If on October 2nd the sale collects `softCap` ETH, then the new end time will be October 3rd.
 
* **uint timeLimit**

This is the total length of the sale in seconds. The sale will end `timeLimit` seconds after `startTime` unless the soft cap is breached or all the tokens are sold.

* **uint softCapTimeLimit**

This is the new time limit that gets enforced after `softCap` ETH is collected. This time period begins in the same transaction that breaches the soft cap, rather than the start time of the whole sale.

* **uint startTime**

This is the timestamp that commences the sale, in seconds. It can be postponed using the `postpone` function.

* **address multisig**

This is address that is considered the sale operator. The token's ownership is transferred to this address when the sale is finalized, along with any excess tokens that are created and not sold or that remain unsold when the sale concludes.

### Functions

#### postpone

This function can be used to delay the start and end time of the sale. It can only be called by the sale's owner (usually whoever deployed the contract or whoever they set the owner to) before the sale has started.

**Signature:** `function postpone(uint startTime_) public auth`

#### finalize

This function should be called when the sale has completed. It will transfer ownership of the token to the `multisig` address. It will also send any unsold tokens to the `multisig` address.

**Signature:** `function finalize() public auth`

#### transferTokens

This function can transfer any tokens that the contract has erroneously received. Sometimes users mishandle their wallets and send an ERC20 token to the contract by mistake. This function allows the sale adminstrators to help out and return the tokens.

**Signature:** `function transferTokens(address dst, uint wad, address tkn_) public auth`
