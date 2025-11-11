const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("合约升级流程测试", function () {
  let logicV1, logicV2, proxy;
  let owner, user;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    // 部署 V1
    const LogicV1 = await ethers.getContractFactory("LogicContract");
    logicV1 = await LogicV1.deploy();
    await logicV1.waitForDeployment();

    // 部署代理合约
    const Proxy = await ethers.getContractFactory("ProxyContract");
    proxy = await Proxy.deploy(await logicV1.getAddress());
    await proxy.waitForDeployment();

    // 部署 V2
    const LogicV2 = await ethers.getContractFactory("LogicContractV2");
    logicV2 = await LogicV2.deploy();
    await logicV2.waitForDeployment();
  });

  describe("升级前的状态", function () {
    it("代理合约应该指向 V1", async function () {
      expect(await proxy.logicContract()).to.equal(await logicV1.getAddress());
    });

    it("应该能使用 V1 的功能", async function () {
      await proxy.incrementViaDelegate();
      expect(await proxy.counter()).to.equal(1);
    });
  });

  describe("执行升级", function () {
    it("所有者应该能够更新逻辑合约地址", async function () {
      // 升级前
      expect(await proxy.logicContract()).to.equal(await logicV1.getAddress());

      // 执行升级 ⭐ 关键步骤
      await proxy.updateLogicContract(await logicV2.getAddress());

      // 升级后
      expect(await proxy.logicContract()).to.equal(await logicV2.getAddress());
    });

    it("非所有者不能更新逻辑合约地址", async function () {
      await expect(
        proxy.connect(user).updateLogicContract(await logicV2.getAddress())
      ).to.be.revertedWith("Only owner can update logic contract");
    });

    it("升级后状态应该保留", async function () {
      // 使用 V1 累积状态
      await proxy.incrementViaDelegate();
      await proxy.incrementViaDelegate();
      await proxy.incrementViaDelegate();
      expect(await proxy.counter()).to.equal(3);

      // 执行升级
      await proxy.updateLogicContract(await logicV2.getAddress());

      // 验证状态保留
      expect(await proxy.counter()).to.equal(3);
    });
  });

  describe("升级后的功能", function () {
    beforeEach(async function () {
      // 先累积一些状态
      await proxy.incrementViaDelegate();
      await proxy.incrementViaDelegate();
      expect(await proxy.counter()).to.equal(2);

      // 执行升级
      await proxy.updateLogicContract(await logicV2.getAddress());
    });

    it("V1 的原有功能应该继续工作", async function () {
      await proxy.incrementViaDelegate();
      expect(await proxy.counter()).to.equal(3);
    });

    it("应该能使用 V2 的新功能: incrementByMultiplier", async function () {
      // 编码 V2 的新函数调用
      const data = logicV2.interface.encodeFunctionData("incrementByMultiplier", [5]);
      
      // 通过代理合约调用
      await owner.sendTransaction({
        to: await proxy.getAddress(),
        data: data,
      });

      expect(await proxy.counter()).to.equal(7); // 2 + 5
    });

    it("应该能使用 V2 的新功能: decrement", async function () {
      const data = logicV2.interface.encodeFunctionData("decrement");
      
      await owner.sendTransaction({
        to: await proxy.getAddress(),
        data: data,
      });

      expect(await proxy.counter()).to.equal(1); // 2 - 1
    });

    it("应该能使用 V2 的新功能: reset", async function () {
      const data = logicV2.interface.encodeFunctionData("reset");
      
      await owner.sendTransaction({
        to: await proxy.getAddress(),
        data: data,
      });

      expect(await proxy.counter()).to.equal(0);
    });

    it("应该能获取 V2 的版本号", async function () {
      const data = logicV2.interface.encodeFunctionData("version");
      
      const result = await owner.call({
        to: await proxy.getAddress(),
        data: data,
      });

      const version = logicV2.interface.decodeFunctionResult("version", result)[0];
      expect(version).to.equal("v2.0.0");
    });
  });

  describe("多次升级", function () {
    it("应该支持多次升级", async function () {
      // 初始状态
      await proxy.incrementViaDelegate();
      expect(await proxy.counter()).to.equal(1);

      // 第一次升级到 V2
      await proxy.updateLogicContract(await logicV2.getAddress());
      expect(await proxy.logicContract()).to.equal(await logicV2.getAddress());

      // 使用 V2 功能
      const data = logicV2.interface.encodeFunctionData("incrementByMultiplier", [10]);
      await owner.sendTransaction({
        to: await proxy.getAddress(),
        data: data,
      });
      expect(await proxy.counter()).to.equal(11);

      // 可以再次升级（比如回退到 V1）
      await proxy.updateLogicContract(await logicV1.getAddress());
      expect(await proxy.logicContract()).to.equal(await logicV1.getAddress());

      // 状态依然保留
      expect(await proxy.counter()).to.equal(11);
    });
  });
});
