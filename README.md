# Blockchain Decentralized Exchange

Peer-to-peer marketplace for trading ETH into LRT (Lighter) in a non-custodial manner.
Includes availability to contirbute to liquidity pool to earn fee rewards based on percent share.

Based on Uniswap V1 structure.

# Setup
1) Run npm install --save-dev hardhat
2) Run npm install --save-dev @nomiclabs/hardhat-ethers ethers
3) Run npm install --save-dev @openzeppelin/contracts

# Deploy
1) Run npx hardhat node
2) **In a seperate terminal** run npx hardhat run --network localhost scripts/deploy_token.js &
   run --network localhost scripts/deploy_exchange.js
3) Open web_app/index.html in your browser

# Test
1) Choose current address in the top right
2) Add to liquidity pool or swap tokens (Only address 1 starts with both ETH and LRT)

CS 251 Project 4: DEX
