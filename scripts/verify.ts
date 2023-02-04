import { verifyContractWithArgs } from "./helpers";
import uniswapAddresses from "./uniswapAddresses.json";

const TO_VERIFY = "0x58A9Ea3d583823A4A609373d45e104456932bA9C";
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
