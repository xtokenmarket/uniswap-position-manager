import { verifyContractWithArgs } from "./helpers";
import uniswapAddresses from "./uniswapAddresses.json";

const TO_VERIFY = '0xdce16ad5cfba50203766f270d69115c265d2687d';
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
