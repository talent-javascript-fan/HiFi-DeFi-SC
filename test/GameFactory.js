// Load dependencies
const { expect } = require("chai");
const { BN, expectEvent, expectRevert } = require("@openzeppelin/test-helpers");
const { formatUnits } = require("@ethersproject/units");

let Box;
let box;
let Token;
let token;
let owner;
let addr1;
let addr2;
let addr3;
let addrs;
// Start test block
describe("GameFactory", function () {
	beforeEach(async function () {
		Token = await ethers.getContractFactory("HiFiToken");
		token = await Token.deploy();
		await token.deployed();

		Box = await ethers.getContractFactory("GameFactory");
		[owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

		box = await Box.deploy(token.address, addr1.address, addr2.address);
		await box.deployed();
		await box._setMaxUserEarningPerDay(100);
		await token.transfer(box.address, 100000000);
	});
	// Test case
	it("Get Burn fee from previous stored", async function () {
		const cfoRole = await box.CFO_ROLE();
		await box.grantRole(cfoRole, addr1.address);

		await box.connect(addr1)._setBurFee(10);
		// Test if the returned value is the same one
		// Note that we need to use strings to compare the 256 bit integers
		expect((await box.getBurnFee()).toString()).to.equal("10");
	});

	it("Get Withdraw fee from previous stored", async function () {
		const cfoRole = await box.CFO_ROLE();
		await box.grantRole(cfoRole, addr1.address);

		await box.connect(addr1)._setWithdrawFee(10);
		// Test if the returned value is the same one
		// Note that we need to use strings to compare the 256 bit integers
		expect((await box.getWithdrawFee()).toString()).to.equal("10");
	});

	it("should add to whitelist", async function () {
		const cmoRole = await box.CMO_ROLE();
		await box.grantRole(cmoRole, addr1.address);

		await box.connect(addr1).initWhitelist([addr1.address, addr2.address]);
		// Test if the returned value is the same one
		// Note that we need to use strings to compare the 256 bit integers
		expect(await box.isWhitelisted(addr1.address)).to.be.true;
	});

	it("should add reward candidates", async function () {
		await box.batchAddRewardCandidates(
			[addr1.address, addr2.address],
			[20, 30]
		);
		// Test if the returned value is the same one
		// Note that we need to use strings to compare the 256 bit integers
		expect(
			(
				await box.connect(addr1).getRewardStateByUser()
			).approvedAmount.toString()
		).to.equal("20");
	});

	it("should transferred reward candidates to thawing", async function () {
		const cmoRole = await box.CMO_ROLE();
		await box.grantRole(cmoRole, addr1.address);
		await box.connect(addr1).addToWhitelist(addr1.address);

		await box.batchAddRewardCandidates([addr1.address], [20]);
		await box.connect(addr1).unfreeze();
		// Test if the returned value is the same one
		// Note that we need to use strings to compare the 256 bit integers
		expect(
			(
				await box.connect(addr1).getRewardStateByUser()
			).approvedAmount.toString()
		).to.equal("0");

		expect(
			(
				await box.connect(addr1).getThawingStateByUser()
			).approvedAmount.toString()
		).to.equal("20");

		expect((await box.connect(addr1).getThawingStateByUser()).status).to.be
			.true;
	});

	it("should claim reward", async function () {
		const cmoRole = await box.CMO_ROLE();
		await box.grantRole(cmoRole, addr1.address);
		await box.connect(addr1).addToWhitelist(addr1.address);
		await box.connect(addr1)._setThawingPeriod(1);

		// added to reward candidate list
		await box.batchAddRewardCandidates([addr1.address], [20]);
		//  unfreeze
		await box.connect(addr1).unfreeze();

		// Test if the returned value is the same one
		// Note that we need to use strings to compare the 256 bit integers
		await box.connect(addr1).claimReward(),
			expect((await token.balanceOf(addr1.address)).toString()).to.equal("19");

		expect(
			(
				await box.connect(addr1).getThawingStateByUser()
			).approvedAmount.toString()
		).to.equal("0");

		expect((await box.connect(addr1).getThawingStateByUser()).status).to.be
			.false;
	});

	it("should freeze reward", async function () {
		const cmoRole = await box.CMO_ROLE();
		await box.grantRole(cmoRole, addr1.address);
		await box.connect(addr1).addToWhitelist(addr1.address);
		await box.connect(addr1)._setThawingPeriod(1);

		// added to reward candidate list
		await box.batchAddRewardCandidates([addr1.address], [20]);
		//  unfreeze
		await box.connect(addr1).unfreeze();

		// Test if the returned value is the same one
		// Note that we need to use strings to compare the 256 bit integers
		await box.connect(addr1).freeze();

		expect((await box.stakeForEarningLists(addr1.address)).toString()).to.equal(
			"20"
		);

		expect(
			(
				await box.connect(addr1).getRewardStateByUser()
			).approvedAmount.toString()
		).to.equal("0");

		expect(
			(
				await box.connect(addr1).getThawingStateByUser()
			).approvedAmount.toString()
		).to.equal("0");

		expect((await box.connect(addr1).getThawingStateByUser()).status).to.be
			.false;
	});

	it("should cancel thawing reward", async function () {
		const cmoRole = await box.CMO_ROLE();
		await box.grantRole(cmoRole, addr1.address);
		await box.connect(addr1).addToWhitelist(addr1.address);

		// added to reward candidate list
		await box.batchAddRewardCandidates([addr1.address], [20]);
		//  unfreeze
		await box.connect(addr1).unfreeze();

		// Test if the returned value is the same one
		// Note that we need to use strings to compare the 256 bit integers
		await box.connect(addr1).cancel();

		expect(
			(
				await box.connect(addr1).getRewardStateByUser()
			).approvedAmount.toString()
		).to.equal("20");

		expect(
			(
				await box.connect(addr1).getThawingStateByUser()
			).approvedAmount.toString()
		).to.equal("0");

		expect((await box.connect(addr1).getThawingStateByUser()).status).to.be
			.false;
	});

	it("should stake token", async function () {
		const cmoRole = await box.CMO_ROLE();
		const cfoRole = await box.CFO_ROLE();
		await box.grantRole(cfoRole, addr1.address);
		await box.grantRole(cmoRole, addr1.address);
		await box.connect(addr1)._setBaseStakeAmountForPlay(100);
		await box.connect(addr1)._setBaseStakeAmountForEarn(1000);

		await box.connect(addr1).initWhitelist([addr1.address, addr2.address]);
		// Test if the returned value is the same one
		await token.transfer(addr1.address, 100000000);
		await token.transfer(addr2.address, 100000000);

		token.connect(addr1).approve(box.address, 100);
		token.connect(addr2).approve(box.address, 1000);

		// Note that we need to use strings to compare the 256 bit integers
		await box.connect(addr1).stakeTokens(1, 100);
		expect((await box.stakeForPlayLists(addr1.address)).toString()).to.equal(
			"100"
		);

		await box.connect(addr2).stakeTokens(2, 1000);
		expect((await box.stakeForEarningLists(addr2.address)).toString()).to.equal(
			"1000"
		);
	});

	it("should withdraw token", async function () {
		const cmoRole = await box.CMO_ROLE();
		const cfoRole = await box.CFO_ROLE();
		await box.grantRole(cfoRole, addr1.address);
		await box.grantRole(cmoRole, addr1.address);
		await box.connect(addr1)._setBaseStakeAmountForPlay(100);
		await box.connect(addr1)._setBaseStakeAmountForEarn(1000);

		await box.connect(addr1).initWhitelist([addr1.address, addr2.address]);
		// Test if the returned value is the same one
		await token.transfer(addr1.address, 100);
		await token.transfer(addr2.address, 1000);

		token.connect(addr1).approve(box.address, 100);
		token.connect(addr2).approve(box.address, 1000);

		// Note that we need to use strings to compare the 256 bit integers
		await box.connect(addr1).stakeTokens(1, 100);
		await box.connect(addr2).stakeTokens(2, 1000);

		await box.connect(addr1).withdrawStakedToken(1, 100);
		await box.connect(addr2).withdrawStakedToken(2, 1000);

		expect((await token.balanceOf(addr1.address)).toString()).to.equal("95");

		expect((await token.balanceOf(addr2.address)).toString()).to.equal("960");
	});

	it("should stake boost item", async function () {
		const cmoRole = await box.CMO_ROLE();
		await box.grantRole(cmoRole, addr1.address);
		await box.setGoldItemPrice(10000);
		await box.setSilverItemPrice(5000);
		await box.setBronzeItemPrice(2000);

		await box.connect(addr1).initWhitelist([addr1.address, addr2.address]);
		// Test if the returned value is the same one
		await token.transfer(addr1.address, 12000);
		await token.transfer(addr2.address, 5000);

		token.connect(addr1).approve(box.address, 12000);
		token.connect(addr2).approve(box.address, 5000);

		// Note that we need to use strings to compare the 256 bit integers
		await box.connect(addr1).stakeForBoost(1);
		await box.connect(addr2).stakeForBoost(2);
		expect(
			(await box.userBoostItemBalance(addr1.address, 1)).toString()
		).to.equal("1");
		expect(
			(await box.userBoostItemBalance(addr2.address, 2)).toString()
		).to.equal("1");
	});


	

	it("Cannot stake multiple boost items", async function () {
		const cmoRole = await box.CMO_ROLE();
		await box.grantRole(cmoRole, addr1.address);
		await box.setGoldItemPrice(10000);
		await box.setSilverItemPrice(5000);
		await box.setBronzeItemPrice(2000);

		await box.connect(addr1).initWhitelist([addr1.address, addr2.address, addr3.address]);
		// Test if the returned value is the same one
		await token.transfer(addr1.address, 12000);
		await token.transfer(addr2.address, 5000);
		await token.transfer(addr3.address, 5000);

		token.connect(addr1).approve(box.address, 12000);
		token.connect(addr2).approve(box.address, 5000);
		token.connect(addr3).approve(box.address, 5000);

		//Note that we need to use strings to compare the 256 bit integers
		await box.connect(addr1).stakeForBoost(1);
		await box.connect(addr2).stakeForBoost(2);
		await box.connect(addr3).stakeForBoost(3);
		expect(
			(await box.userBoostItemBalance(addr1.address, 1)).toString()
		).to.equal("1");
		expect(
			(await box.userBoostItemBalance(addr2.address, 2)).toString()
		).to.equal("1");
		expect(
			(await box.userBoostItemBalance(addr3.address, 3)).toString()
		).to.equal("1");

		const checkBoostDenied = async (address, level) => {
			let boostErrored = false; 
			try {
				await box.connect(address).stakeForBoost(level);
			} catch (error) {
				boostErrored = true;
			}
			expect(boostErrored).to.equal(true);
		}

		await checkBoostDenied(addr1, 1);
		await checkBoostDenied(addr1, 2);
		await checkBoostDenied(addr1, 3);
		
		await checkBoostDenied(addr2, 1);
		await checkBoostDenied(addr2, 2);
		await checkBoostDenied(addr2, 3);

		await checkBoostDenied(addr3, 1);
		await checkBoostDenied(addr3, 2);
		await checkBoostDenied(addr3, 3);
	});


	it("should withdraw Fee", async function () {
		const cmoRole = await box.CMO_ROLE();
		const cfoRole = await box.CFO_ROLE();
		await box.grantRole(cfoRole, addr1.address);
		await box.grantRole(cmoRole, addr1.address);
		await box.connect(addr1)._setBaseStakeAmountForPlay(100);
		await box.connect(addr1)._setBaseStakeAmountForEarn(1000);
		await box.setGoldItemPrice(10000);
		// await box.setSilverItemPrice(30);
		// await box.setBronzeItemPrice(10);

		await box.connect(addr1).initWhitelist([addr1.address, addr2.address]);
		// Test if the returned value is the same one
		await token.transfer(addr1.address, 10000);
		// await token.transfer(addr2.address, 1000);

		token.connect(addr1).approve(box.address, 10000);
		token.connect(addr2).approve(box.address, 10000);

		// Note that we need to use strings to compare the 256 bit integers
		await box.connect(addr1).stakeForBoost(1);
		// await box.connect(addr1).stakeForBoost(2);

		const result = await box.getStatistic();
		const totalComm = formatUnits(result.totalCommission, 0);
		const totalCommWithdrawn = formatUnits(result.totalCommissionWithdrawn, 0);
		const availableToWithdraw = Number.parseInt(totalComm) - Number.parseInt(totalCommWithdrawn);
		console.log(`Total commission: ${totalComm}, Total withdrawn: ${totalCommWithdrawn}, Total left to withdraw: ${availableToWithdraw}`)

		const withdrawAmount = 80;
		await box.withdrawFee(addr2.address, withdrawAmount);
		expect((await token.balanceOf(addr2.address)).toString()).to.equal("80");

		console.log(`Withdraw ${withdrawAmount}`);

		const resultAfterWithdraw = await box.getStatistic();
		const totalCommAfter = formatUnits(resultAfterWithdraw.totalCommission, 0);
		const totalCommWithdrawnAfter = formatUnits(resultAfterWithdraw.totalCommissionWithdrawn, 0);
		const availableToWithdrawAfter = Number.parseInt(totalCommAfter) - Number.parseInt(totalCommWithdrawnAfter);

		console.log(`Total commission: ${totalCommAfter}, Total withdrawn: ${totalCommWithdrawnAfter}, Total left to withdraw: ${availableToWithdrawAfter}`)
	});


	it("should burn and withdraw Fee", async function () {

		await box.connect(owner)._setBurnStatus(true);

		const cmoRole = await box.CMO_ROLE();
		const cfoRole = await box.CFO_ROLE();
		await box.grantRole(cfoRole, addr1.address);
		await box.grantRole(cmoRole, addr1.address);
		await box.connect(addr1)._setBaseStakeAmountForPlay(100);
		await box.connect(addr1)._setBaseStakeAmountForEarn(1000);
		await box.setGoldItemPrice(10000);
		await box.connect(addr1)._setBurFee(10);



		await box.connect(addr1).initWhitelist([addr1.address, addr2.address]);

		// Test if the returned value is the same one
		await token.connect(owner).transfer(addr1.address, 10000);
		await token.connect(owner).transfer(addr2.address, 10000);
		const tokenContractBalance = await token.balanceOf(addr1.address);
		console.log("addr1 is ", tokenContractBalance);

		token.connect(addr1).approve(box.address, 10000);
		token.connect(addr2).approve(box.address, 10000);
		token.connect(owner).approve(box.address, 100000000);
		const add2Amount = await token.balanceOf(addr2.address);
		console.log("add2Amount", add2Amount.toString());
		await box.connect(addr2).stakeForBoost(1);
		// await box.connect(addr1).stakeForBoost(2);
		const add2Amount1 = await token.balanceOf(addr2.address);
		console.log("add2Amount1", add2Amount1.toString())

		const result = await box.getStatistic();
		// console.log(`result :`, result)
		const totalComm = formatUnits(result.totalCommission, 0);
		const totalCommWithdrawn = formatUnits(result.totalCommissionWithdrawn, 0);
		// const isBurnable = formatUnits(result.isBurnable, 0);
		const availableToWithdraw = Number.parseInt(totalComm) - Number.parseInt(totalCommWithdrawn);
		console.log(`Total commission: ${totalComm}, Total withdrawn: ${totalCommWithdrawn}, Total left to withdraw: ${availableToWithdraw}`)

		await box.grantRole(cfoRole, addr2.address);
		await box.connect(addr2)._setBurFee(5);
		const fee = await box.getWithdrawFee();
		console.log("fee", fee.toString());
		await box.withdrawFee(addr2.address, 80);
		expect((await token.balanceOf(addr2.address)).toString()).to.equal("76");

		const resultAfterWithdraw = await box.getStatistic();
		const totalCommAfter = formatUnits(resultAfterWithdraw.totalCommission, 0);
		const totalCommWithdrawnAfter = formatUnits(resultAfterWithdraw.totalCommissionWithdrawn, 0);
		const availableToWithdrawAfter = Number.parseInt(totalCommAfter) - Number.parseInt(totalCommWithdrawnAfter);
		console.log(`Total commission: ${totalCommAfter}, Total withdrawn: ${totalCommWithdrawnAfter}, Total left to withdraw: ${availableToWithdrawAfter}`)
	});
});
