import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, network } from "hardhat";

describe("Staking", function () {
  let owner: any;
  let staker1: any;
  let staker2: any;
  let staker3: any;
  let Staking: any;
  let staking: any
  let liquidityToken: any;
  let implementationStaking: any;
  let ERC1967Proxy: any;
  let proxyStaking: any;
  let rewardToken: any;
  let startDate: any;
  const THREE_YEARS = 52 * 3;
  const ONE_WEEK = 60 * 60 * 24 * 7;
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  beforeEach(async function () {

    startDate = 1688212800;
    await network.provider.send("hardhat_reset")
    await network.provider.send("evm_setNextBlockTimestamp", [startDate - 10000])
    await network.provider.send("evm_mine") // this one will have 2023-07-01 12:00 AM as its timestamp, no matter what the previous block has

    // Contracts are deployed using the first signer/account by default
    const [_owner, _staker1, _staker2, _staker3] = await ethers.getSigners();
    owner = _owner;
    staker1 = _staker1;
    staker2 = _staker2;
    staker3 = _staker3;
    Staking = await ethers.getContractFactory("Staking");
    const Token = await ethers.getContractFactory("ERC20Mock");
    liquidityToken = await Token.deploy('Liquidity Token', 'LTKN', owner.address, 1000000);
    rewardToken = await Token.deploy('Reward Token', 'RTKN', owner.address, 1000000);
    implementationStaking = await Staking.deploy();
    ERC1967Proxy = await ethers.getContractFactory("ERC1967Proxy");
    proxyStaking = await ERC1967Proxy.deploy(implementationStaking.address, "0x");
    staking = await ethers.getContractAt("Staking", proxyStaking.address);
    await staking.initialize(liquidityToken.address, rewardToken.address, startDate, THREE_YEARS);
  })

  describe("Deployment", function () {
    it("Should have right initialized variables ", async function () {
      expect(await staking.liquidityToken()).to.equal(liquidityToken.address);
      expect(await staking.rewardToken()).to.equal(rewardToken.address);
      expect(await staking.startDate()).to.equal(startDate);
      expect(await staking.endDate()).to.equal(startDate + (THREE_YEARS) * ONE_WEEK);
    })

    it("failed to initialize staking contract with wrong liquidity address", async function () {
      implementationStaking = await Staking.deploy();
      ERC1967Proxy = await ethers.getContractFactory("ERC1967Proxy");
      proxyStaking = await ERC1967Proxy.deploy(implementationStaking.address, "0x");
      const testStaking = await ethers.getContractAt("Staking", proxyStaking.address);
      await expect(testStaking.initialize(ethers.constants.AddressZero, rewardToken.address, startDate, THREE_YEARS)).to.be.revertedWith('invalid address');
    })

    it("failed to initialize staking contract with wrong reward address", async function () {
      implementationStaking = await Staking.deploy();
      ERC1967Proxy = await ethers.getContractFactory("ERC1967Proxy");
      proxyStaking = await ERC1967Proxy.deploy(implementationStaking.address, "0x");
      const testStaking = await ethers.getContractAt("Staking", proxyStaking.address);
      await expect(testStaking.initialize(liquidityToken.address, ethers.constants.AddressZero, startDate, THREE_YEARS)).to.be.revertedWith('invalid address');
    })

    it("failed to initialize staking contract with wrong rewardPeriods", async function () {
      implementationStaking = await Staking.deploy();
      ERC1967Proxy = await ethers.getContractFactory("ERC1967Proxy");
      proxyStaking = await ERC1967Proxy.deploy(implementationStaking.address, "0x");
      const testStaking = await ethers.getContractAt("Staking", proxyStaking.address);
      await expect(testStaking.initialize(liquidityToken.address, rewardToken.address, startDate, 0)).to.be.revertedWith('invalid rewardPeriods');
    })

    it("failed to initialize staking contract with wrong startDate", async function () {
      implementationStaking = await Staking.deploy();
      ERC1967Proxy = await ethers.getContractFactory("ERC1967Proxy");
      proxyStaking = await ERC1967Proxy.deploy(implementationStaking.address, "0x");
      const testStaking = await ethers.getContractAt("Staking", proxyStaking.address);
      await expect(testStaking.initialize(liquidityToken.address, rewardToken.address, 1, THREE_YEARS)).to.be.revertedWith('invalid startDate');
    })
  });

  describe("Upgradeable", function () {
    it("update contract successfully", async function () {
      const StakingV2 = await ethers.getContractFactory("StakingMockV2");
      const implementationStakingV2 = await StakingV2.deploy();
      await staking.upgradeTo(implementationStakingV2.address);
      const testStaking = await ethers.getContractAt("StakingMockV2", staking.address);
      await testStaking.setNewVariable(10);
      expect(await testStaking.newVariable()).to.equal(10);
      expect(await testStaking.startDate()).to.equal(startDate);
    })

    it("fail to update contract due to user not owner", async function () {
      const StakingV2 = await ethers.getContractFactory("StakingMockV2");
      const implementationStakingV2 = await StakingV2.deploy();
      await expect(staking.connect(staker1).upgradeTo(implementationStakingV2.address)).to.be.rejectedWith("Ownable: caller is not the owner");
    })

  })

  /*
  describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { lock, unlockTime } = await loadFixture(deployOneYearLockFixture);

      expect(await lock.unlockTime()).to.equal(unlockTime);
    });

    it("Should set the right owner", async function () {
      const { lock, owner } = await loadFixture(deployOneYearLockFixture);

      expect(await lock.owner()).to.equal(owner.address);
    });

    it("Should receive and store the funds to lock", async function () {
      const { lock, lockedAmount } = await loadFixture(
        deployOneYearLockFixture
      );

      expect(await ethers.provider.getBalance(lock.address)).to.equal(
        lockedAmount
      );
    });

    it("Should fail if the unlockTime is not in the future", async function () {
      // We don't use the fixture here because we want a different deployment
      const latestTime = await time.latest();
      const Lock = await ethers.getContractFactory("Lock");
      await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
        "Unlock time should be in the future"
      );
    });
  });

  describe("Withdrawals", function () {
    describe("Validations", function () {
      it("Should revert with the right error if called too soon", async function () {
        const { lock } = await loadFixture(deployOneYearLockFixture);

        await expect(lock.withdraw()).to.be.revertedWith(
          "You can't withdraw yet"
        );
      });

      it("Should revert with the right error if called from another account", async function () {
        const { lock, unlockTime, otherAccount } = await loadFixture(
          deployOneYearLockFixture
        );

        // We can increase the time in Hardhat Network
        await time.increaseTo(unlockTime);

        // We use lock.connect() to send a transaction from another account
        await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
          "You aren't the owner"
        );
      });

      it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
        const { lock, unlockTime } = await loadFixture(
          deployOneYearLockFixture
        );

        // Transactions are sent using the first signer by default
        await time.increaseTo(unlockTime);

        await expect(lock.withdraw()).not.to.be.reverted;
      });
    });

    describe("Events", function () {
      it("Should emit an event on withdrawals", async function () {
        const { lock, unlockTime, lockedAmount } = await loadFixture(
          deployOneYearLockFixture
        );

        await time.increaseTo(unlockTime);

        await expect(lock.withdraw())
          .to.emit(lock, "Withdrawal")
          .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
      });
    });

    describe("Transfers", function () {
      it("Should transfer the funds to the owner", async function () {
        const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
          deployOneYearLockFixture
        );

        await time.increaseTo(unlockTime);

        await expect(lock.withdraw()).to.changeEtherBalances(
          [owner, lock],
          [lockedAmount, -lockedAmount]
        );
      });
    });
  });
  */
});
