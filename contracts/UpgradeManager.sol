// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Proxy.sol";

/**
 * @title UpgradeManager
 * @dev 管理多个代理合约并处理升级的合约
 */
contract UpgradeManager {
    mapping(address => address) public proxyAdmins; // 代理地址到管理员地址的映射

    address[] public proxies; // 此合约管理的所有代理地址数组

    address public owner; // 升级管理器的所有者

    // 事件
    event ProxyRegistered(address indexed proxy, address indexed admin); // 代理注册事件
    event ProxyUpgraded(address indexed proxy, address indexed oldImplementation, address indexed newImplementation); // 代理升级事件
    event ProxyAdminTransferred(address indexed proxy, address indexed oldAdmin, address indexed newAdmin); // 代理管理员转移事件

    // 修饰符
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function"); // 确保只有所有者可以调用
        _;
    }

    modifier validProxy(address proxy) {
        require(proxyAdmins[proxy] != address(0), "Proxy not registered"); // 确保代理已注册
        _;
    }

    /**
     * @dev 构造函数
     */
    constructor() {
        owner = msg.sender; // 设置所有者为部署者
    }

    /**
     * @dev 注册新的代理合约
     * @param proxy 代理合约的地址
     * @param admin 代理管理员的地址
     */
    function registerProxy(address proxy, address admin) external onlyOwner {
        require(proxy != address(0), "Proxy cannot be zero address"); // 确保代理地址不是零地址
        require(admin != address(0), "Admin cannot be zero address"); // 确保管理员地址不是零地址
        require(proxyAdmins[proxy] == address(0), "Proxy already registered"); // 确保代理未注册

        proxyAdmins[proxy] = admin; // 设置代理管理员
        proxies.push(proxy); // 添加到代理数组

        emit ProxyRegistered(proxy, admin); // 触发代理注册事件
    }

    /**
     * @dev 注销代理合约
     * @param proxy 要注销的代理合约地址
     */
    function unregisterProxy(address proxy) external onlyOwner validProxy(proxy) {
        require(msg.sender == owner || msg.sender == proxyAdmins[proxy], "Not authorized"); // 确保有权限

        delete proxyAdmins[proxy]; // 从映射中删除

        for (uint256 i = 0; i < proxies.length; i++) { // 从数组中删除
            if (proxies[i] == proxy) { // 找到匹配的代理
                proxies[i] = proxies[proxies.length - 1]; // 用最后一个元素替换
                proxies.pop(); // 删除最后一个元素
                break;
            }
        }
    }

    /**
     * @dev 升级代理合约的实现（仅所有者或代理管理员）
     * @param proxy 代理合约的地址
     * @param newImplementation 新实现合约的地址
     */
    function upgradeProxy(address payable proxy, address newImplementation) external {
        require(msg.sender == owner || msg.sender == proxyAdmins[proxy], "Not authorized"); // 确保有权限
        require(proxyAdmins[proxy] != address(0), "Proxy not registered"); // 确保代理已注册

        address oldImplementation = Proxy(proxy).getImplementation(); // 获取旧实现地址
        Proxy(proxy).upgradeImplementation(newImplementation); // 升级实现

        emit ProxyUpgraded(proxy, oldImplementation, newImplementation); // 触发代理升级事件
    }

    /**
     * @dev 转移代理管理员权限（仅所有者）
     * @param proxy 代理合约的地址
     * @param newAdmin 新管理员的地址
     */
    function transferProxyAdmin(address payable proxy, address newAdmin) external onlyOwner validProxy(proxy) {
        require(newAdmin != address(0), "Admin cannot be zero address"); // 确保新管理员地址不是零地址

        address oldAdmin = proxyAdmins[proxy]; // 保存旧管理员地址
        proxyAdmins[proxy] = newAdmin; // 设置新管理员

        Proxy(proxy).transferAdmin(newAdmin); // 在代理合约中转移管理员权限

        emit ProxyAdminTransferred(proxy, oldAdmin, newAdmin); // 触发代理管理员转移事件
    }

    /**
     * @dev 获取已注册代理的数量
     * @return 已注册代理的数量
     */
    function getProxyCount() external view returns (uint256) {
        return proxies.length; // 返回代理数组长度
    }

    /**
     * @dev 获取所有已注册的代理地址
     * @return 代理地址数组
     */
    function getAllProxies() external view returns (address[] memory) {
        return proxies; // 返回代理数组
    }

    /**
     * @dev 检查地址是否为已注册的代理
     * @param proxy 要检查的地址
     * @return 如果地址是已注册的代理则返回 true
     */
    function isRegisteredProxy(address proxy) external view returns (bool) {
        return proxyAdmins[proxy] != address(0); // 检查代理是否已注册
    }

    /**
     * @dev 转移升级管理器的所有权
     * @param newOwner 新所有者的地址
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Owner cannot be zero address"); // 确保新所有者地址不是零地址
        owner = newOwner; // 设置新所有者
    }
}
