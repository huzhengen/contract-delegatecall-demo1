const hre = require("hardhat");

/**
 * 完整的升级演示脚本
 * 展示如何从 LogicContract V1 升级到 V2
 */
async function main() {
  console.log("=".repeat(60));
  console.log("🚀 开始合约升级演示");
  console.log("=".repeat(60));

  const [owner] = await hre.ethers.getSigners();
  console.log("\n📍 部署账户:", owner.address);

  // ============================================================
  // 步骤 1: 部署原始逻辑合约 V1
  // ============================================================
  console.log("\n" + "=".repeat(60));
  console.log("📦 步骤 1: 部署逻辑合约 V1");
  console.log("=".repeat(60));

  const LogicV1 = await hre.ethers.getContractFactory("LogicContract");
  const logicV1 = await LogicV1.deploy();
  await logicV1.waitForDeployment();
  const logicV1Address = await logicV1.getAddress();

  console.log("✅ LogicContract V1 部署成功");
  console.log("   地址:", logicV1Address);

  // ============================================================
  // 步骤 2: 部署代理合约，指向 V1
  // ============================================================
  console.log("\n" + "=".repeat(60));
  console.log("📦 步骤 2: 部署代理合约");
  console.log("=".repeat(60));

  const Proxy = await hre.ethers.getContractFactory("ProxyContract");
  const proxy = await Proxy.deploy(logicV1Address);
  await proxy.waitForDeployment();
  const proxyAddress = await proxy.getAddress();

  console.log("✅ ProxyContract 部署成功");
  console.log("   地址:", proxyAddress);
  console.log("   指向逻辑合约:", await proxy.logicContract());

  // ============================================================
  // 步骤 3: 使用代理合约（V1 功能）
  // ============================================================
  console.log("\n" + "=".repeat(60));
  console.log("🔧 步骤 3: 使用代理合约（V1 功能）");
  console.log("=".repeat(60));

  console.log("\n初始状态:");
  console.log("   Counter:", (await proxy.counter()).toString());

  console.log("\n执行操作: 增加计数器 3 次");
  await proxy.incrementViaDelegate();
  await proxy.incrementViaDelegate();
  await proxy.incrementViaDelegate();

  const counterAfterV1 = await proxy.counter();
  console.log("   Counter:", counterAfterV1.toString());

  // ============================================================
  // 步骤 4: 部署新的逻辑合约 V2
  // ============================================================
  console.log("\n" + "=".repeat(60));
  console.log("📦 步骤 4: 部署逻辑合约 V2（升级版）");
  console.log("=".repeat(60));

  const LogicV2 = await hre.ethers.getContractFactory("LogicContractV2");
  const logicV2 = await LogicV2.deploy();
  await logicV2.waitForDeployment();
  const logicV2Address = await logicV2.getAddress();

  console.log("✅ LogicContract V2 部署成功");
  console.log("   地址:", logicV2Address);
  console.log("\n🆕 V2 新增功能:");
  console.log("   - incrementByMultiplier(): 按倍数增加");
  console.log("   - decrement(): 减少计数器");
  console.log("   - reset(): 重置计数器");
  console.log("   - version(): 获取版本号");

  // ============================================================
  // 步骤 5: 更新代理合约指向 V2 ⭐ 关键步骤
  // ============================================================
  console.log("\n" + "=".repeat(60));
  console.log("🔄 步骤 5: 更新代理合约指向新逻辑合约");
  console.log("=".repeat(60));

  console.log("\n升级前:");
  console.log("   代理合约指向:", await proxy.logicContract());
  console.log("   Counter 值:", (await proxy.counter()).toString());

  // ⭐ 这是关键的一步：调用 updateLogicContract 函数
  console.log("\n执行升级...");
  const tx = await proxy.updateLogicContract(logicV2Address);
  await tx.wait();

  console.log("\n✅ 升级完成!");
  console.log("   代理合约现在指向:", await proxy.logicContract());
  console.log("   Counter 值（状态保留）:", (await proxy.counter()).toString());

  // ============================================================
  // 步骤 6: 验证升级后的功能
  // ============================================================
  console.log("\n" + "=".repeat(60));
  console.log("✨ 步骤 6: 测试 V2 的新功能");
  console.log("=".repeat(60));

  // 测试新功能 1: incrementByMultiplier
  console.log("\n测试 1: 使用新功能 incrementByMultiplier(5)");
  const data1 = logicV2.interface.encodeFunctionData("incrementByMultiplier", [5]);
  const tx1 = await owner.sendTransaction({
    to: proxyAddress,
    data: data1,
  });
  await tx1.wait();
  console.log("   Counter:", (await proxy.counter()).toString(), "(应该是 3 + 5 = 8)");

  // 测试新功能 2: decrement
  console.log("\n测试 2: 使用新功能 decrement()");
  const data2 = logicV2.interface.encodeFunctionData("decrement");
  const tx2 = await owner.sendTransaction({
    to: proxyAddress,
    data: data2,
  });
  await tx2.wait();
  console.log("   Counter:", (await proxy.counter()).toString(), "(应该是 8 - 1 = 7)");

  // 测试新功能 3: version
  console.log("\n测试 3: 获取版本号 version()");
  const data3 = logicV2.interface.encodeFunctionData("version");
  const result = await owner.call({
    to: proxyAddress,
    data: data3,
  });
  const version = logicV2.interface.decodeFunctionResult("version", result)[0];
  console.log("   版本:", version);

  // ============================================================
  // 总结
  // ============================================================
  console.log("\n" + "=".repeat(60));
  console.log("📊 升级总结");
  console.log("=".repeat(60));
  console.log("\n✅ 升级成功完成！");
  console.log("\n关键点:");
  console.log("   1. 代理合约地址不变:", proxyAddress);
  console.log("   2. 状态数据完全保留（Counter 从 0 → 3 → 8 → 7）");
  console.log("   3. 逻辑合约从 V1 升级到 V2");
  console.log("   4. 新功能立即可用");
  console.log("\n" + "=".repeat(60));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
