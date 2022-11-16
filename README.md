# uniswap-position-manager
The Uniswap Position Manager is a utility for Uniswap V3 LPs looking to reposition their liquidity. The contract provides a helper function that accepts a liquidity NFT, withdraws all liquidity and burns the position, and redeposits into a new price range, all in one atomic transaction.

The contract has a single public function called `reposition`. It takes a struct called `RepositionParams` with the following variables:
- `uint256 positionId`: the id of the liquidity NFT to be repositioned
- `int24 newTickLower`: the lower price tick on the new liquidity position
- `int24 newTickUpper`: the upper price tick on the new liquidity position
- `uint256 minAmount0Staked`: the minimum amount of token0 expected in the new liquidity position, post-reposition
- `uint256 minAmount1Staked`: the minimum amount of token1 expected in the new liquidity position, post-reposition
- `bytes oneInchData`: calldata to be passed to 1inch aggregator in order to facilitate asset swaps

The contract is intended to be use in conjunction with our open source frontend and fork scripts. In order to effectively reposition, we pass swap data to 1inch to effect the necessary asset ratio between the two tokens in the position. For a given price range and current price, Uniswap V3 requires a precise ratio of tokens. As such, repositioning liquidity typically requires an intermediate swap.

In the case of any remaining dust balance in the two tokens post-reposition, the contract returns all unstaked balance to the user.



