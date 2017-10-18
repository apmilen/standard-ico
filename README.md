
# Standard Token Sale

This repository contains two standard [Dappsys](http://dappsys.info)-driven token sale contracts. The first one is a hard-capped and fixed-price token sale with a time limit and optional soft-cap. The second one adds in a whitelisted presale period where the sale operator can add a series of tranches (in terms of volume) that offer a better price than the public sale. Both contracts accept raw ETH (i.e. not ERC20 Wrapped-ETH) via the fallback function. 

# NOTICE

This software is distributed **without warranty**. I do not accept liability for anyone's token sale. If you don't perform the necessary steps to register your token with the proper authorities, that's entirely your own fault. Please follow the law when selling financial instruments to the public.

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

**bytes32 symbol**

The symbol for the token you are making (e.g. "TKN" or "MKR"). You can optionally add a name once the token sale has completed and has been `finalized` by calling the `setName` function on the token. 

**uint total**

This is the total number of tokens that will be created. This number includes those that will be sold and those that will be sent off to the sale's administrators. This parameter expects a Wad type.

**uint forSale**

This is the number of tokens that will be sold. This parameter expects a Wad type.

**uint cap**

This is the total amount of ETH that will be accepted before terminating the sale. This number is divided by the `forSale` parameter to create the `per` state variable, which is the number of tokens sold per ETH. This means that `per` is the price. The system subtracts `forSale` from `total` and sends the remaining tokens to the `multisig` address, assuming they will be used at some later time. This parameter expects a Wad type.

**uint softCap**

This is the total amount of ETH that needs to be accepted before changing the end time of the sale. When `softCap` ETH has been collected, the end time of the sale will change to `softCapTimeLimit` seconds into the future. For example:

Suppose `softCapTimeLimit` is `1 day` and the sale time limit is `5 days`. If the sale starts on October 1st, then it will end on October 6th. If on October 2nd the sale collects `softCap` ETH, then the new end time will be October 3rd. 

This parameter expects a Wad type.

If you don't want to include a soft-cap, then just set this number equal to `cap`.
 
**uint timeLimit**

This is the total length of the sale in seconds. The sale will end `timeLimit` seconds after `startTime` unless the soft cap is breached or all the tokens are sold.

**uint softCapTimeLimit**

This is the new time limit that gets enforced after `softCap` ETH is collected. This time period begins in the same transaction that breaches the soft cap, rather than the start time of the whole sale.

**uint startTime**

This is the timestamp that commences the sale, in seconds. It can be postponed using the `postpone` function.

**address multisig**

This is address that is considered the sale operator. The token's ownership is transferred to this address when the sale is finalized, along with any excess tokens that are created and not sold or that remain unsold when the sale concludes.

### Functions

#### setOwner

This function will change the sale's `owner` variable. The owner is allowed to call functions that are protected by the `auth` modifier, such as `postpone` or `finalize`

`function setOwner(address owner_) public auth`

#### stop

This function will stop the functions that are protected by the `stoppable` modifier. In the case of this sale, The fallback function is the only user-accessible entrypoint, thus it is the only stoppable function.

`function stop() public auth note`

#### start

This function will start the functions that are protected by the `stoppable` modifier. In the case of this sale, The fallback function is the only user-accessible entrypoint, thus it is the only stoppable function.

`function start() public auth note`

#### postpone

This function can be used to delay the start and end time of the sale. It can only be called by the sale's owner (i.e. whoever deployed the contract or whoever they set the owner to) before the sale has started.

`function postpone(uint startTime_) public auth`

#### finalize

This function should be called when the sale has completed. It will transfer ownership of the token to the `multisig` address. It will also send any unsold tokens to the `multisig` address.

`function finalize() public auth`

#### transferTokens

This function can transfer any tokens that the contract has erroneously received. Sometimes users mishandle their wallets and send an ERC20 token to the contract by mistake. This function allows the sale adminstrators to help out and return the tokens.

`function transferTokens(address dst, uint wad, address tkn_) public auth`

## TwoStageSale

### Set up

The `TwoStageSale` contract is initialized with 12 parameters, in this order:

**bytes32 symbol**

See above.

**uint total**

See above.

**uint forSale**

See above.

**uint cap**

See above.

**uint softCap**

See above.
 
**uint timeLimit**

See above.

**uint softCapTimeLimit**

See above.

**uint startTime**

See above.

**address multisig**

See above.

**uint presaleStartTime**

This is the timestamp that commences the presale, in seconds. The `postpone` and `preDistribute` functions cannot be called after the presale starts.

**uint initPresalePrice**

This price is used to populate the first tranch (which has a floor of 0). We assume that the user wants at least one tranch, or else they would use the `StandardSale`. Tranches are described in detail below under the `addTranch` function.

**uint preSaleCap**

This is the total amount of ETH that will be accepted during the presale. Any ETH that is spoofed with the `preDistribute` function is included in this total as well.

This parameter expects a Wad type.

If you don't want to include a presale-cap, then just set this number equal to `cap`.

### Functions

Since `TwoStageSale` is a child class of `StandardSale` all the functions listed above are also available here. Any additional or overriden functions are listed below:

#### setPresale

This function will modify the presale whitelist for the `who` address. You can use this function to approve an address by setting `what` to `true`, or you can exclude an already approved address by setting `what` to `false`.

`function setPresale(address who, bool what) public auth`

#### postpone

This function can be used to delay the start and end time of the **public** sale. It can only be called by the sale's owner (i.e. whoever deployed the contract or whoever they set the owner to) before the **presale** has started (this is the only difference between this function and the `StandardSale` `postpone` function).

`function postpone(uint startTime_) public auth`

#### preDistribute

This function is used to "spoof" presale activity. If the sale operator accepted ETH before the start of the sale in exchange for a promise of tokens, they can use this function to record that activity as if it had occured during the presale. Sale operators usually have to accept ETH beforehand in order to pay for expenses related to the token sale, such as marketing or legal. The `val` parameter specifies how much ETH the `who` address contributed beforehand. Note: this will give the `who` address the same deal as those who contribute during the presale. If the sale operators promised a different price, they should not consider those tokens for sale and instead distribute them from the excess tokens that get created upon initialization. 

`function preDistribute(address who, uint val) public auth`

#### addTranch

This function will add a new tranch to the presale. A tranch is a window of potential ETH contributions that corresponds to a specific price. For example:

* contributions between 00 and 09.999999999999999999 ETH get a 1% better price
* contributions between 10 and 29.999999999999999999 ETH get a 3% better price
* contributions between 30 and 59.999999999999999999 ETH get a 5% better price
* contributions between 60 and `preSaleCap` get an 8% better price

Notice that the round number is the floor value for each tranch in the example above. This is because tranches are denominated by their floor value. When a contributer sends ETH to the presale, the contract loops through each tranch until it finds a floor value that is greater than the contributed ETH or reaches the end (it then chooses the previous or last tranch, respectively). Importantly, this means that during the presale the fallback function does _not have constant time complexity_. There is no contract enforced limit on how many tranches the operators can add, but it is technically possible to add enough that large contributors will run out of gas before the fallback function can find their right tranch. In practice it is very unlikely that anyone will encounter this problem, as sale operators should usually only need to add about six tranches or so.

As the name suggests, this function is append only. This is in the interest of simplicity and keeping the function limited to constant time complexity. The contract will ensure that each new tranch has a floor that is higher than the current end of the list. 

This `price` parameter expects a Wad type. The contract does not enforce any rules about the `price` parameter (i.e. it doesn't make sure that each new tranch is a better deal than the last), so use common sense when adding your tranches or you will have a lot of angry contributors to deal with. 

`function appendTranch(uint floor_, uint price_) public auth`

### Important note on the TwoStageSale hard-cap 

If any tokens are sold during the presale at a price that's better than the value of `per`, then `cap` will no longer be the hard cap of the sale. This is because `per` is calculated as `forSale` divided by `cap`, but if tokens are sold at a better price during the presale then `remaining_tokens * per` will be less than `cap`. This means the new cap will be `remaining_tokens * per`. An example:

```
forSale is 10000 TKN
cap is 1000 ETH
per is forSale/cap = 10 TKN/ETH

6000 TKN are sold for 500 ETH during the presale
At the start of the public sale there are 4000 TKN for sale at a price of 10 TKN/ETH
If all are sold, the contract will collect 400 ETH
The total ETH collected will be 900 ETH
```

The author chose this format in the interest of simplicity and continuous contract architecture. If you just want the presale component to guarantee access for certain address rather than give a better price, setting `initPresalePrice` to `per` will cause `cap` to actually serve as the hard-cap.

## Provocative Opinions

1. If your token is only used to pay for services in your dapp, it is worse than useless. The author of this contract works for a [stablecoin project](https://makerdao.com) and will likely replace your dapp with a Dai-driven version within a few years. Please either try to come up with a better idea or stay away from smart contract development.

2. This token sale is intentionally boring in an effort to cover the requirements of as many sale operators as possible. It incentivizes needlessly high gas fees by rewarding the initial participants with the opportunity to "flip" these tokens on the secondary market. So lame! Please consider a more interesting and fair sale format such as an auction or continuous token sale model instead of using this contract.
