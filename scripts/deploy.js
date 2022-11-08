
const { deployArgs } = require('./helpers');
const uniswapAddresses = require('./uniswapAddresses.json');

deploy().catch(err => console.log)

async function deploy() {
    const positionManager = await deployArgs('UniswapPositionManager', 
        uniswapAddresses.nonfungibleTokenPositionManagerAddress, uniswapAddresses.v3CoreFactoryAddress);
    console.log('deployed position manager at:', positionManager.address);
}