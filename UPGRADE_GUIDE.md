# 合约升级详细指南

## 📋 目录
1. [升级流程概述](#升级流程概述)
2. [详细步骤说明](#详细步骤说明)
3. [代码示例](#代码示例)
4. [注意事项](#注意事项)

---

## 升级流程概述

```
┌─────────────────┐
│  部署 LogicV1   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  部署 Proxy     │ ← 指向 LogicV1
│  (保存状态)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  使用 Proxy     │ ← 状态累积（counter = 3）
│  调用 V1 功能   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  部署 LogicV2   │ ← 新的逻辑合约
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 调用 Proxy 的   │ ⭐ 关键步骤
│updateLogicContract│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Proxy 现在     │ ← 指向 LogicV2
│  指向 V2        │    状态保留（counter = 3）
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  使用 V2 功能   │ ← 新功能立即可用
└─────────────────┘
```

---

## 详细步骤说明

### 步骤 1: 部署原始逻辑合约 (V1)

```javascript
const LogicV1 = await ethers.getContractFactory("LogicContract");
const logicV1 = await LogicV1.deploy();
await logicV1.waitForDeployment();
const logicV1Address = await logicV1.getAddress();

console.log("LogicV1 地址:", logicV1Address);
// 输出: 0x5FbDB2315678afecb367f032d93F642f64180aa3
```

**说明：**
- 部署包含业务逻辑的合约
- 记录合约地址，后续需要用到

---

### 步骤 2: 部署代理合约

```javascript
const Proxy = await ethers.getContractFactory("ProxyContract");
const proxy = await Proxy.deploy(logicV1Address);  // 传入 V1 地址
await proxy.waitForDeployment();
const proxyAddress = await proxy.getAddress();

console.log("Proxy 地址:", proxyAddress);
// 输出: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512

console.log("Proxy 指向:", await proxy.logicContract());
// 输出: 0x5FbDB2315678afecb367f032d93F642f64180aa3 (V1 地址)
```

**说明：**
- 代理合约在构造函数中接收逻辑合约地址
- 代理合约地址是固定的，用户始终使用这个地址
- 代理合约内部存储了逻辑合约的地址

---

### 步骤 3: 使用代理合约（累积状态）

```javascript
// 初始状态
console.log("Counter:", await proxy.counter());  // 0

// 调用 V1 功能
await proxy.incrementViaDelegate();
await proxy.incrementViaDelegate();
await proxy.incrementViaDelegate();

console.log("Counter:", await proxy.counter());  // 3
```

**说明：**
- 用户通过代理合约调用功能
- 所有状态变化都保存在代理合约中
- 逻辑合约 V1 的状态不变

---

### 步骤 4: 部署新的逻辑合约 (V2)

```javascript
const LogicV2 = await ethers.getContractFactory("LogicContractV2");
const logicV2 = await LogicV2.deploy();
await logicV2.waitForDeployment();
const logicV2Address = await logicV2.getAddress();

console.log("LogicV2 地址:", logicV2Address);
// 输出: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
```

**说明：**
- V2 包含所有 V1 的功能 + 新功能
- V2 的状态变量布局必须与 V1 兼容
- 新变量只能添加在最后

---

### 步骤 5: 更新代理合约指向 ⭐ 关键步骤

这是最关键的一步！有两种方式：

#### 方式 1: 直接调用 updateLogicContract（推荐）

```javascript
// 升级前
console.log("升级前指向:", await proxy.logicContract());
// 输出: 0x5FbDB2315678afecb367f032d93F642f64180aa3 (V1)

console.log("升级前 Counter:", await proxy.counter());
// 输出: 3

// ⭐ 执行升级
const tx = await proxy.updateLogicContract(logicV2Address);
await tx.wait();

// 升级后
console.log("升级后指向:", await proxy.logicContract());
// 输出: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 (V2)

console.log("升级后 Counter:", await proxy.counter());
// 输出: 3 (状态保留！)
```

**ProxyContract.sol 中的实现：**
```solidity
function updateLogicContract(address _newLogicContract) public {
    require(msg.sender == owner, "Only owner can update logic contract");
    logicContract = _newLogicContract;  // 更新存储槽 2 的值
}
```

**这一步发生了什么：**
1. 检查调用者是否是所有者（权限控制）
2. 将 `logicContract` 变量（存储槽 2）的值从 V1 地址改为 V2 地址
3. 代理合约的其他状态（counter, owner）完全不变
4. 交易完成后，代理合约就指向新的逻辑合约了

#### 方式 2: 使用 ethers.js 发送交易

```javascript
const [owner] = await ethers.getSigners();

const tx = await owner.sendTransaction({
  to: proxyAddress,
  data: proxy.interface.encodeFunctionData("updateLogicContract", [logicV2Address])
});
await tx.wait();
```

---

### 步骤 6: 验证升级并使用新功能

```javascript
// 验证升级成功
console.log("当前指向:", await proxy.logicContract());
// 输出: V2 地址

// 使用 V1 的原有功能（仍然可用）
await proxy.incrementViaDelegate();
console.log("Counter:", await proxy.counter());  // 4

// 使用 V2 的新功能
const data = logicV2.interface.encodeFunctionData("incrementByMultiplier", [10]);
await owner.sendTransaction({
  to: proxyAddress,
  data: data
});
console.log("Counter:", await proxy.counter());  // 14

// 使用 V2 的 decrement 功能
const data2 = logicV2.interface.encodeFunctionData("decrement");
await owner.sendTransaction({
  to: proxyAddress,
  data: data2
});
console.log("Counter:", await proxy.counter());  // 13
```

---

## 代码示例

### 完整的升级脚本

运行演示脚本：
```bash
npx hardhat run scripts/upgrade-demo.js
```

### 运行测试

```bash
npx hardhat test test/Upgrade.test.js
```

---

## 注意事项

### ⚠️ 1. 状态变量布局必须兼容

**错误示例：**
```solidity
// V1
contract LogicV1 {
    uint256 public counter;  // 槽 0
    address public owner;    // 槽 1
}

// V2 - ❌ 错误！改变了顺序
contract LogicV2 {
    address public owner;    // 槽 0 ❌
    uint256 public counter;  // 槽 1 ❌
}
```

**正确示例：**
```solidity
// V1
contract LogicV1 {
    uint256 public counter;  // 槽 0
    address public owner;    // 槽 1
}

// V2 - ✅ 正确！保持顺序，新变量添加在最后
contract LogicV2 {
    uint256 public counter;  // 槽 0 ✅
    address public owner;    // 槽 1 ✅
    uint256 public newVar;   // 槽 2 ✅ 新变量
}
```

### ⚠️ 2. 权限控制

```solidity
function updateLogicContract(address _newLogicContract) public {
    require(msg.sender == owner, "Only owner can update");
    logicContract = _newLogicContract;
}
```

- 只有所有者可以升级
- 生产环境建议使用多签钱包或 DAO 治理

### ⚠️ 3. 升级前的验证

升级前应该：
1. 在测试网充分测试 V2
2. 审计 V2 的代码
3. 验证状态变量布局兼容性
4. 准备回滚方案

### ⚠️ 4. 升级是立即生效的

```javascript
await proxy.updateLogicContract(logicV2Address);
// 这一行执行后，所有用户立即使用 V2 的逻辑
```

### ⚠️ 5. 可以回滚

如果 V2 有问题，可以回滚到 V1：
```javascript
await proxy.updateLogicContract(logicV1Address);
```

---

## 实际应用场景

### 场景 1: 修复 Bug
```
V1 有 bug → 部署 V2（修复 bug）→ 升级 → 用户立即使用修复后的版本
```

### 场景 2: 添加新功能
```
V1 功能有限 → 部署 V2（新功能）→ 升级 → 用户可以使用新功能
```

### 场景 3: 优化 Gas
```
V1 Gas 消耗高 → 部署 V2（优化）→ 升级 → 降低用户成本
```

---

## 总结

**更新代理合约指向新地址的核心就是：**

```solidity
// 在 ProxyContract 中调用
proxy.updateLogicContract(newLogicAddress);
```

这个函数做的事情很简单：
```solidity
logicContract = _newLogicContract;  // 更新一个地址变量
```

但效果很强大：
- ✅ 代理合约地址不变（用户无感知）
- ✅ 所有状态数据保留
- ✅ 逻辑立即切换到新版本
- ✅ 新功能立即可用
