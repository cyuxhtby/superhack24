// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {PythUtils} from "@pythnetwork/pyth-sdk-solidity/PythUtils.sol";

/// @dev Market-Weighted Index Fund Vault
contract Vault is IVault, ERC20 {
    using SafeERC20 for IERC20;

    struct Asset {
        IERC20 token;
        uint256 balance;
        bytes32 priceFeedId;
    }

    struct Pool {
        address token0;
        address token1;
        bool isActive;
    }

    mapping(address => Asset) public assets;
    mapping(address => Pool) public pools;
    address[] public assetList;

    uint256 constant PRECISION = 1e18;

    modifier onlyLM() {
        // TODO
        _;
    }

    IPyth public pyth;

    constructor(
        address[] memory _tokens,
        bytes32[] memory _priceFeedIds,
        address pythContract,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        if (_tokens.length != _priceFeedIds.length) revert Vault__TokensAndOraclesLengthMismatch();

        pyth = IPyth(pythContract);

        for (uint256 i = 0; i < _tokens.length; i++) {
            assets[_tokens[i]] = Asset({
                token: IERC20(_tokens[i]),
                balance: 0,
                priceFeedId: _priceFeedIds[i]
            });
            assetList.push(_tokens[i]);
        }
    }

    function addPool(address _pool, address _token0, address _token1) external onlyLM {
        if (pools[_pool].isActive) revert Vault__PoolAlreadyExists();
        if (assets[_token0].token == IERC20(address(0)) || assets[_token1].token == IERC20(address(0))) 
            revert Vault__TokenNotSupported();

        pools[_pool] = Pool({
            token0: _token0,
            token1: _token1,
            isActive: true
        });

        emit PoolAdded(_pool, _token0, _token1);
    }

    function removePool(address _pool) external onlyLM {
        if (!pools[_pool].isActive) revert Vault__PoolDoesNotExist();
        pools[_pool].isActive = false;

        emit PoolRemoved(_pool);
    }

    // `pythUpdateData` is the binary pyth price update data retrieved from Pyth's Hermes API,
    // it updates the onchain price if the provided update is more recent than the current onchain price.
    function deposit(uint256[] calldata _amounts, bytes[] calldata pythUpdateData) external payable returns (uint256 lpTokensMinted) {
        if (_amounts.length != assetList.length) revert Vault__IncorrectAmountsLength();

        uint256 fee = pyth.getUpdateFee(pythUpdateData);
        pyth.updatePriceFeeds{value: fee}(pythUpdateData);

        uint256 totalValue = 0;
        uint256 totalSupplyCache = totalSupply();

        for (uint256 i = 0; i < assetList.length; i++) {
            address assetAddress = assetList[i];
            uint256 amount = _amounts[i];

            if (amount == 0) revert Vault__AmountMustBeGreaterThanZero();

            Asset storage asset = assets[assetAddress];
            asset.token.safeTransferFrom(msg.sender, address(this), amount);
            asset.balance += amount;
            totalValue += _calculateAssetValue(assetAddress, amount);
        }

        // Calculate LP tokens to mint based on the proportion of new value to total value
        lpTokensMinted = (totalSupplyCache == 0) ? totalValue : (totalValue * totalSupplyCache) / getTotalValue();
        _mint(msg.sender, lpTokensMinted);

        emit Deposit(msg.sender, _amounts, lpTokensMinted);
    }

    function withdraw(uint256 _lpTokens, bytes[] calldata pythUpdateData) external payable returns (uint256[] memory amounts) {
        if (balanceOf(msg.sender) < _lpTokens) revert Vault__InsufficientLPTokens();

        uint256 fee = pyth.getUpdateFee(pythUpdateData);
        pyth.updatePriceFeeds{value: fee}(pythUpdateData);

        uint256 userShare = (_lpTokens * PRECISION) / totalSupply();
        amounts = new uint256[](assetList.length);

        for (uint256 i = 0; i < assetList.length; i++) {
            address assetAddress = assetList[i];
            Asset storage asset = assets[assetAddress];
            uint256 assetValue = getAssetTotalValue(assetAddress);
            uint256 amount = (assetValue * userShare) / PRECISION;
            if (amount > asset.balance) revert Vault__InsufficientAssetBalance();

            asset.balance -= amount;
            amounts[i] = amount;
            asset.token.safeTransfer(msg.sender, amount);
        }

        _burn(msg.sender, _lpTokens);

        emit Withdraw(msg.sender, _lpTokens, amounts);
    }

    function getTokensForPool(address _pool) external view override returns (address[] memory tokens) {
        Pool memory pool = pools[_pool];
        if (!pool.isActive) revert Vault__PoolDoesNotExist();

        tokens[0] = pool.token0;
        tokens[1] = pool.token1;
        return tokens;
    }

    function getReservesForPool(address _pool, address[] calldata _tokens) external view override returns (uint256[] memory reserves) {
        Pool memory pool = pools[_pool];
        if (!pool.isActive) revert Vault__PoolDoesNotExist();
        if (_tokens.length != 2 || _tokens[0] != pool.token0 || _tokens[1] != pool.token1) 
            revert Vault__InvalidTokensLength();

        reserves[0] = getVirtualReserve(_tokens[0]);
        reserves[1] = getVirtualReserve(_tokens[1]);
    }

    function claimPoolManagerFees(uint256 _feePoolManager0, uint256 _feePoolManager1) external {}

    function getVirtualReserve(address assetAddress) public view returns (uint256 virtualReserve) {
        Asset storage asset = assets[assetAddress];
        uint256 price = _getCurrentPrice(asset);
        virtualReserve = asset.balance * price / PRECISION;
    }

    function getTotalValue() public view returns (uint256 total) {
        for (uint256 i = 0; i < assetList.length; i++) {
            total += getAssetTotalValue(assetList[i]);
        }
    }

    function getAssetTotalValue(address assetAddress) public view returns (uint256 assetValue) {
        Asset storage asset = assets[assetAddress];
        uint256 price = _getCurrentPrice(asset);
        assetValue = asset.balance * price / PRECISION;
    }

    function _calculateAssetValue(address assetAddress, uint256 amount) internal view returns (uint256 assetValue) {
        uint256 price = _getCurrentPrice(assets[assetAddress]);
        assetValue = amount * price / PRECISION;
    }

    function _getCurrentPrice(Asset storage asset) internal view returns (uint256 price) {
        PythStructs.Price memory pythPrice = pyth.getPrice(asset.priceFeedId);
        if (pythPrice.price <= 0) revert Vault__InvalidOraclePrice();
        price = PythUtils.convertToUint(pythPrice.price, pythPrice.expo, 18);
    }
}
