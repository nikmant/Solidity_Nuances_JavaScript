// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity=0.7.6;
pragma abicoder v2;

import './interfaces/INonfungiblePositionManager.sol';
import './interfaces/IAutoService.sol';
import './TransferHelper.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

// Wrap over contracts "AutoService" and "NonfungiblePositionManager"
contract Panel
{
    // =================================
    // Storage
    // =================================

    IAutoServices autoServices;
    INonfungiblePositionManager immutable nonfungiblePositionManager;

    // =================================
    // Constructor
    // =================================
    constructor(INonfungiblePositionManager _nonfungiblePositionManager, IAutoServices _autoServices)
    {
        nonfungiblePositionManager = _nonfungiblePositionManager;
        autoServices = _autoServices;
    }

    // =================================
    // Main functions
    // =================================

    function destroyPosition(
        uint256 tokenID
    ) external
    {
        nonfungiblePositionManager.burn(tokenID);
        autoServices.setNftOptions(tokenID, false, false, 0);
    }

    function createPosition(
        address token0,
        address token1,
        uint24 fee,
        int24 minTick,
        int24 maxTick,
        uint256 amount0Desired,
        uint256 amount1Desired,
        bool isAvailableRebalancer,
        bool isAvailableAutoCompound,
        uint8 percentRebalancer
    ) external
    {
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0Desired);
        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), amount1Desired);
        
        (uint256 tokenID,,,) = nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: minTick,
                tickUpper: maxTick,
                amount0Desired: TransferHelper.safeGetBalance(token0, address(this)),
                amount1Desired: TransferHelper.safeGetBalance(token1, address(this)),
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        autoServices.setNftOptions(tokenID, isAvailableRebalancer, isAvailableAutoCompound, percentRebalancer);

        // Здесь хотелось бы дать права на NFT нашему autoService.
        // Но это не получится, т.к. NFT после смены владельца
        // всё равно забывает выданные разрешения.

        // Отдадаё NFT инвестору
        IERC721(address(nonfungiblePositionManager)).transferFrom(address(this), msg.sender, tokenID);
    }

}