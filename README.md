# Quiver contracts

Repo contains all the work done for quiver smart contract development work.

## QREP ERC20 / BEP20 contract
Reputation token is not transferable for regular users.
Only governance users or initial admin user has possibility for transfer.

## QSTK ERC20 / BEP20 contract

QSTK stands for Quiver Stock, Quiver stock is infinitely mintable by providing stable coins, for now, we stick on USDT.
Initial supply for QSTK token is 300,000,000.
There are possibilities to mint / burn, total supply can't go under initial supply.
As more tokens are minted, QSTK token mint price goes up and more tokens are burnt price goes down inside contract. 
The mechanism for this could be 
```
CONTRACT_USDT_BALANCE = NEW_MINT_AFTER_INITIAL_SUPPLY ^ log(NEW_MINT_AFTER_INITIAL_SUPPLY)
```

At a stage, we might need to stop minting for our ERC20 and BEP20 as users' request. We need to add `stopMint() onlyAdmin` function.

## QNFT ERC721 contract

### Background

Quiver Emotional NFT is an "investment emotion NFT".

Each NFT is a character like **whale, dragon, fish, deer, bear** and it has 5 emotions - 1 image is assigned per emotion. The emotions are **Angry, Worry, Normal, Rest, Happy**.

As it's an investment emotion NFT, each NFT has its favorite coin. One NFT could only have a single favorite coin and NFT should change its emotion by its favorite coin's price change. The visualization from price change is done on frontend. Contract just stores all the possible NFT emotion images and default image index for listing. Users can select their favorite creature as part of a mint process. If the person is interested in BTC and ETH, he can purchase BTC-NFT and ETH-NFT that change their emotions by BTC and ETH price change.

Another cool feature is that NFT can provide an early purchase of locked QSTK. When user mint, users buy locked QSTK as part of the process and they are able to withdraw it after the lock period passes.

To incentivize users, we offer a cheap price if duration is longer. There's a private sale price in ETH registered inside the contract. It is meant to be $0.01.

And by duration, there are mint amount restrictions by introducing min and max amounts.

NFT miners should pay in ETH for image price and QSTK token price. If a user selected an image which is worth $80 and bought a 6 month lock 10000 QSTK token, he/she should pay $80 + 10000 x $0.01 x 80% that is $160.

### Emotional NFT fields

1. Image set
2. Background set
3. Favorite coin
4. Lock Option
5. QSTK amount - the locked amount of qstk tokens
6. Default image index - index of image to show on listing website
7. Created time - the NFT creation date
8. Withdrawn - if qstk is withdrawn already
9. Metadata

- Name - name that NFT minter want to give to the NFT
- Color - NFT image color
- Story - story that NFT minter want to put for the NFT

10. Creator information (minter)
- Creator Address - NFT creator address
- Creator Name - NFT creator name

### NFT mint params

1. Image set id
2. Background set id
3. Favorite coin
4. Lock Option
5. QSTK amount to purchase
6. Default image index
7. Name
8. Creator name
9. Color
10. Story

### NFTs iteration

1. Apps should be able to fetch all the Ids of available NFTs (starts from 1)
2. Apps should be able to fetch data of the NFTs by id
3. Apps should be able to get default image ( image to show on listings)

### NFT upgrade
We need NFT upgrade as the number of NFTs are restricted and no more could be minted. Anyone who has ownership of NFT should be able to change a few attributes.

1. Image set to different one - user needs to pay for image mint price
2. Background set to different one - this is for free
3. Reset favorite coin to different one - user needs to pay for favorite coin mint price

### NFT transfer
 NFT should be able to be transferred between users so that it can be sold / bought on marketplaces or be sent to friends.

1. Change ownership of the NFT
2. Change voting power of NFT sender and receiver
3. Change vote result to set DAO multi-sig address to withdraw ETH

### QSTK token distribution on NFT
#### Total QSTK tokens put

- Supply QSTK tokens to the contract
- Only supplied tokens should be able to be sold

#### Free QSTK allocations

- Free allocations are set by admin
- Free allocation total amount - managed when admin change individual's allocation
- Free allocation total distributed amount - modified when a user use free allocation while minting NFT

#### QSTK token lock on NFTs - Users can withdraw QSTK after lock duration pass
#### QSTK token address upgrade ability

- Before token upgrade, admin should supply same amount of QSTK token to the contract while upgrade or before upgrade
- Upgrade function should check `new_QSTK` amount is bigger than `old_QSTK` amount

### User paid ETH distribution

