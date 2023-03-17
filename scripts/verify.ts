import { verifyContractWithArgs } from "./helpers";
import uniswapAddresses from "./uniswapAddresses.json";

const TO_VERIFY = "0xDA317DAb6137ab7aC56b628d659F02Def36DE405";
verify(TO_VERIFY).catch((err) => console.log);

async function verify(positionManagerAddress) {
  let nftManagerAddress =
    uniswapAddresses.nonfungibleTokenPositionManagerAddress;
  let uniFactoryAddress = uniswapAddresses.v3CoreFactoryAddress;
  await verifyContractWithArgs(
    positionManagerAddress,
    nftManagerAddress,
    uniFactoryAddress
  );
}
