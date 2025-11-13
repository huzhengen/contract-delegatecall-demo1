// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Chainlink 价格预言机接口
interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
}

/**
 * @title NFTCollection
 * @dev 简单的 ERC721 NFT 集合合约，支持通过预言机以 USDT 计价
 */
contract NFTCollection is ERC721, ERC721URIStorage, Ownable {
    uint256 private _tokenIds; // 代币 ID 计数器

    string private _baseTokenURI; // 用于计算 tokenURI 的基础 URI

    mapping(uint256 => string) private _tokenURIs; // 代币 ID 到 URI 的映射

    uint256 public maxSupply = 10000; // NFT 最大供应量

    uint256 public mintPriceUSD = 1e18; // 铸造价格（1 USDT，18 位小数）

    uint256 public maxMintPerTx = 10; // 每笔交易最多可铸造的 NFT 数量

    AggregatorV3Interface public priceFeed; // BNB/USD 价格预言机

    mapping(address => bool) public whitelisted; // 预售白名单
    bool public whitelistEnabled = false; // 是否启用白名单

    uint256 public presalePrice = 0.01 ether; // 预售价格
    uint256 public publicSalePrice = 0.05 ether; // 公开销售价格

    bool public saleActive = false; // 公开销售是否激活
    bool public presaleActive = false; // 预售是否激活

    uint256 public reservedSupply = 100; // 为团队/赠品保留的 NFT 数量

    address payable public royaltyRecipient; // 版税接收地址
    uint256 public royaltyBps = 250; // 版税基点（250 = 2.5%）

    // 事件
    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI); // NFT 铸造事件
    event BaseTokenURIUpdated(string previousURI, string newURI); // 基础 URI 更新事件
    event SaleStateChanged(bool saleActive, bool presaleActive); // 销售状态变更事件
    event WhitelistStateChanged(bool enabled); // 白名单状态变更事件
    event WhitelistUpdated(address[] indexed addresses, bool indexed whitelisted); // 白名单更新事件
    event MaxSupplyUpdated(uint256 previousSupply, uint256 newSupply); // 最大供应量更新事件
    event MintPriceUpdated(uint256 previousPrice, uint256 newPrice); // 铸造价格更新事件
    event RoyaltyUpdated(address indexed recipient, uint256 bps); // 版税更新事件

    /**
     * @dev 构造函数，设置名称、符号和基础 URI
     * @param name_ NFT 集合的名称
     * @param symbol_ NFT 集合的符号
     * @param baseTokenURI_ 所有代币的基础 URI
     * @param priceFeedAddress_ BNB/USD 价格预言机地址
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseTokenURI_,
        address priceFeedAddress_
    ) ERC721(name_, symbol_) Ownable(msg.sender) { // 初始化 ERC721 和 Ownable
        _baseTokenURI = baseTokenURI_; // 设置基础 URI
        royaltyRecipient = payable(msg.sender); // 设置版税接收者为部署者
        priceFeed = AggregatorV3Interface(priceFeedAddress_); // 设置价格预言机
    }

    /**
     * @dev 使用当前销售逻辑铸造新 NFT
     * @param to 接收 NFT 的地址
     * @param tokenURI_ NFT 元数据的 URI
     * @return 新铸造的 NFT 的 ID
     */
    function mintNFT(address to, string memory tokenURI_) public payable returns (uint256) {
        require(saleActive || presaleActive, "Sale is not active"); // 要求销售或预售激活
        require(totalSupply() + 1 <= maxSupply - reservedSupply, "Exceeds available supply"); // 检查是否超过可用供应量

        uint256 price = getMintPrice(); // 获取当前铸造价格
        require(msg.value >= price, "Insufficient payment"); // 检查支付金额是否足够

        return _mintNFT(to, tokenURI_); // 执行铸造
    }

    /**
     * @dev 内部铸造函数
     */
    function _mintNFT(address to, string memory tokenURI_) internal returns (uint256) {
        uint256 newTokenId = ++_tokenIds; // 递增代币 ID
        _safeMint(to, newTokenId); // 安全铸造 NFT
        _setTokenURI(newTokenId, tokenURI_); // 设置代币 URI
        emit NFTMinted(to, newTokenId, tokenURI_); // 触发铸造事件
        return newTokenId; // 返回新代币 ID
    }

    /**
     * @dev 在一笔交易中铸造多个 NFT
     * @param to 接收 NFT 的地址
     * @param count 要铸造的 NFT 数量
     * @param tokenURIs NFT 元数据的 URI 数组
     * @return 新铸造的 NFT 的 ID 数组
     */
    function mintNFTs(address to, uint256 count, string[] memory tokenURIs) public payable returns (uint256[] memory) {
        require(count <= maxMintPerTx, "Exceeds max mint per transaction"); // 检查是否超过单笔交易最大铸造数量
        require(saleActive || presaleActive, "Sale is not active"); // 要求销售或预售激活
        require(totalSupply() + count <= maxSupply - reservedSupply, "Exceeds available supply"); // 检查是否超过可用供应量
        require(tokenURIs.length == count, "URI count must match NFT count"); // 检查 URI 数量是否匹配

        uint256 price = getMintPrice(); // 获取当前铸造价格
        uint256 totalPrice = price * count; // 计算总价格
        require(msg.value >= totalPrice, "Insufficient payment"); // 检查支付金额是否足够

        uint256[] memory newTokenIds = new uint256[](count); // 创建新代币 ID 数组

        for (uint256 i = 0; i < count; i++) { // 循环铸造
            newTokenIds[i] = _mintNFT(to, tokenURIs[i]); // 铸造每个 NFT
        }

        return newTokenIds; // 返回新代币 ID 数组
    }

    /**
     * @dev 返回代币总供应量
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIds; // 返回当前代币 ID 计数
    }

    /**
     * @dev 根据销售状态获取当前铸造价格（以 BNB 计价）
     * @return 当前铸造价格（BNB 数量）
     */
    function getMintPrice() public view returns (uint256) {
        uint256 usdPrice; // USDT 价格

        if (presaleActive && whitelistEnabled && whitelisted[msg.sender]) { // 如果是预售且启用白名单且调用者在白名单中
            usdPrice = presalePrice; // 使用预售价格
        } else if (saleActive) { // 如果是公开销售
            usdPrice = publicSalePrice; // 使用公开销售价格
        } else {
            usdPrice = mintPriceUSD; // 使用默认铸造价格（1 USDT）
        }

        return _convertUSDToBNB(usdPrice); // 将 USDT 价格转换为 BNB
    }

    /**
     * @dev 通过预言机将 USDT 价格转换为 BNB 数量
     * @param usdAmount USDT 金额（18 位小数）
     * @return BNB 数量（18 位小数）
     */
    function _convertUSDToBNB(uint256 usdAmount) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData(); // 获取 BNB/USD 最新价格
        require(price > 0, "Invalid price from oracle"); // 确保价格有效

        uint8 decimals = priceFeed.decimals(); // 获取价格精度（通常是 8）

        // 计算公式: BNB数量 = USDT金额 / (BNB价格 / 10^decimals)
        // 简化为: BNB数量 = (USDT金额 * 10^decimals) / BNB价格
        uint256 bnbAmount = (usdAmount * (10 ** decimals)) / uint256(price);

        return bnbAmount; // 返回需要支付的 BNB 数量
    }

    /**
     * @dev 设置价格预言机地址（仅所有者）
     * @param priceFeedAddress_ 新的价格预言机地址
     */
    function setPriceFeed(address priceFeedAddress_) external onlyOwner {
        require(priceFeedAddress_ != address(0), "Invalid price feed address"); // 确保地址有效
        priceFeed = AggregatorV3Interface(priceFeedAddress_); // 更新价格预言机
    }

    /**
     * @dev 获取可用供应量（不包括保留）
     * @return 公开销售的可用供应量
     */
    function availableSupply() public view returns (uint256) {
        return maxSupply - reservedSupply - totalSupply(); // 计算可用供应量
    }

    /**
     * @dev 设置销售状态（仅所有者）
     * @param _saleActive 公开销售是否激活
     * @param _presaleActive 预售是否激活
     */
    function setSaleState(bool _saleActive, bool _presaleActive) public onlyOwner {
        saleActive = _saleActive; // 设置公开销售状态
        presaleActive = _presaleActive; // 设置预售状态
        emit SaleStateChanged(_saleActive, _presaleActive); // 触发销售状态变更事件
    }

    /**
     * @dev 设置白名单状态（仅所有者）
     * @param enabled 是否启用白名单
     */
    function setWhitelistEnabled(bool enabled) public onlyOwner {
        whitelistEnabled = enabled; // 设置白名单启用状态
        emit WhitelistStateChanged(enabled); // 触发白名单状态变更事件
    }

    /**
     * @dev 添加地址到白名单（仅所有者）
     * @param addresses 要加入白名单的地址数组
     * @param _whitelisted 是否添加到白名单或从白名单移除
     */
    function updateWhitelist(address[] memory addresses, bool _whitelisted) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) { // 循环处理每个地址
            whitelisted[addresses[i]] = _whitelisted; // 更新白名单状态
        }
        emit WhitelistUpdated(addresses, _whitelisted); // 触发白名单更新事件
    }

    /**
     * @dev 设置最大供应量（仅所有者）
     * @param _maxSupply 新的最大供应量
     */
    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        require(_maxSupply >= totalSupply(), "Cannot set below current supply"); // 确保不低于当前供应量
        uint256 previousSupply = maxSupply; // 保存旧的最大供应量
        maxSupply = _maxSupply; // 设置新的最大供应量
        emit MaxSupplyUpdated(previousSupply, _maxSupply); // 触发最大供应量更新事件
    }

    /**
     * @dev 设置铸造价格（仅所有者，以 USDT 计价）
     * @param _presalePrice 新的预售价格（USDT）
     * @param _publicSalePrice 新的公开销售价格（USDT）
     */
    function setMintPrices(uint256 _presalePrice, uint256 _publicSalePrice) public onlyOwner {
        uint256 previousPresalePrice = presalePrice; // 保存旧的预售价格
        uint256 previousPublicPrice = publicSalePrice; // 保存旧的公开销售价格
        presalePrice = _presalePrice; // 设置新的预售价格（USDT）
        publicSalePrice = _publicSalePrice; // 设置新的公开销售价格（USDT）
        emit MintPriceUpdated(previousPresalePrice, _presalePrice); // 触发预售价格更新事件
        emit MintPriceUpdated(previousPublicPrice, _publicSalePrice); // 触发公开销售价格更新事件
    }

    /**
     * @dev 设置版税配置（仅所有者）
     * @param recipient 版税接收地址
     * @param bps 版税基点
     */
    function setRoyalty(address payable recipient, uint256 bps) public onlyOwner {
        require(bps <= 1000, "Royalty cannot exceed 10%"); // 确保版税不超过 10%
        royaltyRecipient = recipient; // 设置版税接收者
        royaltyBps = bps; // 设置版税基点
        emit RoyaltyUpdated(recipient, bps); // 触发版税更新事件
    }

    /**
     * @dev 为团队/赠品保留铸造（仅所有者）
     * @param to 接收 NFT 的地址
     * @param tokenURI_ NFT 元数据的 URI
     * @return 新铸造的 NFT 的 ID
     */
    function reservedMint(address to, string memory tokenURI_) public onlyOwner returns (uint256) {
        require(totalSupply() < maxSupply, "Maximum supply reached"); // 确保未达到最大供应量
        return _mintNFT(to, tokenURI_); // 执行铸造
    }

    /**
     * @dev 为团队/赠品批量保留铸造（仅所有者）
     * @param to 接收 NFT 的地址
     * @param tokenURIs NFT 元数据的 URI 数组
     * @return 新铸造的 NFT 的 ID 数组
     */
    function reservedMintBatch(address to, string[] memory tokenURIs) public onlyOwner returns (uint256[] memory) {
        require(totalSupply() + tokenURIs.length <= maxSupply, "Exceeds maximum supply"); // 确保不超过最大供应量

        uint256[] memory newTokenIds = new uint256[](tokenURIs.length); // 创建新代币 ID 数组

        for (uint256 i = 0; i < tokenURIs.length; i++) { // 循环铸造
            newTokenIds[i] = _mintNFT(to, tokenURIs[i]); // 铸造每个 NFT
        }

        return newTokenIds; // 返回新代币 ID 数组
    }

    /**
     * @dev 返回代币的版税信息（EIP-2981）
     * @param tokenId 要获取版税信息的代币 ID
     * @param salePrice 代币的销售价格
     * @return receiver 接收版税的地址
     * @return royaltyAmount 要接收的版税金额
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        require(ownerOf(tokenId) != address(0), "URI query for nonexistent token"); // 确保代币存在
        receiver = royaltyRecipient; // 返回版税接收者
        royaltyAmount = (salePrice * royaltyBps) / 10000; // 计算版税金额
    }

    /**
     * @dev 设置用于计算 tokenURI 的基础 URI
     * @param baseTokenURI_ 新的基础 URI
     */
    function setBaseTokenURI(string memory baseTokenURI_) public onlyOwner {
        string memory previousURI = _baseTokenURI; // 保存旧的基础 URI
        _baseTokenURI = baseTokenURI_; // 设置新的基础 URI
        emit BaseTokenURIUpdated(previousURI, baseTokenURI_); // 触发基础 URI 更新事件
    }

    /**
     * @dev 为特定代币设置自定义 URI
     * @param tokenId 代币的 ID
     * @param tokenURI_ 代币的自定义 URI
     */
    function setTokenURI(uint256 tokenId, string memory tokenURI_) public {
        require(ownerOf(tokenId) != address(0), "URI set of nonexistent token"); // 确保代币存在
        require(ownerOf(tokenId) == msg.sender || msg.sender == owner(), "Not owner or approved"); // 确保是所有者或已授权
        _setTokenURI(tokenId, tokenURI_); // 设置代币 URI
    }

    /**
     * @dev 返回给定代币 ID 的 URI
     * @param tokenId 代币的 ID
     * @return 代币的 URI
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId); // 返回代币 URI
    }

    /**
     * @dev 将合约余额提取给所有者
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance; // 获取合约余额
        payable(owner()).transfer(balance); // 转账给所有者
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId); // 检查是否支持接口
    }
}
