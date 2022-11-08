import { ethers, deployments } from 'hardhat';
import { deploy, deployArgs, deployAndLink, deployWithAbi,
        bnDecimal, 
        depositLiquidityInPool,
        deployWithAbiAndLink,
        getEvent} from '../scripts/helpers';

import UniQuoter from '@uniswap/v3-periphery/artifacts/contracts/lens/Quoter.sol/Quoter.json';

import SwapRouter from '@uniswap/v3-periphery/artifacts/contracts/SwapRouter.sol/SwapRouter.json'
import NFTDescriptorLibrary from '@uniswap/v3-periphery/artifacts/contracts/libraries/NFTDescriptor.sol/NFTDescriptor.json';
import NFTPositionDescriptor from '@uniswap/v3-periphery/artifacts/contracts/NonFungibleTokenPositionDescriptor.sol/NonFungibleTokenPositionDescriptor.json';
import NFTPositionManager from '@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json';
import UniFactory from '@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json';

import { ERC20Basic, INonfungiblePositionManager, UniswapPositionManager } from '../typechain';

/**
 * Deployment fixture
 * Deploys minimum required for tests
 */
export const deploymentFixture = deployments.createFixture(async () => {
    const [admin, user1, user2, user3] = await ethers.getSigners();
    // Deploy tokens for initial pool deployment
    let token0 : ERC20Basic = <ERC20Basic>await deployArgs('ERC20Basic', 'DAI', 'DAI');
    let token1 : ERC20Basic = <ERC20Basic>await deployArgs('ERC20Basic', 'TUSD', 'TUSD');
    // Tokens must be sorted by address
    if(token0.address.toLowerCase() > token1.address.toLowerCase()) {
      let tmp = token0;
      token0 = token1;
      token1 = tmp;
    }

    // Deploy Uniswap V3 Contracts
    const uniFactory = await deployWithAbi(UniFactory, admin);
    const tokenDescriptorLib = await deployWithAbi(NFTDescriptorLibrary, admin);
    const tokenDescriptor = await deployWithAbiAndLink(NFTPositionDescriptor, 
      'NFTDescriptor', tokenDescriptorLib.address, admin, token0.address, "0x46554e4e594d4f4e455900000000000000000000000000000000000000000000");
    const nftManager: INonfungiblePositionManager = <INonfungiblePositionManager>await deployWithAbi(NFTPositionManager, admin, 
                                                uniFactory.address, token0.address, tokenDescriptor.address);
    const swapRouter = await deployWithAbi(SwapRouter, admin, uniFactory.address, token0.address);
    const quoter = await deployWithAbi(UniQuoter, admin, uniFactory.address, token0.address);

    // Deploy Uni V3 Pool
    // 0.94 - 1.06 price
    const lowTick = -600;
    const highTick = 600;
    // Price = 1
    const price = '79228162514264337593543950336';
    await nftManager.createAndInitializePoolIfNecessary(token0.address, token1.address, 3000, price);

    // Deposit liquidity in pool
    const initialDepositAmount = bnDecimal(100000);
    let depositResult = await depositLiquidityInPool(nftManager, initialDepositAmount, initialDepositAmount, 
      token0, token1, 3000, admin.address)
    let depositEvent = await getEvent(depositResult, 'IncreaseLiquidity');
    let nftId = depositEvent.args[0];

    // Deploy position manager
    const positionManager: UniswapPositionManager = <UniswapPositionManager>await deployArgs('UniswapPositionManager', 
      nftManager.address, uniFactory.address);
    
    // transfer tokens to other users
    await token0.transfer(user1.address, bnDecimal(1000000));
    await token1.transfer(user1.address, bnDecimal(1000000));
    await token0.transfer(user2.address, bnDecimal(1000000));
    await token1.transfer(user2.address, bnDecimal(1000000));

    return {
      token0, token1, positionManager, nftId, nftManager
    }
});