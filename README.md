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

QNFT contract is providing below functionalities.
Keep QSTK token and lock it until lock period finish.
```sol
// Pseudo code
contract QNFT is ERC721 {
  QSTK_TOKEN address;
  max_nfts_count uint256;
  remainingqSTK uint256; // amount of token that could be assigned to NFT mint
  totalLockedQSTK uint256; // amount of token assigned to NFTs already only unlockable when they are unlocked
  balancesPerNFT map[address][uint256];
  lockQSTKDuration map[address][uint256];
  mintableAmounts uint256[3] = []; // 100QSTK, 200QSTK, 300QSTK
  lockableDurations uint256[3] = []; // 3 months, 6 months, 1 year
  discounts uint256[3] = []; // 10%, 20%, 30%
  
  registerEmotionSet(url1,...url5 memory string) onlyAdmin;
  removeEmotionSet(emotionId uint256) onlyAdmin;
  whitelistCoins() onlyAdmin;
  blacklistCoins() onlyAdmin;
  depositQSTK() onlyAdmin;
  withdrawQSTK() onlyAdmin;
  startNFTMint() onlyAdmin;
  stopNFTMint() onlyAdmin;
  resetAdmin() onlyAdmin; // at final, should be governance multisig address

  // user should pay ETH when mint, and mint price is calculated by params provided
  // NFT Mint Price = QSTK initial sale price (0.00001ETH) * QSTK quantity(user input) * discountRateByDuration +  ImageSetPrice (admin) + Coin selection price(admin)
  mintNFT(emotionId uint256, favCoinId uint256, mintQSTKAmt uint256, lockQSTKDuration uint256) returns ();
  // At the time of burn event, you will need to not be fully paid for QSTK token
  burnNFT(nftId uint256) returns ();
  // Upgrade NFT is to replace image to better one he like and add more tokens as they want - should think of restrictions, it is required when users want to mint more than maximum amount, and remove ones that are not qualified than others
  upgradeNFT(nftId uint256, imageSetId uint256, tokensAdd uint256) returns ();
  transferNFT(nftId uint256, to address) returns ();

  unlockQSTKFromNFT(nftId uint256) returns ();
  getNFTInfo(nftId uint256) returns ();
  
  // NFT contract sale is done before governance setup, to ensure governance dev funds are put in correct governance managed multi-sig wallet, we need to add simple voter interface so that the addresses with more purchase of locked QSTK could have more voting power
  // When vote, users vote with multi-sig receiver address that he has verified.
  // If Quorum reaches and the 50% are same addresses, it can be automatically withdrawn to the wallet by admin
  // If Quorum does not reach within 2 weeks, 50% goes back to users' wallet and 50% goes to foundation wallet.
  // At the time of NFT mint, 40% goes to foundation wallet, it's for foundation payment of whitepaper and NFT project development
  // Here, 40%, and 50% are set as a variable before mint start and once start, can't be modified
}
```

## QInvestor contract

QInvestor contract uses USDT put inside QSTK contract.
It contains all the on-invest ERC20 tokens, NFT tokens or all the other type of assets that could make profit.
Once investment finish, it's converted to USDT and paid back to QSTK contract.
If user want to withdraw on-invest ERC20 tokens, they can deposit QSTK token into QInvestor contract.

## TODO

- NFT auction should be available when lots of users want to buy NFTs.
- Reference common NFT contracts for other common functionalities.
