const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTCollection", function () {
  let nftCollection;
  let owner;
  let addr1;
  let addr2;

  const name = "Test NFT Collection";
  const symbol = "TNFT";
  const baseTokenURI = "https://api.testnft.com/metadata/";

  beforeEach(async function () {
    // 获取签名者
    [owner, addr1, addr2] = await ethers.getSigners();

    // 部署 NFT 合约
    const NFTCollection = await ethers.getContractFactory("NFTCollection");
    nftCollection = await NFTCollection.deploy(name, symbol, baseTokenURI);
    await nftCollection.waitForDeployment();
  });

  describe("部署", function () {
    it("应该正确设置合约名称和符号", async function () {
      expect(await nftCollection.name()).to.equal(name);
      expect(await nftCollection.symbol()).to.equal(symbol);
    });

    it("应该正确设置所有者", async function () {
      expect(await nftCollection.owner()).to.equal(owner.address);
    });

    it("初始总供应量应该为 0", async function () {
      expect(await nftCollection.totalSupply()).to.equal(0);
    });
  });

  describe("铸造 NFT", function () {
    const tokenURI = "1.json";

    it("应该成功铸造一个 NFT", async function () {
      const tokenId = await nftCollection.mintNFT(addr1.address, tokenURI);
      await tokenId.wait();

      expect(await nftCollection.totalSupply()).to.equal(1);
      expect(await nftCollection.ownerOf(1)).to.equal(addr1.address);
      expect(await nftCollection.tokenURI(1)).to.equal(baseTokenURI + tokenURI);
    });

    it("应该触发 NFTMinted 事件", async function () {
      await expect(nftCollection.mintNFT(addr1.address, tokenURI))
        .to.emit(nftCollection, "NFTMinted")
        .withArgs(addr1.address, 1, tokenURI);
    });

    it("应该可以铸造多个 NFT", async function () {
      // 铸造第一个 NFT
      await nftCollection.mintNFT(addr1.address, "1.json");

      // 铸造第二个 NFT
      await nftCollection.mintNFT(addr1.address, "2.json");

      expect(await nftCollection.totalSupply()).to.equal(2);
      expect(await nftCollection.balanceOf(addr1.address)).to.equal(2);
    });

    it("批量铸造应该成功", async function () {
      const count = 3;
      const tokenURIs = ["1.json", "2.json", "3.json"];

      const tokenIds = await nftCollection.mintNFTs(addr1.address, count, tokenURIs);
      await tokenIds.wait();

      expect(await nftCollection.totalSupply()).to.equal(3);
      expect(await nftCollection.balanceOf(addr1.address)).to.equal(3);
    });
  });

  describe("元数据支持", function () {
    const tokenURI = "1.json";

    beforeEach(async function () {
      // 先铸造一个 NFT
      await nftCollection.mintNFT(addr1.address, tokenURI);
    });

    it("应该返回正确的 tokenURI", async function () {
      expect(await nftCollection.tokenURI(1)).to.equal(baseTokenURI + tokenURI);
    });

    it("所有者应该可以设置自定义 tokenURI", async function () {
      const newTokenURI = "custom.json";
      await nftCollection.connect(owner).setTokenURI(1, newTokenURI);
      expect(await nftCollection.tokenURI(1)).to.equal(baseTokenURI + newTokenURI);
    });

    it("NFT 持有者应该可以设置自己的 tokenURI", async function () {
      // 转移所有权给 addr1
      await nftCollection.connect(owner).transferFrom(owner.address, addr1.address, 1);

      const newTokenURI = "holder.json";
      await nftCollection.connect(addr1).setTokenURI(1, newTokenURI);
      expect(await nftCollection.tokenURI(1)).to.equal(baseTokenURI + newTokenURI);
    });
  });

  describe("访问控制", function () {
    const tokenURI = "1.json";

    beforeEach(async function () {
      // 先铸造一个 NFT
      await nftCollection.mintNFT(owner.address, tokenURI);
    });

    it("只有所有者才能更新基础 URI", async function () {
      const newBaseURI = "https://api.newnft.com/metadata/";
      await nftCollection.connect(owner).setBaseTokenURI(newBaseURI);
      expect(await nftCollection.tokenURI(1)).to.equal(newBaseURI + tokenURI);
    });

    it("非所有者不能更新基础 URI", async function () {
      const newBaseURI = "https://api.newnft.com/metadata/";
      await expect(nftCollection.connect(addr1).setBaseTokenURI(newBaseURI))
        .to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("只有所有者才能提取合约余额", async function () {
      // 发送一些 ETH 到合约
      await owner.sendTransaction({
        to: await nftCollection.getAddress(),
        value: ethers.parseEther("1.0")
      });

      const initialBalance = await ethers.provider.getBalance(owner.address);
      await nftCollection.connect(owner).withdraw();
      const finalBalance = await ethers.provider.getBalance(owner.address);

      expect(finalBalance).to.be.above(initialBalance);
    });
  });

  describe("供应量限制", function () {
    it("达到最大供应量时应该无法继续铸造", async function () {
      // 设置最大供应量为 1
      await nftCollection.connect(owner).setMaxSupply(1);

      // 铸造一个 NFT
      await nftCollection.mintNFT(addr1.address, "1.json");

      // 尝试再铸造一个应该失败
      await expect(nftCollection.mintNFT(addr1.address, "2.json"))
        .to.be.revertedWith("Maximum supply reached");
    });
  });
});