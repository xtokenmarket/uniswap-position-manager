// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * Contract which manages an Uniswap V3 Position
 * Can rebalance and change the ticks of the position
 */
contract UniswapPositionManager {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    INonfungiblePositionManager public nftManager;
    IUniswapV3Factory public uniswapFactory;

    uint256 private constant MINT_BURN_SLIPPAGE = 100; // 1%
    // 1inch v4 exchange address
    address private constant oneInchExchange =
        0x1111111254fb6c44bAC0beD2854e76F90643097d;

    constructor(
        INonfungiblePositionManager _nftManager,
        IUniswapV3Factory _uniswapFactory
    ) {
        nftManager = _nftManager;
        uniswapFactory = _uniswapFactory;
    }

    /* ========================================================================================= */
    /*                                          Structs                                          */
    /* ========================================================================================= */

    // Parameters for reposition function input
    struct RepositionParams {
        uint256 positionId;
        int24 newTickLower;
        int24 newTickUpper;
        uint256 minAmount0Staked;
        uint256 minAmount1Staked;
        bytes oneInchData;
    }

    // Main position parameters
    struct PositionParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
    }

    /* ========================================================================================= */
    /*                                          Events                                           */
    /* ========================================================================================= */

    event Repositioned(
        uint256 indexed oldPositionId,
        uint256 indexed newPositionId,
        int24 oldLowerTick,
        int24 oldUpperTick,
        int24 newLowerTick,
        int24 newUpperTick
    );

    /* ========================================================================================= */
    /*                                        User-facing                                        */
    /* ========================================================================================= */

    /**
     * @dev Rebalance a given Uni V3 position to a new price range
     * @param params Reposition parameter structure
     */
    function reposition(RepositionParams memory params) public {
        PositionParams memory positionParams = getPositionParams(
            params.positionId
        );
        uint160 poolPrice = getPoolPrice(params.positionId);
        require(
            params.newTickLower != positionParams.tickLower ||
                params.newTickUpper != positionParams.tickUpper,
            "Need to change ticks"
        );

        // withdraw entire liquidity from the position
        (uint256 _amount0, uint256 _amount1) = withdrawAll(params.positionId);
        // burn current position NFT
        burn(params.positionId);

        // calculate how much can we deposit in the new position
        (uint256 amount0, uint256 amount1) = calculatePoolMintedAmounts(
            _amount0,
            _amount1,
            poolPrice,
            getPriceFromTick(params.newTickLower),
            getPriceFromTick(params.newTickUpper)
        );

        // approve the tokens to the uni nft manager
        IERC20(positionParams.token0).approve(address(nftManager), _amount0);
        IERC20(positionParams.token1).approve(address(nftManager), _amount1);

        // mint the position NFT and deposit the liquidity
        // user receives the new nft
        uint256 newPositionId = createPosition(
            amount0,
            amount1,
            positionParams.token0,
            positionParams.token1,
            positionParams.fee,
            params.newTickLower,
            params.newTickUpper
        );

        // swap using 1inch and stake all tokens in position after swap
        if (params.oneInchData.length != 0) {
            approveOneInch(positionParams.token0, positionParams.token1);
            oneInchSwap(params.oneInchData);
            stakePosition(
                IERC20(positionParams.token0).balanceOf(address(this)),
                IERC20(positionParams.token1).balanceOf(address(this)),
                newPositionId,
                getPoolPrice(params.positionId),
                getPriceFromTick(params.newTickLower),
                getPriceFromTick(params.newTickUpper)
            );
        }
        // Return balance not sent to user
        IERC20(positionParams.token0).transfer(
            msg.sender,
            IERC20(positionParams.token0).balanceOf(address(this))
        );
        IERC20(positionParams.token1).transfer(
            msg.sender,
            IERC20(positionParams.token1).balanceOf(address(this))
        );

        {
            // Check if balances are enough
            (
                uint256 stakedToken0Balance,
                uint256 stakedToken1Balance
            ) = getStakedTokenBalance(newPositionId);
            require(
                params.minAmount0Staked <= stakedToken0Balance &&
                    params.minAmount1Staked <= stakedToken1Balance,
                "Staked token amounts after rebalance are not enough"
            );

            emit Repositioned(
                params.positionId,
                newPositionId,
                positionParams.tickLower,
                positionParams.tickUpper,
                params.newTickLower,
                params.newTickUpper
            );
        }
    }

    /**
     * @dev Withdraws all current liquidity from the position
     */
    function withdrawAll(
        uint256 positionId
    ) private returns (uint256 _amount0, uint256 _amount1) {
        // Collect fees
        collect(positionId);
        (_amount0, _amount1) = unstakePosition(
            getPositionLiquidity(positionId),
            positionId
        );
        collectPosition(uint128(_amount0), uint128(_amount1), positionId);
    }

    /**
     * @dev Unstakes a given amount of liquidity from the Uni V3 position
     * @param liquidity amount of liquidity to unstake
     * @return amount0 token0 amount unstaked
     * @return amount1 token1 amount unstaked
     */
    function unstakePosition(
        uint128 liquidity,
        uint256 positionId
    ) private returns (uint256 amount0, uint256 amount1) {
        (uint256 _amount0, uint256 _amount1) = getAmountsForLiquidity(
            liquidity,
            positionId
        );
        (amount0, amount1) = nftManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: positionId,
                liquidity: liquidity,
                amount0Min: _amount0,
                amount1Min: _amount1,
                deadline: block.timestamp
            })
        );
    }

    /**
     * @dev Stake liquidity in position represented by tokenId NFT
     */
    function stakePosition(
        uint256 amount0,
        uint256 amount1,
        uint256 tokenId,
        uint160 poolPrice,
        uint160 priceLower,
        uint160 priceUpper
    ) private returns (uint256 stakedAmount0, uint256 stakedAmount1) {
        (
            uint256 stakeAmount0,
            uint256 stakeAmount1
        ) = calculatePoolMintedAmounts(
                amount0,
                amount1,
                poolPrice,
                priceLower,
                priceUpper
            );
        (, stakedAmount0, stakedAmount1) = nftManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: stakeAmount0,
                amount1Desired: amount1,
                amount0Min: stakeAmount0.sub(
                    stakeAmount0.div(MINT_BURN_SLIPPAGE)
                ),
                amount1Min: stakeAmount1.sub(
                    stakeAmount1.div(MINT_BURN_SLIPPAGE)
                ),
                deadline: block.timestamp
            })
        );
    }

    /**
     * @notice Collect fees generated from position
     */
    function collect(
        uint256 positionId
    ) private returns (uint256 collected0, uint256 collected1) {
        (collected0, collected1) = collectPosition(
            type(uint128).max,
            type(uint128).max,
            positionId
        );
    }

    /**
     *  @dev Collect token amounts from pool position
     */
    function collectPosition(
        uint128 amount0,
        uint128 amount1,
        uint256 positionId
    ) private returns (uint256 collected0, uint256 collected1) {
        (collected0, collected1) = nftManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: positionId,
                recipient: address(this),
                amount0Max: amount0,
                amount1Max: amount1
            })
        );
    }

    /**
     * @dev burn NFT representing a pool position with tokenId
     * @dev uses NFT Position Manager
     */
    function burn(uint256 tokenId) private {
        nftManager.burn(tokenId);
    }

    /**
     * @dev Creates the NFT token representing the pool position
     * @dev Mint initial liquidity
     */
    function createPosition(
        uint256 amount0,
        uint256 amount1,
        address token0,
        address token1,
        uint24 poolFee,
        int24 newTickLower,
        int24 newTickUpper
    ) private returns (uint256 _tokenId) {
        (_tokenId, , , ) = nftManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: poolFee,
                tickLower: newTickLower,
                tickUpper: newTickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: amount0.sub(amount0.div(MINT_BURN_SLIPPAGE)),
                amount1Min: amount1.sub(amount1.div(MINT_BURN_SLIPPAGE)),
                recipient: msg.sender,
                deadline: block.timestamp
            })
        );
    }

    /* ========================================================================================= */
    /*                               1inch Swap Helper functions                                 */
    /* ========================================================================================= */

    /**
     * @dev Swap tokens in CLR (mining pool) using 1inch v4 exchange
     * @param _oneInchData - One inch calldata, generated off-chain from their v4 api for the swap
     */
    function oneInchSwap(bytes memory _oneInchData) private {
        (bool success, ) = oneInchExchange.call(_oneInchData);

        require(success, "One inch swap call failed");
    }

    /**
     * Approve 1inch v4 for swaps
     */
    function approveOneInch(address token0, address token1) private {
        IERC20(token0).safeApprove(oneInchExchange, type(uint256).max);
        IERC20(token1).safeApprove(oneInchExchange, type(uint256).max);
    }

    /* ========================================================================================= */
    /*                               Uniswap Getter Helper functions                             */
    /* ========================================================================================= */

    /**
     * @notice Get token balances in the position
     */
    function getStakedTokenBalance(
        uint256 positionId
    ) public view returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = getAmountsForLiquidity(
            getPositionLiquidity(positionId),
            positionId
        );
    }

    /**
     * @dev Calculates the amounts deposited/withdrawn from the pool
     * amount0, amount1 - amounts to deposit/withdraw
     * amount0Minted, amount1Minted - actual amounts which can be deposited
     */
    function calculatePoolMintedAmounts(
        uint256 amount0,
        uint256 amount1,
        uint160 poolPrice,
        uint160 priceLower,
        uint160 priceUpper
    ) public view returns (uint256 amount0Minted, uint256 amount1Minted) {
        uint128 liquidityAmount = getLiquidityForAmounts(
            amount0,
            amount1,
            poolPrice,
            priceLower,
            priceUpper
        );
        (amount0Minted, amount1Minted) = getAmountsForLiquidity(
            liquidityAmount,
            poolPrice,
            priceLower,
            priceUpper
        );
    }

    /**
     * @dev Calculates single-side minted amount
     * @dev Takes an asset and amount and returns
     * @dev the amounts to deposit in the pool in the correct ratio
     * @param inputAsset - use token0 if 0, token1 else
     * @param amount - amount to deposit/withdraw
     * @param positionId - nft id of the position
     */
    function calculateAmountsMintedSingleToken(
        uint8 inputAsset,
        uint256 amount,
        uint256 positionId
    ) public view returns (uint256 amount0Minted, uint256 amount1Minted) {
        uint160 poolPrice = getPoolPrice(positionId);
        (int24 tickLower, int24 tickUpper) = getTicks(positionId);
        uint160 priceLower = getPriceFromTick(tickLower);
        uint160 priceUpper = getPriceFromTick(tickUpper);
        uint128 liquidityAmount;

        // In case the pool is out of range
        if (poolPrice < priceLower) {
            liquidityAmount = getLiquidityForAmount0(
                priceLower,
                priceUpper,
                amount
            );
        } else if (poolPrice > priceUpper) {
            liquidityAmount = getLiquidityForAmount1(
                priceLower,
                priceUpper,
                amount
            );
        } else {
            if (inputAsset == 0) {
                liquidityAmount = getLiquidityForAmount0(
                    poolPrice,
                    priceUpper,
                    amount
                );
            } else {
                liquidityAmount = getLiquidityForAmount1(
                    priceLower,
                    poolPrice,
                    amount
                );
            }
        }
        (amount0Minted, amount1Minted) = getAmountsForLiquidity(
            liquidityAmount,
            positionId
        );
    }

    function getLiquidityForAmount0(
        uint160 priceLower,
        uint160 priceUpper,
        uint256 amount0
    ) public pure returns (uint128 liquidity) {
        liquidity = LiquidityAmounts.getLiquidityForAmount0(
            priceLower,
            priceUpper,
            amount0
        );
    }

    function getLiquidityForAmount1(
        uint160 priceLower,
        uint160 priceUpper,
        uint256 amount1
    ) public pure returns (uint128 liquidity) {
        liquidity = LiquidityAmounts.getLiquidityForAmount1(
            priceLower,
            priceUpper,
            amount1
        );
    }

    /**
     * @dev Calculate pool liquidity for given token amounts
     */
    function getLiquidityForAmounts(
        uint256 amount0,
        uint256 amount1,
        uint160 poolPrice,
        uint160 priceLower,
        uint160 priceUpper
    ) public view returns (uint128 liquidity) {
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            poolPrice,
            priceLower,
            priceUpper,
            amount0,
            amount1
        );
    }

    /**
     * @dev Calculate pool liquidity for given token amounts
     */
    function getLiquidityForAmounts(
        uint256 amount0,
        uint256 amount1,
        uint256 positionId
    ) public view returns (uint128 liquidity) {
        (int24 tickLower, int24 tickUpper) = getTicks(positionId);
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            getPoolPrice(positionId),
            getPriceFromTick(tickLower),
            getPriceFromTick(tickUpper),
            amount0,
            amount1
        );
    }

    /**
     * @dev Calculate token amounts for given pool liquidity
     */
    function getAmountsForLiquidity(
        uint128 liquidity,
        uint256 positionId
    ) public view returns (uint256 amount0, uint256 amount1) {
        (int24 tickLower, int24 tickUpper) = getTicks(positionId);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            getPoolPrice(positionId),
            getPriceFromTick(tickLower),
            getPriceFromTick(tickUpper),
            liquidity
        );
    }

    /**
     * @dev Calculate token amounts for given pool liquidity
     */
    function getAmountsForLiquidity(
        uint128 liquidity,
        uint160 poolPrice,
        uint160 priceLower,
        uint160 priceUpper
    ) public view returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            poolPrice,
            priceLower,
            priceUpper,
            liquidity
        );
    }

    /**
     * @dev get price from tick
     */
    function getPriceFromTick(int24 tick) public pure returns (uint160) {
        return TickMath.getSqrtRatioAtTick(tick);
    }

    /**
     * @dev get tick from price
     */
    function getTickFromPrice(uint160 price) public pure returns (int24) {
        return TickMath.getTickAtSqrtRatio(price);
    }

    /**
     * @dev Get a pool's price from position id
     * @param positionId the position id
     */
    function getPoolPrice(
        uint256 positionId
    ) public view returns (uint160 price) {
        return getPoolPriceFromAddress(getPoolAddress(positionId));
    }

    /**
     * @dev Get a pool's price from pool address
     * @param _pool the pool address
     */
    function getPoolPriceFromAddress(
        address _pool
    ) public view returns (uint160 price) {
        IUniswapV3Pool pool = IUniswapV3Pool(_pool);
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        return sqrtRatioX96;
    }

    /* ========================================================================================= */
    /*                               Uni V3 NFT Manager Helper functions                         */
    /* ========================================================================================= */

    /**
     * @dev Returns a position's liquidity
     * @param positionId the nft id of the position
     */
    function getPositionLiquidity(
        uint256 positionId
    ) public view returns (uint128 liquidity) {
        (, , , , , , , liquidity, , , , ) = nftManager.positions(positionId);
    }

    /**
     * @dev Returns a position's fee
     * @param positionId the nft id of the position
     */
    function getFee(uint256 positionId) public view returns (uint24 fee) {
        (, , , , fee, , , , , , , ) = nftManager.positions(positionId);
    }

    /**
     * @dev Returns a position's lower and upper ticks
     * @param positionId the nft id of the position
     */
    function getTicks(
        uint256 positionId
    ) public view returns (int24 tickLower, int24 tickUpper) {
        (, , , , , tickLower, tickUpper, , , , , ) = nftManager.positions(
            positionId
        );
    }

    function getPoolAddress(
        uint256 positionId
    ) public view returns (address pool) {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            ,
            ,
            ,
            ,
            ,
            ,

        ) = nftManager.positions(positionId);
        pool = uniswapFactory.getPool(token0, token1, fee);
    }

    /**
     * @dev Returns a position's token 0 and token 1 addresses
     * @param positionId the nft id of the position
     */
    function getTokens(
        uint256 positionId
    ) public view returns (address token0, address token1) {
        (, , token0, token1, , , , , , , , ) = nftManager.positions(positionId);
    }

    /**
     * @dev Returns the parameters needed for reposition function
     * @param positionId the nft id of the position
     */
    function getPositionParams(
        uint256 positionId
    ) public view returns (PositionParams memory positionParams) {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            ,
            ,
            ,
            ,

        ) = nftManager.positions(positionId);
        return
            PositionParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper
            });
    }
}
