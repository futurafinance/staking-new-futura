# staking-new-futura

![image](https://user-images.githubusercontent.com/94194537/154544640-d648c282-abbc-4046-9aea-5433605b19e1.png)

- Futura Fuel 
  > - Helps processing the rewrads queue from small fees out of the pools
  > - Notice you need to allow the other contracts to interact with it using setAuthorizedContract function for Fuel, Futura, Investor and Masterchef
  
- Futura Investor
  > - Invests into IFundingPlans (ex: Cake Plan) to generate profits. Receives part of the Stake Pool when ProcessAllFunds is called
  > - Notice you need to allow the other contracts to interact with it using setAuthorizedContract function for Fuel, Futura, Investor and Masterchef
  > - Receives the profits from the funding plans, reinvest and redistribute to the pools
  
- Stake Futura Pool
  > - This is the main Stake Futura Pool contract. You define Futura addr, Fuel addr (deploy it first), Investor addr (deploy it first), Router address (Kienti for testnet and Pancakeswap main for mainnet), Outtoken addr (reward token)
  > - An admin needs to click "FillPool" for the pool to claim
  > - Before someone stakes, it needs to increase allowance from Futura contract using approve function with spender = stake pool addr, amount = total supply
  > - An admin needs to click "FillPool" for the pool to claim
  > - Notice you need to allow the other contracts to interact with it using setAuthorizedContract function for Fuel, Futura, Investor and Masterchef
  > - You also need to exclude this contract from fees on Futura side
- AutoCompoundPool
  > - This is a subclass of Stake Futura Pool, we will use that for AutoCompound or implementing a new type
  > - Users can stake / unstake 100% of their stokens by calling stakeAll / unstakeAll
- Cake Investment Plan (Funding Plan)
  > - This is used by the investor to invest in Pancakeswap's Cake on mainnet. For testnet we need to deploy our own masterchef (Masterchef2.sol) and Fortuna / Fortuna Split Bar tokens that will act as "Cake".
  
- Masterchef2
  > - This is used to invest into Cake on testnet, while on mainnet we don't need this. 
