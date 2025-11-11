// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title LogicContractV2
 * @dev 升级版的逻辑合约，添加了新功能
 * 注意：状态变量的布局必须与 V1 保持一致！
 */
contract LogicContractV2 {
    // ⚠️ 必须保持与 V1 相同的状态变量顺序
    uint256 public counter;
    address public owner;
    
    // ✅ 新的状态变量只能添加在最后
    uint256 public multiplier;

    /**
     * @dev V1 的原有功能：增加计数器
     */
    function increment() public {
        counter += 1;
    }

    /**
     * @dev V1 的原有功能：获取计数器
     */
    function getCounter() public view returns (uint256) {
        return counter;
    }

    /**
     * @dev V1 的原有功能：设置计数器
     */
    function setCounter(uint256 _value) public {
        counter = _value;
    }

    /**
     * @dev 🆕 V2 新增功能：按倍数增加计数器
     */
    function incrementByMultiplier(uint256 _multiplier) public {
        counter += _multiplier;
    }

    /**
     * @dev 🆕 V2 新增功能：减少计数器
     */
    function decrement() public {
        require(counter > 0, "Counter is already 0");
        counter -= 1;
    }

    /**
     * @dev 🆕 V2 新增功能：重置计数器
     */
    function reset() public {
        counter = 0;
    }

    /**
     * @dev 🆕 V2 新增功能：设置倍数
     */
    function setMultiplier(uint256 _multiplier) public {
        multiplier = _multiplier;
    }

    /**
     * @dev 🆕 V2 新增功能：获取版本号
     */
    function version() public pure returns (string memory) {
        return "v2.0.0";
    }
}