1. 30% of ETH paid is sent to foundation wallet when it is paid by users while mint, upgrade
2. 70% of ETH is put on the contract until it's withdrawn to DAO multisig wallet
3. Same rule is applied for payment by users after mint period finish or finishing withdrawal once

### Governance of fund to withdraw to correct DAO multisig address

1. Why is it required?
- IDAO address is not set yet as governance is not setup yet
- To get more people involve governance process
- To set up governance users
- To show foundation is giving users permission to withdraw and manage funds

2. What fields are required
- Vote status (`not_started`, ongoing, `able_to_withdraw`)
- Vote duration
- Vote Quorum
- Vote Power

3. Who can withdraw and when?
- Withdraw action by normal user if vote quorum pass and min vote period pass
- Force withdraw action by admin if safe force withdraw time pass and vote quorum does not reach

4. Vote result
- Vote result by voter
- Vote result by voted address

### Rounds of NFT sale

1. There are 3 rounds of NFT sale
2. We are planning to use same smart contract for 3 rounds of sale - it should be secure enough for multiple rounds of NFTs sale
3. Withdraw shouldn't be able to be done by malicious actors

### Environment variables

#### Constants

- NFT sale duration, 2 weeks
- Foundation percentage, 30%
- Min vote duration, 1 week
- Safe vote end duration, 3 weeks - when admin can force withdraw
- Vote quorum, 50%
- Emotion count per NFT, 5
- Image count for background set, 4
- Image count for arrows, 3 - it's used to show crypto trending arrow

#### Contract variables

- qstkPrice, QSTK token price without discount expressed in ETH(default: $0.03)
- nonTokenPriceMultiplier, the percentage to be multiplied to non-token price like images and coins. (default: 100%)
- tokenPriceMultiplier, the percentage to be multiplied to qstk price. (default: 100%)
- mintStarted, if mint is started or not
- mintStartTime, mint start timestamp
- mintPaused, if mint is paused or not
- foundationWallet, wallet that foundation owned
- totalSupply, total number of NFTs to be minted
- circulatingSupply, total minted NFT count
- qstk, QSTK contract address
- totalAssignedQstk, QSTK locked as part of minted NFT
- qstkBalances, voting power / QSTK balance by address - total sum of nfts QSTK owned by the address
- freeAllocations, free allocations that user can use while minting his/her first NFT, all free allocations goes to the first NFT he mine.
- nftImages, list of nft character images that is set on NFT
- bgImages, list background images that is set on NFT
- favCoins, list of favorite coins selectable when mint
- lockOptions, list of QSTK purchase options selectable when mint
- arrowImage, up/down arrow image to be set as part of background, combined with bgImage
- nftData, NFT Data by id
- voteResult, voting power by voted address
- voteAddressByVoter, voted address by voter address
- voteWeightByVoter, voted power on voted address

### Admin functionalities

#### QNFT contract

- Deposit and withdraw QSTK
- Add and remove free allocation
- Set total NFT supply
- Set mintable status
- Safe withdraw of ETH if vote quorum does not reach after time pass
- Set foundation wallet to receive 30% of purchase

#### QNFTSettings contract

- Set mint price multiplier
- Add/remove lock option - QSTK discount, min/max manager
- Add/Remove image set
- Add/Remove background image set
- Add/Remove favorite coin
- Calculate mint price for given lock options

#### QNFTGovernance contract
 QNFTGovernance is the simple governance contract to manage ETH funds paid by users. It is meant to be used for withdrawing the ETH to correct Quiver IDAO multi-sig wallet. Quiver IDAO multi-sig wallet will be built just after NFT v1 sale finishes.

- Vote on multi-sig wallet with voting power - locked qstk amount
- Withdraw to multi-sig wallet if it has enough quorum.
- Force withdrawal to multi-sig wallet if safe vote end duration is passed. (by owner)

#### Contract ownership change

- Delegate admin role to someone else
- It is meant to be configured to governance multi-sig address when there's functionality for multi-sig address to call NFT admin functions

### Compatibility with NFT marketplaces and visualization apps

- Ability to be detected by general NFT apps
- Ability to be visualized by general NFT apps
- Ability to be transferred by general NFT apps - (to sell or give)

## QInvestor contract - upcoming contract for Quiver IDAO fund management

QInvestor contract uses USDT put inside QSTK contract.
It contains all the on-invest ERC20 tokens, NFT tokens or all the other type of assets that could make profit.
Once investment finish, it's converted to USDT and paid back to QSTK contract.
If user want to withdraw on-invest ERC20 tokens, they can deposit QSTK token into QInvestor contract.

## TODO

- NFT auction should be available when lots of users want to buy NFTs.
