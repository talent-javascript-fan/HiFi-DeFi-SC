// scripts/deploy.js
require("@nomiclabs/hardhat-ethers");

async function main() {
	// const TokenContract = await ethers.getContractFactory("HiFiToken");
	// console.log("Deploying HiFi Token Contract...");
	// const token = await TokenContract.deploy();
	// console.log("HiFi Token Contract deployed to:", token.address);

	const GameFactory = await ethers.getContractFactory("GameFactory");
	console.log("Deploying GameFactory...");
	const box = await GameFactory.deploy(
		// token.address,
		"0xeFAd4c0B50Dc4089Bb354979AE2caD9E41C3606B",
		"0xf36b8b5D3C2a18C40BFCC5562e27f208d970b236",
		"0xf36b8b5D3C2a18C40BFCC5562e27f208d970b236"
	);
	console.log("GameFactory deployed to:", box.address);

	// await hre.run("verify:verify", {
	//   address: box.address,
	//   constructorArguments: [
	//     token.address,
	//     "0x23853fde632616E7f3BBa4C7662b86A21A326A89",
	//     "0x23853fde632616E7f3BBa4C7662b86A21A326A89",
	//   ],
	//   contract: "contracts/GameFactory.sol:GameFactory",
	// });
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
