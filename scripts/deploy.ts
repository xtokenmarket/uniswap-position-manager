
import { deployArgs, verifyContractWithArgs } from './helpers';
import uniswapAddresses from './uniswapAddresses.json';

deploy().catch(err => console.log)

async function deploy() {
    let nftManagerAddress = uniswapAddresses.nonfungibleTokenPositionManagerAddress
    let uniFactoryAddress = uniswapAddresses.v3CoreFactoryAddress
    const positionManager = await deployArgs('UniswapPositionManager', nftManagerAddress, uniFactoryAddress);
    console.log('deployed position manager at:', positionManager.address);
    await verifyContractWithArgs(positionManager.address, nftManagerAddress, uniFactoryAddress)
}