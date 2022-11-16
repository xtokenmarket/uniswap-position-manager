import { ethers, deployments } from 'hardhat';
import { deployArgs,
        depositLiquidityInPool,
        receiveUSDT,
        receiveUSDC,
        getTokens,
        bnDecimals } from '../scripts/helpers';

import { INonfungiblePositionManager, UniswapPositionManager } from '../typechain';
import uniswapAddresses from '../scripts/uniswapAddresses.json';

/**
 * Mainnet forking fixture which uses USDC and USDT as primary position tokens
 * Deposits 100k of t0 and t1 in USDC/USDT Uni V3 0.03% fee pool
 */
export const usdcUsdtFixture = deployments.createFixture(async () => {
    let nftManagerAddress = uniswapAddresses.nonfungibleTokenPositionManagerAddress
    let uniFactoryAddress = uniswapAddresses.v3CoreFactoryAddress
    const positionManager: UniswapPositionManager = 
        <UniswapPositionManager>await deployArgs('UniswapPositionManager', nftManagerAddress, uniFactoryAddress);

    // Get USDT and USDC
    let [admin] = await ethers.getSigners();
    await receiveUSDT(admin);
    await receiveUSDC(admin);
    let tokens = await getTokens();
    
    const nftManager: INonfungiblePositionManager = 
    <INonfungiblePositionManager>await ethers.getContractAt('INonfungiblePositionManager', nftManagerAddress);
    // Create USDC/USDT position
    let initialDepositAmount = bnDecimals(100000, 6);
    // initial ticks: -887220 to 887220
    // widest possible range
    let lowTick = -887220;
    let highTick = 887220;
    let deposit = await depositLiquidityInPool(nftManager, initialDepositAmount, initialDepositAmount, 
        tokens.usdc, tokens.usdt, 3000, lowTick, highTick, admin.address)

    return {
      token0: tokens.usdc, token1: tokens.usdt, positionManager, nftId: deposit.nftId, nftManager
    }
})