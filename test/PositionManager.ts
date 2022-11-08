import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deploymentFixture } from './fixture';

// Events tests for UniswapPositionManager
describe('Contract: UniswapPositionManager', async () => {
    let positionManager, nftId, nftManager, token0, token1;
    let admin, user1
  beforeEach(async () => {
      ({ positionManager, nftId, nftManager, token0, token1 } = await deploymentFixture());
      [admin, user1] = await ethers.getSigners();
  })

  describe('Reposition', async () => {
    it('should be able to get position ticks', async () => {
        let ticks = await positionManager.getTicks(nftId);
        expect(ticks.tickLower).to.be.eq(-887220)
        expect(ticks.tickUpper).to.be.eq(887220)
    }),

    it('should be able to get position tokens', async () => {
        let tokens = await positionManager.getTokens(nftId);
        expect(tokens.token0).to.be.eq(token0.address);
        expect(tokens.token1).to.be.eq(token1.address);
    }),

    it('should be able to get position staked balance', async () => {
        let stakedBalance = await positionManager.getStakedTokenBalance(nftId);
        expect(stakedBalance.amount0).to.be.gt(0);
        expect(stakedBalance.amount1).to.be.gt(0);
    }),

    it('should be able to reposition', async () => {
        // approve nft to positionManager
        await nftManager.approve(positionManager.address, nftId)
        let newTickLower = -487200
        let newTickUpper = 487200
        let repositionParams =  {
            positionId: nftId,
            newTickLower: newTickLower,
            newTickUpper: newTickUpper,
            minAmount0Staked: 0,
            minAmount1Staked: 0,
            oneInchData: '0x'
        }
        await expect(positionManager.reposition(repositionParams)).not.to.be.reverted;
    })
  })
})
