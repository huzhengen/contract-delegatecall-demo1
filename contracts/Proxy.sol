// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Proxy
 * @dev 使用 delegatecall 将调用转发到实现合约的简单代理合约
 * @dev 此实现遵循 EIP-1822 通用可升级代理标准 (UUPS)
 */
contract Proxy {
    address private _implementation; // 实现合约地址

    address private _admin; // 可以升级实现的管理员地址

    uint256[50] private __gap; // 存储间隙，用于在实现合约中允许未来的状态变量，防止升级时的存储冲突

    // 事件
    event ImplementationUpdated(address indexed oldImplementation, address indexed newImplementation); // 实现更新事件
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin); // 管理员更新事件

    /**
     * @dev 构造函数，设置初始实现和管理员
     * @param implementation_ 初始实现合约的地址
     */
    constructor(address implementation_) {
        require(implementation_ != address(0), "Implementation cannot be zero address"); // 确保实现地址不是零地址
        _implementation = implementation_; // 设置实现地址
        _admin = msg.sender; // 设置管理员为部署者

        emit ImplementationUpdated(address(0), implementation_); // 触发实现更新事件
    }

    /**
     * @dev 回退函数，将调用委托给实现合约
     */
    fallback() external payable {
        _delegate(_implementation); // 委托调用到实现合约
    }

    /**
     * @dev 接收函数，接受普通的以太币转账
     */
    receive() external payable {
        _delegate(_implementation); // 委托调用到实现合约
    }

    /**
     * @dev 执行 delegatecall 的内部函数
     * @param implementation_ 要委托调用的地址
     */
    function _delegate(address implementation_) internal {
        assembly {
            let ptr := mload(0x40) // 加载空闲内存指针
            mstore(ptr, implementation_) // 存储实现地址

            calldatacopy(add(ptr, 0x20), 0, calldatasize()) // 将调用数据复制到内存

            let result := delegatecall(gas(), implementation_, add(ptr, 0x20), calldatasize(), 0, 0) // 执行 delegatecall

            let size := returndatasize() // 获取返回数据大小

            returndatacopy(ptr, 0, size) // 将返回数据复制到内存

            switch result // 检查 delegatecall 是否成功
            case 0 { revert(ptr, size) } // 失败则回滚
            default { return(ptr, size) } // 成功则返回数据
        }
    }

    /**
     * @dev 升级实现合约（仅管理员）
     * @param newImplementation 新实现合约的地址
     */
    function upgradeImplementation(address newImplementation) external {
        require(msg.sender == _admin, "Only admin can upgrade"); // 确保只有管理员可以升级
        require(newImplementation != address(0), "Implementation cannot be zero address"); // 确保新实现地址不是零地址
        require(newImplementation != _implementation, "Same implementation address"); // 确保不是相同的实现地址

        address oldImplementation = _implementation; // 保存旧实现地址
        _implementation = newImplementation; // 设置新实现地址

        emit ImplementationUpdated(oldImplementation, newImplementation); // 触发实现更新事件
    }

    /**
     * @dev 将管理员权限转移到新地址（仅管理员）
     * @param newAdmin 新管理员的地址
     */
    function transferAdmin(address newAdmin) external {
        require(msg.sender == _admin, "Only admin can transfer admin rights"); // 确保只有管理员可以转移权限
        require(newAdmin != address(0), "Admin cannot be zero address"); // 确保新管理员地址不是零地址

        address oldAdmin = _admin; // 保存旧管理员地址
        _admin = newAdmin; // 设置新管理员地址

        emit AdminUpdated(oldAdmin, newAdmin); // 触发管理员更新事件
    }

    /**
     * @dev 获取当前实现地址
     * @return 当前实现合约的地址
     */
    function getImplementation() external view returns (address) {
        return _implementation; // 返回实现地址
    }

    /**
     * @dev 获取当前管理员地址
     * @return 当前管理员的地址
     */
    function getAdmin() external view returns (address) {
        return _admin; // 返回管理员地址
    }
}
