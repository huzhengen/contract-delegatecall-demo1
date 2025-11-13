const hre = require("hardhat");

async function main() {
  console.log("=".repeat(60));
  console.log("🚀 部署 NFT 合约");
  console.log("=".repeat(60));

  const [owner] = await hre.ethers.getSigners();
  console.log("\n📍 部署账户:", owner.address);

  // 获取合约工厂
  const NFTCollection = await hre.ethers.getContractFactory("NFTCollection");

  // 部署参数
  const name = "My NFT Collection";
  const symbol = "MNFT";
  const baseTokenURI = "https://api.mynft.com/metadata/";

  console.log("\n📦 部署参数:");
  console.log("   名称:", name);
  console.log("   符号:", symbol);
  console.log("   基础URI:", baseTokenURI);

  // 部署合约
  const nftCollection = await NFTCollection.deploy(name, symbol, baseTokenURI);
  await nftCollection.waitForDeployment();
  const contractAddress = await nftCollection.getAddress();

  console.log("\n✅ NFTCollection 部署成功");
  console.log("   地址:", contractAddress);

  // 验证部署
  console.log("\n🔍 验证部署:");
  console.log("   名称:", await nftCollection.name());
  console.log("   符号:", await nftCollection.symbol());
  console.log("   所有者:", await nftCollection.owner());
  console.log("   最大供应量:", (await nftCollection.maxSupply()).toString());

  console.log("\n" + "=".repeat(60));
  console.log("🎉 部署完成!");
  console.log("=".repeat(60));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });