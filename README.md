# Prelude to the ICPverse NFT Token Standard 

Basic NFT minter inspired by the DIP 721 standard (implementation not guarantee, consider this example as an educational ressource. For a production project with DIP721, please take a look at the official DIP721 repo).

30 Day Sprint Index (all on main.mo unless stated otherwise):  
Development of Buy/Sell functionality: line 435  
Development of Upvote functionality: line 337  
Implementation of Auction functionality: line 512  
Implementation of Staking functionality (in token.mo): line 1109  
Implementation of Tags functionality: line 15  

## Running the project locally

To run the project locally, you can use the following commands:

```bash
# Install dependencies
npm run start

# Starts the replica
dfx start 

# Deploys your canisters to the replica and generates your candid interface
dfx deploy
```

Once the job completes, your application will be available at `http://localhost:8000?canisterId={asset_canister_id}`.
Additionally, if you are making frontend changes, you can start a development server with
```bash
npm start
```


Thanks to https://github.com/torates/testMinter for the inspiration.

NOTE: The scope of the repository is completed. It will eventually be merged to ICPverse Repository.
