// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './token.sol';
import "hardhat/console.sol";

contract TokenExchange is Ownable {
    string public exchange_name = '';

    // TODO: paste token contract address here
    // e.g.address tokenAddr = 0x5bfe88a.....
    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    Token public token = Token(tokenAddr);                                

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    // Fee Pools
    uint private token_fee_reserves = 0;
    uint private eth_fee_reserves = 0;

    // struct for lp
    struct LP {
        uint shares;
        uint eth_fees;
        uint token_fees;
    }

    // Liquidity pool shares
    mapping(address => LP) private lps;

    // For Extra Credit only: to loop through the keys of the lps mapping
    address[] private lp_providers;      

    // Total Pool Shares
    uint private total_shares = 0;

    // liquidity rewards
    uint private swap_fee_numerator = 3;                
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    // For use with exchange rates
    uint private multiplier = 10**5;
    uint private exchangePrecisionDiff = 10**8;

    constructor() {}
    
    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens)
        external
        payable
        onlyOwner
    {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require (token_reserves == 0, "Token reserves was not 0");
        require (eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(amountTokens <= tokenSupply, "Not have enough tokens to create the pool");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;

        // Pool shares set to a large value to minimize round-off errors
        total_shares = 10**5;
        // Pool creator has some low amount of shares to allow autograder to run

        LP storage lp = lps[msg.sender];
        lp.shares = 100;
    }

    // For use for ExtraCredit ONLY
    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(index < lp_providers.length, "specified index is larger than the number of lps");
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================
    
    /* ========================= Liquidity Provider Functions =========================  */ 

    /* ========================= Liquidity Provider Functions =========================  */ 
    // Function findAmtShares returns the amount of shares associated with the given amount of eth
    function findAmtShares(uint ethAmt) public view returns (uint) {
        uint shares = (ethAmt * total_shares) / eth_reserves;
        return shares;
    }

    function print_lps() public view returns (bool) {
        console.log("");
        console.log("LPS");
        console.log("");
        console.log("total eth fees: ", eth_fee_reserves);
        console.log("total token fees: ", token_fee_reserves);
        for (uint i = 0; i < lp_providers.length; i++) {
            console.log("");
            LP storage lp = lps[lp_providers[i]];
            console.log("lp_provider: ", lp_providers[i]);
            console.log("shares: ", lp.shares);
            console.log("eth_fees: ", lp.eth_fees);
            console.log("token_fees (to 10^5): ", lp.token_fees);
        }
        console.log("");
        console.log("total shares: ", total_shares);
        console.log("");
        return true;
    }

    function ethToTokenRate() public view returns (uint) {
        uint rate = (eth_reserves * multiplier) / token_reserves;
        return rate;
    }

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(uint maxExchangeRate, uint minExchangeRate) 
        external 
        payable
    {
        // value is not negative and owns enough eth
        require(msg.value > 0, "Zero or Negative ETH");

        // Find equivalent amount of tokens given Eth amount
        uint tokensAmount = (msg.value * token_reserves) / eth_reserves;
        require(token.balanceOf(msg.sender) >= tokensAmount, "Insufficient token balance for liquidity");

        // Require rate has not slipped out of bounds
        uint rate = ethToTokenRate();
        require(rate - exchangePrecisionDiff <= maxExchangeRate, "Current rate above maxExchangeRate");
        require(rate + exchangePrecisionDiff >= minExchangeRate, "Current rate below minExchangeRate");

        console.log("ADDING LIQUIDITY: ", msg.sender);
        console.log("ETH ADDING: ", msg.value);
        console.log("TOKENS ADDING:", tokensAmount);

        token.transferFrom(msg.sender, address(this), tokensAmount); // transfer tokens to contract
        console.log("CONTRACT ETH: ", address(this).balance);
        console.log("CONTRACT TOKENS: ", token.balanceOf(address(this)));

        LP storage lp = lps[msg.sender];

        // Update total shares and lp shares
        uint newShares = findAmtShares(msg.value);
        total_shares += newShares;
        lp.shares += newShares;
        console.log("SHARES ADDED: ", newShares);

        // Update exchange state
        eth_reserves = address(this).balance;
        token_reserves = token.balanceOf(address(this));
        k = address(this).balance * token.balanceOf(address(this));

        // if lp provider is not already in the lp_provider array, add it
        bool found = false;
        for (uint i = 0; i < lp_providers.length; i++) {
            if (lp_providers[i] == msg.sender) {
                found = true;
                break;
            }
        }

        if (!found) {
            lp_providers.push(msg.sender); // Add to lp_providers array
        }

        print_lps();
    }

    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountETH, uint maxExchangeRate, uint minExchangeRate)
        public 
        payable
    {
        require(amountETH > 0, "Zero or Negative ETH");
        require(amountETH < eth_reserves, "Withdrawal would deplete ETH reserves");

        // Check token amount does now exceed token reserves
        uint tokensAmount = ((token_reserves - token_fee_reserves) * amountETH) / eth_reserves;
        require(tokensAmount < (token_reserves - token_fee_reserves), "Withdrawal would deplete token reserves");

        uint rate = ethToTokenRate();
        require(rate - exchangePrecisionDiff <= maxExchangeRate, "Current rate above maxExchangeRate");
        require(rate + exchangePrecisionDiff >= minExchangeRate, "Current rate below minExchangeRate");

        LP storage lp = lps[msg.sender];

        // Require that the LP has enough liquidity to remove this amount of ETH
        uint providerProportion = (lp.shares * multiplier) / total_shares;
        uint amountProportion = (amountETH * multiplier) / eth_reserves;
        require(providerProportion >= amountProportion, "LP has insufficient liquidity");

        // Require removing shares less than lp shares
        uint removedShares = findAmtShares(amountETH);
        require(removedShares <= lp.shares, "Cannot remove more shares than you have");

        // Find fee rewards for LP
        uint ethRewards = (removedShares * lp.eth_fees) / lp.shares;
        uint tokenRewards = ((removedShares * (lp.token_fees / multiplier)) / lp.shares);

        console.log("REMOVING SHARES: ", removedShares);
        console.log("ETH REWARDS: ", ethRewards);
        console.log("TOKEN REWARDS: ", tokenRewards);

        // transefer eth and tokens to msg.sender
        payable(msg.sender).transfer(amountETH + ethRewards);
        token.transfer(msg.sender, tokensAmount + tokenRewards);

        // update lp state
        lp.token_fees -= (removedShares * lp.token_fees) / lp.shares;
        lp.shares -= removedShares;
        lp.eth_fees -= ethRewards;

        // uopdate exchange state
        total_shares -= removedShares;
        eth_fee_reserves -= ethRewards;
        token_fee_reserves -= tokenRewards;

        // if shares depleted, remove lp from lp_provider's list
        bool remove = false;
        uint remove_index = 0;
        if (lp.shares == 0) {
            remove = true;
        }
        for (uint i = 0; i < lp_providers.length; i++) { // find index or lp to remove
            if (lp_providers[i] == msg.sender) {
                remove_index = i;
            }
        }
        if (remove) {        
            lp.eth_fees = 0;
            lp.token_fees = 0;
            removeLP(remove_index);
        }

        eth_reserves = address(this).balance;
        token_reserves = token.balanceOf(address(this));
        k = address(this).balance * token.balanceOf(address(this));
        print_lps();
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint maxExchangeRate, uint minExchangeRate)
        external
        payable
    {

        // find ETH:Token rate
        uint rate = ethToTokenRate();
        require(rate - exchangePrecisionDiff <= maxExchangeRate, "Current rate above maxExchangeRate");
        require(rate + exchangePrecisionDiff >= minExchangeRate, "Current rate below minExchangeRate");

        LP storage lp = lps[msg.sender];

        // proportion of user:total shares
        uint userProportion = (multiplier * lp.shares) / total_shares;
        uint maxEth = (userProportion * (eth_reserves - eth_fee_reserves)) / multiplier; // max eth withdrawable
        uint maxTokens = (userProportion * (token_reserves - token_fee_reserves)) / multiplier; // max token withdrawable

        require(maxEth < (eth_reserves - eth_fee_reserves), "Withdraw would deplete eth reserves to 0");
        require(maxTokens < (token_reserves - token_fee_reserves), "Withdraw would deplete eth reserves to 0");

        console.log("ETH FEES: ", lp.eth_fees);
        console.log("TOKEN FEES: ", lp.token_fees / multiplier);

        payable(msg.sender).transfer(maxEth + lp.eth_fees);
        token.transfer(msg.sender, maxTokens + (lp.token_fees / multiplier));

        // update pool shares and fees
        total_shares -= lp.shares;
        eth_fee_reserves -= lp.eth_fees;
        token_fee_reserves -= lp.token_fees / multiplier;

        // set lp state to 0
        lp.shares = 0;
        lp.eth_fees = 0;
        lp.token_fees = 0;

        // remove lp from lp_providers
        for (uint i = 0; i < lp_providers.length; i++) {
            if (lp_providers[i] == msg.sender) { // find index of lp to remove
                removeLP(i);
                break;
            }
        } 

        // update exchange state
        eth_reserves = address(this).balance;
        token_reserves = token.balanceOf(address(this));
        k = address(this).balance * token.balanceOf(address(this));

        print_lps();
    }

    /***  Define additional functions for liquidity fees here as needed ***/
    /* ========================= Swap Functions =========================  */ 

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens, uint minEthTokenExchangeRate)
        external 
        payable
    {
        require(amountTokens > 0, "Cannot swap a negative amount of tokens");
        require(amountTokens <= token.balanceOf(msg.sender), "Not enough tokens to make this swap");

        uint rate = ethToTokenRate();
        require(rate + exchangePrecisionDiff >= minEthTokenExchangeRate, "Current rate has moved above maxExchangeRate");
        
        uint fee = (swap_fee_numerator * amountTokens) / swap_fee_denominator;
        uint amountEth = eth_reserves - (k / (token_reserves + (amountTokens - fee)));
        require(amountEth < eth_reserves - eth_fee_reserves, "Insufficient reserves of ETH for the transaction");

        console.log("AMOUNT FEE TOKENS: ", amountEth);

        // Adjust user balances
        token.transferFrom(msg.sender, address(this), amountTokens);
        payable(msg.sender).transfer(amountEth);

        // for each address in lp_providers, add the fee to thier accrued_fees
        for (uint i = 0; i < lp_providers.length; i++) {
            address addr = lp_providers[i];
            LP storage lp = lps[addr];
            lp.token_fees += ((lp.shares * fee) * multiplier) / total_shares;
            console.log("Accrued token fees for ", addr, ": ", lp.token_fees);
        }

        // Adjust reserves
        token_reserves = token.balanceOf(address(this));
        eth_reserves = address(this).balance;
        token_fee_reserves += fee;

        print_lps();
    }

    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint maxExchangeRate)
        external
        payable 
    {

        require(msg.value > 0, "Cannot swap a negative amount of ETH");

        uint rate = ethToTokenRate();
        require(rate - exchangePrecisionDiff <= maxExchangeRate, "Current rate has moved above maxExchangeRate");
        
        // generate fee
        uint amountEth = msg.value;
        uint fee = (swap_fee_numerator * amountEth) / swap_fee_denominator;

        // covert eth to tokens
        uint amountTokens = token_reserves - (k / (eth_reserves + (amountEth-fee)));
        require(amountTokens > 0, "Cannot give back a negative token number");
        require(amountTokens < token_reserves - token_fee_reserves, "Not enough tokens in reserve to make swap");

        console.log("AMOUNT FEE ETH: ", fee);

        token.transfer(msg.sender, amountTokens);

        // for each address in lp_providers, add the eth fee based on shares
        for (uint i = 0; i < lp_providers.length; i++) {
            address addr = lp_providers[i];
            LP storage lp = lps[addr];
            lp.eth_fees += (lp.shares * fee) / total_shares;
        }

        token_reserves = token.balanceOf(address(this));
        eth_reserves = address(this).balance;
        eth_fee_reserves += fee;

        print_lps();
    }
}