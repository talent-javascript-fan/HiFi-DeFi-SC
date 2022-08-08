// scripts/deploy.js
require("@nomiclabs/hardhat-ethers");

async function main() {
  const GameFactory = await ethers.getContractFactory("GameFactory");
  console.log("Deploying GameFactory...");
  const box = await GameFactory.deploy(
    "0x0A38bc18022b0cCB043F7b730B354d554C6230F1",
    "0x22C33ADdAD46DEFcFf5f4Fc0b964F20496548fE6",
    "0xEB4ef836d796861189dbF63F5DF8484d506fdf90"
  );
  console.log("GameFactory deployed to:", box.address);

  // const TokenContract = await ethers.getContractFactory("HiFiToken");
  // console.log("Deploying HiFi Token Contract...");
  // const token = await TokenContract.deploy();
  // console.log("HiFi Token Contract deployed to:", token.address);

  await hre.run("verify:verify", {
    address: box.address,
    constructorArguments: [
      "0x0A38bc18022b0cCB043F7b730B354d554C6230F1",
      "0x22C33ADdAD46DEFcFf5f4Fc0b964F20496548fE6",
      "0xEB4ef836d796861189dbF63F5DF8484d506fdf90",
    ],
    contract: "contracts/GameFactory.sol:GameFactory",
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
