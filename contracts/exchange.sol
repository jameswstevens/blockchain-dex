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

    function tokenToEthRate() public view returns (uint) {
        return (token_reserves * multiplier) / eth_reserves;
    }

    function ethToTokenRate() public view returns (uint) {
        return (eth_reserves * multiplier) / token_reserves;
    }

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(uint maxExchangeRate, uint minExchangeRate) 
        external 
        payable
    {
        LP storage lp = lps[msg.sender];

        console.log("Token reserves:", token_reserves);
        console.log("K value:", k);
        console.log("ETH reserves:", eth_reserves);
        console.log("User's shares", lp.shares);
        console.log("Total shares: ", total_shares);
        console.log("Add liquidity of amount : ", msg.value);

        // Require rate has not slipped out of bounds
        uint rate = ethToTokenRate();
        require(rate <= maxExchangeRate, "Current rate has moved above maxExchangeRate");
        require(rate >= minExchangeRate, "Current rate has moved below minExchangeRate");

        require(msg.value > 0, "Must add positive amount of liquidity");

        // Find equivalent amount of tokens given Eth amount
        uint tokensAmount = (msg.value * token_reserves) / eth_reserves;

        console.log("this equals tokensAmount:", tokensAmount);
        require(token.balanceOf(msg.sender) >= tokensAmount, "Sender does not have enough tokens to add that amount of liquidity");
        
        // Pay contract
        console.log("Before paying: ", token.balanceOf(msg.sender));
        token.transferFrom(msg.sender, address(this), tokensAmount);
        console.log("Contract after payment: ", token.balanceOf(address(this)));

        // Update liquidity
        uint newShares = findAmtShares(msg.value);
        total_shares += newShares;
        lp.shares += newShares;
        console.log("Shares to add: ", newShares);

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
        if (!found) lp_providers.push(msg.sender); // Add to lp_providers array
        
        console.log("After paying: ", token.balanceOf(msg.sender));
        console.log("Contract after payment: ", token.balanceOf(address(this)));
        console.log("Token reserves:", token_reserves);
        console.log("K value:", k);
        console.log("ETH reserves:", eth_reserves);
        console.log("Total shares: ", total_shares);
        console.log("User's shares", lp.shares);
    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountETH, uint maxExchangeRate, uint minExchangeRate)
        public 
        payable
    {
        LP storage lp = lps[msg.sender];

        uint rate = ethToTokenRate();
        require(rate <= maxExchangeRate, "Current rate has moved above maxExchangeRate");
        require(rate >= minExchangeRate, "Current rate has moved below minExchangeRate");

        require(amountETH > 0, "Must remove positive amount of liquidity");
        require(amountETH < eth_reserves, "Cannot deplete ETH reserves to 0");
        
        // Require that the LP has enough liquidity to remove this amount of ETH
        uint providerProportion = (lp.shares * multiplier) / total_shares;
        uint amountProportion = (amountETH * multiplier) / eth_reserves;
        require(providerProportion >= amountProportion, "LP has insufficient liquidity");

        uint tokensAmount = (token_reserves * amountETH) / eth_reserves;
        require(tokensAmount < token_reserves, "Cannot deplete token reserves to 0");
        console.log("this equals tokensAmount:", tokensAmount);

        // update liquidity and shares and rewards to give
        uint removedShares = findAmtShares(amountETH);
        uint ethRewards = (removedShares * lp.eth_fees) / total_shares;
        uint tokenRewards = (removedShares * lp.token_fees) / total_shares;
        total_shares -= removedShares; // remove shares from total
        eth_fee_reserves -= ethRewards;
        token_fee_reserves -= tokenRewards;

        lp.shares -= removedShares;

        // if shares depleted, set remove to true
        bool remove = false;
        uint remove_index = 0;
        if (lp.shares == 0) {
            remove = true;
        }

        for (uint i = 0; i < lp_providers.length; i++) {
            // remove taken fees from each lp
            LP storage _lp = lps[lp_providers[i]];
            _lp.eth_fees -= ethRewards;
            _lp.token_fees -= tokenRewards;
            if (lp_providers[i] == msg.sender) { // find index of lp to remove
                remove_index = i;
            }
        }

        if (remove) removeLP(remove_index); // if lp.shares = 0, remove lp from lp_providers array
        
        token.transfer(msg.sender, tokensAmount);
        payable(msg.sender).transfer(amountETH);

        eth_reserves = address(this).balance;
        token_reserves = token.balanceOf(address(this));
        k = address(this).balance * token.balanceOf(address(this));

        console.log("User balance: ", token.balanceOf(msg.sender));
        console.log("Token reserves:", token_reserves);
        console.log("K value:", k);
        console.log("ETH reserves:", eth_reserves);
        console.log("Total shares: ", total_shares);
        console.log("User's shares", lp.shares);
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint maxExchangeRate, uint minExchangeRate)
        external
        payable
    {

        LP storage lp = lps[msg.sender];

        // find ETH:Token rate
        uint rate = ethToTokenRate();
        require(rate <= maxExchangeRate, "Current rate has moved above maxExchangeRate");
        require(rate >= minExchangeRate, "Current rate has moved below minExchangeRate");

        // proportion of user:total shares
        uint userProportion = (multiplier * lp.shares) / total_shares;
        uint maxEth = (userProportion * eth_reserves) / multiplier; // max eth withdrawable
        uint maxTokens = (userProportion * token_reserves) / multiplier; // max token withdrawable
        require(maxEth < eth_reserves, "Cannot deplete eth reserves to 0");
        require(maxTokens < token_reserves, "Cannot deplete token reserves to 0");

        uint removedShares = findAmtShares(maxEth); // all shared being removed by user

        // given the percent user:total shares, reward eth and tokens based off fees accumulated during time as LP
        uint ethRewards = (removedShares * lp.eth_fees) / total_shares;
        uint tokenRewards = (removedShares * lp.token_fees) / total_shares;
        total_shares -= removedShares;
        eth_fee_reserves -= ethRewards;
        token_fee_reserves -= tokenRewards;

        console.log("Shares to remove: ", removedShares);
        console.log("ethRewards: ", ethRewards);
        console.log("tokenRewards: ", tokenRewards);

        // set shares to 0
        lp.shares = 0;

        uint remove_index = 0;
        for (uint i = 0; i < lp_providers.length; i++) {
            // remove taken fees from each lp
            LP storage _lp = lps[lp_providers[i]];
            _lp.eth_fees -= ethRewards;
            _lp.token_fees -= tokenRewards;
            if (lp_providers[i] == msg.sender) { // find index of lp to remove
                remove_index = i;
            }
        }
        removeLP(remove_index);

        console.log("User balance: ", token.balanceOf(msg.sender));
        // Pay the user
        token.transfer(msg.sender, maxTokens);
        payable(msg.sender).transfer(maxEth);

        eth_reserves = address(this).balance;
        token_reserves = token.balanceOf(address(this));
        k = address(this).balance * token.balanceOf(address(this));
        console.log("User balance: ", token.balanceOf(msg.sender));

        console.log("Token reserves:", token_reserves);
        console.log("K value:", k);
        console.log("ETH reserves:", eth_reserves);
        console.log("User's shares", lp.shares);
        console.log("Total shares: ", total_shares);
    }
    /***  Define additional functions for liquidity fees here as needed ***/


    /* ========================= Swap Functions =========================  */ 

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens, uint maxExchangeRate)
        external 
        payable
    {

        console.log("Token reserves:", token_reserves);
        console.log("K value:", k);
        console.log("ETH reserves:", eth_reserves);
        console.log("Total shares: ", total_shares);
        console.log("swapTokensForETH of tokenAmt: ", amountTokens);

        require(amountTokens <= token.balanceOf(msg.sender), "Not enough tokens to make this swap");
        require(amountTokens > 0, "Must swap a positive amount of tokens");

        uint rate = tokenToEthRate();
        require(rate <= maxExchangeRate, "Current rate has moved above maxExchangeRate");

        
        uint fee = (swap_fee_numerator * amountTokens) / swap_fee_denominator;
        token_fee_reserves += fee;

        uint amountEth = eth_reserves - (k / (token_reserves + (amountTokens - fee)));

        
        console.log("Fee: ", fee); 

        // for each address in lp_providers, add the fee to thier accrued_fees
        for (uint i = 0; i < lp_providers.length; i++) {
            address addr = lp_providers[i];
            LP storage lp = lps[addr];
            lp.token_fees += fee;
            console.log("Accrued token fees for ", addr, ": ", lp.token_fees);
        }

        require(amountEth < eth_reserves, "Insufficient reserves of ETH for the transaction");
        console.log("Amount to Eth: ", amountEth);

        // Adjust user balances
        console.log("Balance of sender: ", token.balanceOf(msg.sender));
        token.transferFrom(msg.sender, address(this), amountTokens);
        payable(msg.sender).transfer(amountEth);

        // Adjust reserves
        token_reserves = token.balanceOf(address(this));
        eth_reserves = address(this).balance;
        

        console.log("Token reserves:", token_reserves);
        console.log("K value:", k);
        console.log("ETH reserves:", eth_reserves);
        console.log("Total shares: ", total_shares);
    }



    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint maxExchangeRate)
        external
        payable 
    {
        console.log("SwapETHForTokens", msg.value);
        console.log("Token reserves:", token_reserves);
        console.log("K value:", k);
        console.log("ETH reserves:", eth_reserves);
        console.log("maxExchangeRate: ", maxExchangeRate);

        require(msg.value > 0, "Cannot swap a negative amount");

        uint rate = ethToTokenRate();
        console.log("currentRate: ", rate);
        console.log("max rate", maxExchangeRate);
        require(rate <= maxExchangeRate, "Current rate has moved above maxExchangeRate");

        uint amountEth = msg.value;
        uint fee = (swap_fee_numerator * amountEth) / swap_fee_denominator;
        eth_fee_reserves += fee;

        console.log("Fee: ", fee);  

        // for each address in lp_providers, add the fee to thier accrued_fees
        for (uint i = 0; i < lp_providers.length; i++) {
            address addr = lp_providers[i];
            LP storage lp = lps[addr];
            lp.eth_fees += fee;
            console.log("Accrued token fees for ", addr, ": ", lp.eth_fees);
        }

        uint amountTokens = token_reserves - (k / (eth_reserves + (amountEth-fee)));
        console.log("TokensAmount  = ", amountTokens);
        require(amountTokens > 0, "Cannot give back a negative token number");
        require(amountTokens < token_reserves, "Not enough tokens in reserve to make swap");

        token.transfer(msg.sender, amountTokens);

        console.log("Swapper eth balance: ", msg.sender.balance);
        console.log("Swapper token balance:", token.balanceOf(msg.sender));

        token_reserves = token.balanceOf(address(this));
        eth_reserves = address(this).balance;

        console.log("Token reserves:", token_reserves);
        console.log("K value:", k);
        console.log("ETH reserves:", eth_reserves);
    }
}
