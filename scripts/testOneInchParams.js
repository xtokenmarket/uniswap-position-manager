const hre = require("hardhat");
const { ethers, network } = require("hardhat");
const { deployArgs, verifyContractWithArgs } = require("./helpers");
const uniswapAddresses = require("./uniswapAddresses.json");

testParams().catch((err) => console.log);

async function testParams() {
  let nftManagerAddress =
    uniswapAddresses.nonfungibleTokenPositionManagerAddress;
  let uniFactoryAddress = uniswapAddresses.v3CoreFactoryAddress;
  const positionManager = await deployArgs(
    "UniswapPositionManager",
    nftManagerAddress,
    uniFactoryAddress
  );
  console.log("deployed position manager at:", positionManager.address);
  const uniNftManager = await ethers.getContractAt(
    "UniswapPositionManager",
    nftManagerAddress
  );
  console.log("uniNftManager");
  console.log("nftManagerAddress", nftManagerAddress);

  const accountToImpersonate = "0x4c0c29539c463af348f8cba8c02d644a8d68c320";
  const positionId = "694509";
  const newTickLower = "128080";
  const newTickUpper = "328080";
  console.log("set vars");
  
  console.log("positionManager", positionManager);
  let tokens = await positionManager.getTokens(positionId);
  // let tokens = await positionManager["getTokens(uint256)"](positionId);
  let token0 = tokens.token0;
  let token1 = tokens.token1;
  console.log("token0", token0);
  console.log("token1", token1);
  token0 = await ethers.getContractAt("ERC20", token0);
  token1 = await ethers.getContractAt("ERC20", token1);
  const token0Decimals = await token0.decimals();
  const token1Decimals = await token1.decimals();
  console.log("token0Decimals", token0Decimals);
  console.log("token1Decimals", token1Decimals);

  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [accountToImpersonate],
  });
  const signer = await ethers.getSigner(accountToImpersonate);

  await uniNftManager["approve(address,uint256)"](
    positionManager.address,
    positionId
  );

  const currentPoolPrice = await positionManager["getPoolPrice(uint256)"](
    positionId
  );
  console.log("currentPoolPrice", currentPoolPrice);
  const pseudoMintedAmounts = await getNewPositionAssetRatio(
    positionManager,
    currentPoolPrice,
    newTickLower,
    newTickUpper,
    token0Decimals,
    token1Decimals
  );
  console.log("pseudoMintedAmounts", pseudoMintedAmounts);
}

async function getNewPositionAssetRatio(
  positionManager,
  poolPrice,
  newTickLower,
  newTickUpper,
  token0Decimals,
  token1Decimals
) {
  const testAmount0 = 1 * 10 ** token0Decimals;
  const testAmount1 = 1 * 10 ** token1Decimals;
  const pseudoMintedAmounts = await positionManager.calculatePoolMintedAmounts(
    testAmount0,
    testAmount1,
    poolPrice,
    newTickLower,
    newTickUpper
  );
  return pseudoMintedAmounts;
}
