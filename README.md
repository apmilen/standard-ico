# Standard Token Sale

This repository contains two standard [Dappsys](http://dappsys.info)-driven token sale contracts. The first one is a standard hard-capped and fixed-price token sale with a time limit and optional soft-cap. The second one adds in a whitelisted presale period where the sale operator can add a series of tranches (in terms of volume) that offer a better price than the public sale. Both contracts accept raw ETH (i.e. not ERC20 Wrapped-ETH) via the fallback function. 

## NOTICE

This software is distributed **without warranty**. I do accept liability for anyone's token sale. If you don't perform the necessary steps to register your token with the proper authorities, that's entirely your own fault. Please follow the law when selling financial instruments to the public.

## Reference

### IMPORTANT NOTE ON NUMERICAL TYPES

Any user-provided `uint` type that refers to an amount of tokens (e.g. a balance, the total supply, the number for sale, etc) or a price (e.g. the token price per ETH during the presale) assumes you are using a [Dappsys standard](https://blog.dapphub.com/ds-math/) `Wad` type. This means the contract assumes you will be representing a decimal number with 18 digits of precision as an integer. For example:

12 tokens would be 12000000000000000000

3.14159265 would be 3141592650000000000

It is very important that you create a proper Wad type number when providing data that references tokens or prices. Otherwise the token sale might work very differently that you are expecting. For example:

If you intend to create a presale period that offers tokens for a price of 8 tokens per ETH, but you create a `TwoStageSale` that sets `initPresalePrice` to `8` instead of `8000000000000000000`, the actual price would actually be 0.000000000000000008 tokens per ETH!

### StandardSale

The `StandardSale` contract is initialized with 9 parameters, in this order:

* bytes32 symbol

The symbol for the token you are making (e.g. "TKN" or "MKR"). You can optionally add a name once the token sale has completed and has been `finalized` by calling the `setName` function on the token. 

* uint total

This is the total number of 

* uint forSale
* uint cap
* uint softCap
* uint timeLimit
* uint softCapTimeLimit
* uint startTime
* address multisig