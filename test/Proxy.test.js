const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Proxy and NFTCollectionV2 Delegatecall Tests", function () {
  let proxy;
  let nftCollectionV2;
  let upgradeManager;
  let owner;
  let addr1;
  let addr2;
  let proxyAdmin;

  const name = "Test NFT Collection";
  const symbol = "TNFT";
  const baseTokenURI = "https://api.testnft.com/metadata/";

  beforeEach(async function () {
    // 获取签名者
    [owner, addr1, addr2, proxyAdmin] = await ethers.getSigners();

    // 部署 NFTCollectionV2 逻辑合约
    const NFTCollectionV2 = await ethers.getContractFactory("NFTCollectionV2");
    nftCollectionV2 = await NFTCollectionV2.deploy();
    await nftCollectionV2.waitForDeployment();

    // 部署代理合约，指向 NFTCollectionV2
    const Proxy = await ethers.getContractFactory("Proxy");
    proxy = await Proxy.deploy(await nftCollectionV2.getAddress());
    await proxy.waitForDeployment();

    // 部署升级管理器
    const UpgradeManager = await ethers.getContractFactory("UpgradeManager");
    upgradeManager = await UpgradeManager.deploy();
    await upgradeManager.waitForDeployment();

    // 注册代理到升级管理器
    await upgradeManager.registerProxy(await proxy.getAddress(), proxyAdmin.address);

    // 通过代理初始化 NFT 合约
    const proxyAsNFT = await ethers.getContractAt("NFTCollectionV2", await proxy.getAddress());
    await proxyAsNFT.initialize(name, symbol, baseTokenURI);
  });

  describe("代理合约基本功能", function () {
    it("应该正确设置初始实现合约地址", async function () {
      const implementation = await proxy.getImplementation();
      expect(implementation).to.equal(await nftCollectionV2.getAddress());
    });

    it("应该正确设置初始管理员地址", async function () {
      const admin = await proxy.getAdmin();
      expect(admin).to.equal(owner.address);
    });

    it("代理应该正确转发调用到实现合约", async function () {
      const proxyAsNFT = await ethers.getContractAt("NFTCollectionV2", await proxy.getAddress());

      expect(await proxyAsNFT.name()).to.equal(name);
      expect(await proxyAsNFT.symbol()).to.equal(symbol);
      expect(await proxyAsNFT.owner()).to.equal(owner.address);
    });

    it("应该能够升级实现合约", async function () {
      // 部署新版本的 NFT 合约
      const NFTCollectionV2_New = await ethers.getContractFactory("NFTCollectionV2");
      const newNFTCollectionV2 = await NFTCollectionV2_New.deploy();
      await newNFTCollectionV2.waitForDeployment();

      const oldImplementation = await proxy.getImplementation();

      // 升级实现合约
      await proxy.upgradeImplementation(await newNFTCollectionV2.getAddress());

      const newImplementation = await proxy.getImplementation();
      expect(newImplementation).to.equal(await newNFTCollectionV2.getAddress());
      expect(newImplementation).to.not.equal(oldImplementation);
    });

    it("非管理员不能升级实现合约", async function () {
      const NFTCollectionV2_New = await ethers.getContractFactory("NFTCollectionV2");
      const newNFTCollectionV2 = await NFTCollectionV2_New.deploy();
      await newNFTCollectionV2.waitForDeployment();

      await expect(
        proxy.connect(addr1).upgradeImplementation(await newNFTCollectionV2.getAddress())
      ).to.be.revertedWith("Only admin can upgrade");
    });
  });

  describe("升级管理器功能", function () {
    it("应该正确注册代理", async function () {
      const isRegistered = await upgradeManager.isRegisteredProxy(await proxy.getAddress());
      expect(isRegistered).to.be.true;

      const admin = await upgradeManager.proxyAdmins(await proxy.getAddress());
      expect(admin).to.equal(proxyAdmin.address);
    });

    it("应该能够升级已注册的代理", async function () {
      const NFTCollectionV2_New = await ethers.getContractFactory("NFTCollectionV2");
      const newNFTCollectionV2 = await NFTCollectionV2_New.deploy();
      await newNFTCollectionV2.waitForDeployment();

      const oldImplementation = await proxy.getImplementation();

      await upgradeManager.connect(proxyAdmin).upgradeProxy(
        await proxy.getAddress(),
        await newNFTCollectionV2.getAddress()
      );

      const newImplementation = await proxy.getImplementation();
      expect(newImplementation).to.equal(await newNFTCollectionV2.getAddress());
      expect(newImplementation).to.not.equal(oldImplementation);
    });

    it("非授权用户不能升级代理", async function () {
      const NFTCollectionV2_New = await ethers.getContractFactory("NFTCollectionV2");
      const newNFTCollectionV2 = await NFTCollectionV2_New.deploy();
      await newNFTCollectionV2.waitForDeployment();

      await expect(
        upgradeManager.connect(addr1).upgradeProxy(
          await proxy.getAddress(),
          await newNFTCollectionV2.getAddress()
        )
      ).to.be.revertedWith("Not authorized");
    });

    it("应该能够转移代理管理员权限", async function () {
      const newAdmin = addr2.address;
      await upgradeManager.transferProxyAdmin(await proxy.getAddress(), newAdmin);

      const admin = await upgradeManager.proxyAdmins(await proxy.getAddress());
      expect(admin).to.equal(newAdmin);
    });
  });

  describe("通过代理进行 NFT 操作", function () {
    let proxyAsNFT;

    beforeEach(async function () {
      proxyAsNFT = await ethers.getContractAt("NFTCollectionV2", await proxy.getAddress());
    });

    it("应该能够通过代理激活销售", async function () {
      await proxyAsNFT.connect(owner).setSaleState(true, false);

      expect(await proxyAsNFT.saleActive()).to.be.true;
      expect(await proxyAsNFT.presaleActive()).to.be.false;
    });

    it("应该能够通过代理铸造 NFT", async function () {
      // 激活销售
      await proxyAsNFT.connect(owner).setSaleState(true, false);

      const tokenURI = "1.json";
      await proxyAsNFT.mintNFT(addr1.address, tokenURI);

      expect(await proxyAsNFT.totalSupply()).to.equal(1);
    });

    it("应该能够通过代理设置白名单", async function () {
      const addresses = [addr1.address, addr2.address];

      await proxyAsNFT.connect(owner).setWhitelistEnabled(true);
      await proxyAsNFT.connect(owner).updateWhitelist(addresses, true);

      expect(await proxyAsNFT.whitelisted(addr1.address)).to.be.true;
      expect(await proxyAsNFT.whitelisted(addr2.address)).to.be.true;
    });

    it("应该能够通过代理提取资金", async function () {
      // 发送一些 ETH 到代理合约
      await owner.sendTransaction({
        to: await proxy.getAddress(),
        value: ethers.parseEther("1.0")
      });

      const initialBalance = await ethers.provider.getBalance(owner.address);

      await proxyAsNFT.connect(owner).withdraw();

      const finalBalance = await ethers.provider.getBalance(owner.address);
      expect(finalBalance).to.be.above(initialBalance);
    });
  });

  describe("升级后的功能保持", function () {
    it("升级后状态应该保持", async function () {
      const proxyAsNFT = await ethers.getContractAt("NFTCollectionV2", await proxy.getAddress());

      // 设置一些状态
      await proxyAsNFT.connect(owner).setMaxSupply(5000);
      await proxyAsNFT.connect(owner).setSaleState(true, false);

      // 升级实现合约
      const NFTCollectionV2_New = await ethers.getContractFactory("NFTCollectionV2");
      const newNFTCollectionV2 = await NFTCollectionV2_New.deploy();
      await newNFTCollectionV2.waitForDeployment();

      await proxy.upgradeImplementation(await newNFTCollectionV2.getAddress());

      // 检查状态是否保持
      expect(await proxyAsNFT.maxSupply()).to.equal(5000);
      expect(await proxyAsNFT.saleActive()).to.be.true;
    });

    it("升级后应该能够继续执行函数调用", async function () {
      const proxyAsNFT = await ethers.getContractAt("NFTCollectionV2", await proxy.getAddress());

      // 升级实现合约
      const NFTCollectionV2_New = await ethers.getContractFactory("NFTCollectionV2");
      const newNFTCollectionV2 = await NFTCollectionV2_New.deploy();
      await newNFTCollectionV2.waitForDeployment();

      await proxy.upgradeImplementation(await newNFTCollectionV2.getAddress());

      // 升级后应该仍然能够调用函数
      expect(await proxyAsNFT.getVersion()).to.equal("2.0.0");

      await proxyAsNFT.connect(owner).setSaleState(true, false);
      expect(await proxyAsNFT.saleActive()).to.be.true;
    });
  });

  describe("错误处理", function () {
    it("不能将实现合约设置为空地址", async function () {
      await expect(
        proxy.upgradeImplementation(ethers.ZeroAddress)
      ).to.be.revertedWith("Implementation cannot be zero address");
    });

    it("不能将实现合约设置为相同地址", async function () {
      const currentImplementation = await proxy.getImplementation();

      await expect(
        proxy.upgradeImplementation(currentImplementation)
      ).to.be.revertedWith("Same implementation address");
    });

    it("未初始化的合约不能再次初始化", async function () {
      const proxyAsNFT = await ethers.getContractAt("NFTCollectionV2", await proxy.getAddress());

      await expect(
        proxyAsNFT.initialize(name, symbol, baseTokenURI)
      ).to.be.revertedWith("Already initialized");
    });
  });
});