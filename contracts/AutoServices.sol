// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity=0.7.6;
pragma abicoder v2;

import './TransferHelper.sol';
import './libraries/LiquidityAmounts.sol';
import './interfaces/INonfungiblePositionManager.sol';
import './interfaces/ISwapRouter.sol';
import './interfaces/IAutoService.sol';

// Импортируем контракт оракула Uniswap
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

// Собирает fee и реинвестирует её
contract AutoServices is IAutoServices
{
    // =================================
    // Storage
    // =================================
    INonfungiblePositionManager nonfungiblePositionManager;
    ISwapRouter swapRouter;

    struct NftOptions
    {
        // check for Rebalancer
        bool isAvailableRebalancer;
        // check for AutoCompound
        bool isAvailableAutoCompound;    
        // percent btfore perod-end to start rebalance
        uint8 percentRebalancer;
    }

    /// @dev The token ID position data
    mapping(uint256 => NftOptions) public _NftOptions;

    // =================================
    // Constructor
    // =================================

    constructor(INonfungiblePositionManager _nonfungiblePositionManager, ISwapRouter _swapRouter) {
        nonfungiblePositionManager = _nonfungiblePositionManager;
        swapRouter = _swapRouter;
    }

    // =================================
    // Main Setters
    // =================================

    event NftOptionsLife(uint256 indexed tokenId, 
          address token0, address token1, uint24 minTick, uint24 maxTick, 
          bool isAvailableRebalancer, bool isAvailableAutoCompound, uint8 percentRebalancer);

    function setNftOptions(uint256 tokenId, bool isAvailableRebalancer, bool isAvailableAutoCompound, uint8 percentRebalancer) external override
    {
        require(nonfungiblePositionManager.ownerOf(tokenId) == msg.sender, "Not owner of this token");
        _NftOptions[tokenId].isAvailableRebalancer = isAvailableRebalancer;
        _NftOptions[tokenId].isAvailableAutoCompound = isAvailableAutoCompound;
        _NftOptions[tokenId].percentRebalancer = percentRebalancer;

        (,,address token0,address token1,,int24 minTick,int24 maxTick,,,,,) = nonfungiblePositionManager.positions(tokenId);
        emit NftOptionsLife(tokenId,
        token0,token1,minTick,maxTick,
        isAvailableRebalancer, isAvailableAutoCompound, percentRebalancer);
    }

    // =================================
    // Main Functions
    // =================================

    function makeAutoCompound(uint256 tokenId) external override
    {
        require(_NftOptions[tokenId].isAvailableAutoCompound==true, "Token is not alligeble for auto compound");
        (,,address token0,address token1,uint24 fee,int24 minTickOld,int24 maxTickOld,,,,,) = nonfungiblePositionManager.positions(tokenId);
        // базовый метод
        makePreWork(tokenId, token0, token1, fee, minTickOld, maxTickOld);
        // Создаём новую ликвидность (интервал)
        nonfungiblePositionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: TransferHelper.safeGetBalance(token0, address(this)),
                amount1Desired: TransferHelper.safeGetBalance(token1, address(this)),
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
    }


    function makeRebalancer(uint256 tokenId) external override
    {
        require(_NftOptions[tokenId].isAvailableRebalancer==true, "Token is not alligeble for Rebalancer");
        (,,address token0,address token1,uint24 fee,int24 minTickOld, int24 maxTickOld, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        // Удаляем старую ликвидность (интервал)
        nonfungiblePositionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        // базовый метод
        makePreWork(tokenId, token0, token1, fee, minTickOld, maxTickOld);

        // Получаю текущую цену токена0 в токене1
        IUniswapV3Pool pool = IUniswapV3Pool(IUniswapV3Factory(nonfungiblePositionManager.factory()).getPool(token0, token1, fee));
        (, int24 currentTick, , , , , ) = pool.slot0();
        
        // Создаём новую ликвидность (интервал)
        int24 tickSpacing = pool.tickSpacing();
        
        nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: ((currentTick - int24((maxTickOld-minTickOld) / 2)) / tickSpacing) * tickSpacing,
                tickUpper: ((currentTick + int24((maxTickOld-minTickOld) / 2)) / tickSpacing) * tickSpacing,
                amount0Desired: TransferHelper.safeGetBalance(token0, address(this)),
                amount1Desired: TransferHelper.safeGetBalance(token1, address(this)),
                amount0Min: 0,
                amount1Min: 0,
                recipient: nonfungiblePositionManager.ownerOf(tokenId),   // Получаю владельца NFT
                deadline: block.timestamp
            })
        );
        

    }

    // =================================
    // Internal Functions
    // =================================

    function makePreWork(uint256 tokenId, address token0,address token1,uint24 fee,int24 minTick,int24 maxTick) internal
    {
        
        // (,,address token0,address token1,uint24 fee,int24 minTick,int24 maxTick,uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);

        TransferHelper.safeApprove(token0, address(swapRouter), type(uint256).max);
        TransferHelper.safeApprove(token1, address(swapRouter), type(uint256).max);
        TransferHelper.safeApprove(token0, address(nonfungiblePositionManager), type(uint256).max);
        TransferHelper.safeApprove(token1, address(nonfungiblePositionManager), type(uint256).max);

        // Получаем fee в виде токенов на адресе контракта
        // Чтобы узнать, сколько токенов fee мы получили,
        // нужно считать объём полученных токенов на адресе контракта.
        collectFees(tokenId, address(this));

        // Рассчитываем, сколько должно  быть токена 0 и токена 1 в идеале для пополнения позиции
        // в единицах самого токена соответствующего
        uint160 sqrtPriceX96 = getSqrtRatioX96(token0,token1,fee);
        (uint256 token0AmountDesired, uint256 token1AmountDesired) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(minTick),
            TickMath.getSqrtRatioAtTick(maxTick),
            uint128(
                (
                    (TransferHelper.safeGetBalance(token0, address(this)) + getSpotPrice(token1, TransferHelper.safeGetBalance(token1, address(this)), token0, sqrtPriceX96))
                    * 1e18 / getPriceForLiquidityInToken0(token0, token1, minTick, maxTick, sqrtPriceX96)
                )
            )
        );

        // Производим конвертацию, того токена, которого больше чем нужно,
        // в тот, которого меньше чем нужно
        if (token0AmountDesired > TransferHelper.safeGetBalance(token0, address(this))) {            
            swapRouter.exactOutputSingle(
                ISwapRouter.ExactOutputSingleParams({
                    tokenIn: token1,
                    tokenOut: token0,
                    fee: fee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountOut: token0AmountDesired - TransferHelper.safeGetBalance(token0, address(this)),
                    amountInMaximum: type(uint256).max,
                    sqrtPriceLimitX96: 0
                })
            );           
        } else if (token1AmountDesired > TransferHelper.safeGetBalance(token1, address(this))) {
            swapRouter.exactOutputSingle(
                ISwapRouter.ExactOutputSingleParams({
                    tokenIn: token0,
                    tokenOut: token1,
                    fee: fee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountOut: token1AmountDesired - TransferHelper.safeGetBalance(token1, address(this)),
                    amountInMaximum: type(uint256).max,
                    sqrtPriceLimitX96: 0
                })
            );   
        }
        
    }





    // =================================
    // Internal Functions
    // =================================

    // Считает стоимость ликвидности в единицах токена0
    function getPriceForLiquidityInToken0(address token0, address token1, int24 minTick, int24 maxTick, uint160 sqrtRatioX96) internal pure returns (uint256) 
    {
        (uint256 a, uint256 b) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(minTick),
            TickMath.getSqrtRatioAtTick(maxTick),
            1e18
        );
        return (getSpotPrice(token1, b, token0, sqrtRatioX96) + a);
    }

    // Считаем количество tokenOut,
    // соответствующее по эквити tokenIn в количестве amountIn,
    // учитывая цену между ними таковой - sqrtRatioX96
    function getSpotPrice(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint160 sqrtRatioX96
    ) internal pure returns (uint256 amountOut) {
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            amountOut = tokenIn < tokenOut
                ? FullMath.mulDiv(ratioX192, uint128(amountIn), 1 << 192)
                : FullMath.mulDiv(1 << 192, uint128(amountIn), ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            amountOut = tokenIn < tokenOut
                ? FullMath.mulDiv(ratioX128, uint128(amountIn), 1 << 128)
                : FullMath.mulDiv(1 << 128, uint128(amountIn), ratioX128);
        }
    }

    // Принимаем fee в виде токенов на адресе контракта
    function collectFees(uint256 tokenId, address resipient) internal 
    {
        nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: resipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            }));
    }

    // Функция для получения квадратичной цены, на основании двух цен.
    // sqrtPriceX96 - это цена, умноженная на 2^96, 
    // так что нужно будет разделить это значение на 2^96, 
    // чтобы получить фактическую цену.
    function getSqrtRatioX96(address token0, address token1, uint24 fees) internal view returns (uint160) 
    {
        (uint160 sqrtRatioX96, , , , , , ) = IUniswapV3Pool(IUniswapV3Factory(nonfungiblePositionManager.factory()).getPool(token0,token1,fees)).slot0();
        return sqrtRatioX96;
    }

}