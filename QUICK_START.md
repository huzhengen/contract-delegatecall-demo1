# 快速开始指南

## 🎯 核心问题

**如何更新代理合约指向新的逻辑合约地址？**

## ⚡ 快速答案

```javascript
// 1. 部署新的逻辑合约
const LogicV2 = await ethers.getContractFactory("LogicContractV2");
const logicV2 = await LogicV2.deploy();
await logicV2.waitForDeployment();

// 2. 调用代理合约的 updateLogicContract 函数 ⭐
await proxy.updateLogicContract(await logicV2.getAddress());

// 3. 完成！
console.log("升级完成，状态保留，新功能可用");
```

## 🚀 运行演示

```bash
# 查看完整的升级流程演示
npx hardhat run scripts/upgrade-demo.js
```

**输出示例：**
```
🚀 开始合约升级演示
============================================================
📦 步骤 1: 部署逻辑合约 V1
✅ LogicContract V1 部署成功
   地址: 0x5FbDB2315678afecb367f032d93F642f64180aa3

📦 步骤 2: 部署代理合约
✅ ProxyContract 部署成功
   地址: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512

🔧 步骤 3: 使用代理合约（V1 功能）
   Counter: 0 → 3

📦 步骤 4: 部署逻辑合约 V2（升级版）
✅ LogicContract V2 部署成功
   地址: 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707

🔄 步骤 5: 更新代理合约指向新逻辑合约 ⭐
✅ 升级完成!
   代理合约现在指向: 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
   Counter 值（状态保留）: 3

✨ 步骤 6: 测试 V2 的新功能
   Counter: 3 → 8 → 7
   版本: v2.0.0
```

## 📚 详细文档

- **基础概念**：查看 [README.md](./README.md)
- **升级指南**：查看 [UPGRADE_GUIDE.md](./UPGRADE_GUIDE.md)
- **可视化图解**：查看 [UPGRADE_VISUAL.md](./UPGRADE_VISUAL.md)

## 🧪 运行测试

```bash
# 运行所有测试（22 个测试用例）
npx hardhat test

# 只运行升级测试
npx hardhat test test/Upgrade.test.js
```

## 💡 关键理解

### 升级改变了什么？

```
代理合约的存储：

升级前：
┌──────┬─────────────────┐
│ 槽 0 │ counter = 3     │
│ 槽 1 │ owner = 0xf39F..│
│ 槽 2 │ 0x5FbD...0aa3   │ ← V1 地址
└──────┴─────────────────┘

升级后：
┌──────┬─────────────────┐
│ 槽 0 │ counter = 3     │ ← 不变
│ 槽 1 │ owner = 0xf39F..│ ← 不变
│ 槽 2 │ 0x5FC8...5707   │ ← 只改变这个！
└──────┴─────────────────┘
```

### 为什么状态会保留？

因为状态数据存储在**代理合约**中，不在逻辑合约中。

升级只是改变了代理合约的 `logicContract` 变量（一个地址指针），其他数据完全不变。

### 为什么新功能立即可用？

因为 delegatecall 会从新地址读取代码。升级后，所有通过代理合约的调用都会使用 V2 的代码。

## 🎓 实际操作

### 使用 Hardhat Console

```bash
npx hardhat console
```

```javascript
// 获取合约工厂
const LogicV1 = await ethers.getContractFactory("LogicContract");
const LogicV2 = await ethers.getContractFactory("LogicContractV2");
const Proxy = await ethers.getContractFactory("ProxyContract");

// 部署 V1 和代理
const v1 = await LogicV1.deploy();
const proxy = await Proxy.deploy(await v1.getAddress());

// 使用 V1
await proxy.incrementViaDelegate();
console.log(await proxy.counter()); // 1

// 部署 V2
const v2 = await LogicV2.deploy();

// 升级 ⭐
await proxy.updateLogicContract(await v2.getAddress());

// 验证
console.log(await proxy.counter()); // 1 (保留)
console.log(await proxy.logicContract()); // V2 地址

// 使用 V2 新功能
const [owner] = await ethers.getSigners();
const data = v2.interface.encodeFunctionData("version");
const result = await owner.call({
  to: await proxy.getAddress(),
  data: data
});
console.log(v2.interface.decodeFunctionResult("version", result)[0]); // "v2.0.0"
```

## ⚠️ 重要提醒

1. **状态变量顺序**：V2 必须保持 V1 的状态变量顺序
2. **权限控制**：只有所有者可以调用 `updateLogicContract`
3. **立即生效**：升级后立即对所有用户生效
4. **可以回滚**：如果有问题，可以回滚到 V1

## 🎉 总结

更新代理合约指向新地址就是调用一个函数：

```javascript
await proxy.updateLogicContract(newAddress);
```

就这么简单！
