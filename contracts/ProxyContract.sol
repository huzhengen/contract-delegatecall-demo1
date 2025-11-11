// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ProxyContract
 * @dev 代理合约，使用 delegatecall 调用逻辑合约
 * delegatecall 的关键特性：
 * 1. 在调用者（代理合约）的上下文中执行被调用合约的代码
 * 2. msg.sender 和 msg.value 保持不变
 * 3. 状态变量的修改发生在代理合约的存储中
 */
contract ProxyContract {
    // 状态变量布局必须与 LogicContract 完全一致
    uint256 public counter;
    address public owner;
    
    // 逻辑合约的地址
    address public logicContract;

    event DelegateCallExecuted(address indexed logicContract, bool success);

    constructor(address _logicContract) {
        logicContract = _logicContract;
        owner = msg.sender;
    }

    /**
     * @dev 通过 delegatecall 调用逻辑合约的 increment 函数
     */
    function incrementViaDelegate() public returns (bool) {
        // 编码函数调用
        bytes memory data = abi.encodeWithSignature("increment()");
        
        // 使用 delegatecall 调用逻辑合约
        (bool success, ) = logicContract.delegatecall(data);
        
        emit DelegateCallExecuted(logicContract, success);
        require(success, "Delegatecall failed");
        
        return success;
    }

    /**
     * @dev 通过 delegatecall 调用逻辑合约的 setCounter 函数
     */
    function setCounterViaDelegate(uint256 _value) public returns (bool) {
        bytes memory data = abi.encodeWithSignature("setCounter(uint256)", _value);
        
        (bool success, ) = logicContract.delegatecall(data);
        
        emit DelegateCallExecuted(logicContract, success);
        require(success, "Delegatecall failed");
        
        return success;
    }

    /**
     * @dev 获取当前计数器的值（直接读取代理合约的状态）
     */
    function getCounter() public view returns (uint256) {
        return counter;
    }

    /**
     * @dev 更新逻辑合约地址（仅所有者可调用）
     */
    function updateLogicContract(address _newLogicContract) public {
        require(msg.sender == owner, "Only owner can update logic contract");
        logicContract = _newLogicContract;
    }

    /**
     * @dev Fallback 函数，将所有未识别的函数调用转发到逻辑合约
     * 这允许代理合约调用逻辑合约中的任何函数
     */
    fallback() external payable {
        address _impl = logicContract;
        require(_impl != address(0), "Logic contract not set");

        assembly {
            // 复制 calldata
            calldatacopy(0, 0, calldatasize())

            // 使用 delegatecall 调用逻辑合约
            let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)

            // 复制返回数据
            returndatacopy(0, 0, returndatasize())

            // 根据结果返回或回滚
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev Receive 函数，允许合约接收 ETH
     */
    receive() external payable {}
}
