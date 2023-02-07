import { verifyContractWithArgs } from "./helpers";
import uniswapAddresses from "./uniswapAddresses.json";

const TO_VERIFY = "0x78A5ACfC789CB3bbd1D47f5Fa1A8896238aDD0ec";
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
