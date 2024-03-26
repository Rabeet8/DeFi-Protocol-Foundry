//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/**
 * @title DSCEngine
 * @author Syed Rabeet
 *
 *
 * This is system is designed to be as minimal as possible and have the tokens maintain a 1 token ==  1peg.
 *
 * This stable coin has the properties:
 * Exogenous Collateral
 * Dolal r Peged
 * Algorithmically Stable
 
 *
 * Our DSC system should always be "overcollaterized". At no point,should the value of the all collateral <= backed value of all the USDC
 *
 * It is similar to DAI if DAI had no governance, no fees, and was only backed by WETH and WBTC.
 *
 * @notice This contract is the core of the DSC systen. It handles all the logic for mining and reddeming DSC
 * as well as deppsoting & withdrawing collateral.
 *
 * @notice This contract is very loosely based on the MakerDAO DSS (DAI) System
 */

contract DECEngine is ReentrancyGuard {
    //Error
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error revertIFHealthFactorIsBroken();
    error DSCEngine__BreakHealthFACTOR(unit256 healthFactor);
    error DSCEngine__MintFailed();

    //State Variable
    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount))
        private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    address[] private s_collateralTokens;

    DecentralizedStableCoin private i_dsc;

    //Events
    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );
    event CollateralRedeemed(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    )

    //Modifier
    modifier moreThanZero(uint256) {
        if (amount == 0) {
            revert;
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            return DSCEngine__NotAllowedToken();
        }
        _;
    }
        // @param tokenCollateralAddress the address of the token to deposit as collateral
        // @param amountCollateral the amount of collateral to deposit
        // @param amountDscToMint The amount of decentralized stable coin to mint
        // @notice this function will deposit your collateral and mint DSC in one transaction
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /*
    @notice follows CEI
    @param tokenCollateralAddress the address of the token to deposit as collateral
    @param amountCollateral The amount of collateral to deposit
    */

    //Functions
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddress,
        address dscAddress
    ) {
        //USD Price Feeds
        if (tokenAddress.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        //For eg: ETH/ USD,BTC/USD/ MKR/USD,etc
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeesAddresses[i];
            s_collateralTokens.push(tokenAddress[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    //External Function

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;
        emit CollateralDeposited(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );
        bool success = IERC20(tokenCollateralAddress).transfer(
            msg.sender,
            address(this),
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }
    //in order to redeem collateral
    //1. health factor must be over collateral value than the min threshold
    
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral ) public moreThanZero(amountCollateral) nonReentrant{
    s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
    emit CollateralRedeemed(msg.sender,tokenCollateralAddress,amountCollateral);  

    bool success = IERC20(tokenCollateralAddress).transfer(msg.sender,amountCollateral);
    if(!success){
        revert DSCEngine__TransferFailed();
    }  
    _revertIFHealthFactorIsBroken(msg.sender);
    }

    // @notice follows CEI
    // @param amountDscToMint The amount decentralized StableCoin to mint
    // @notice they must have more collateral avlue than the min threshold

    function mintDsc(
        uint256 amountDscToMint
    ) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIFHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn) external {
        
        burnDsc(amountToBurn);
        redeemCollateral(tokenCollateralAddress,amountCollateral);
        
    }

    function burnDsc(uint256 amount) public moreThanZero(amount) {
       s__DSCMinted[msg.sender] -=amount; 

       bool success = i_dsc.transferFrom(msg.sender, address(this),amount);
       if(!success){
        revert DSCEngine__TransferFailed();
       }

       i_dsc.burn(amount);
       _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view {}

    //PRIVATE AND VIEW, INTERNAL FUNCTION

    function _getAccountInformation(
        address user
    )
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsed)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValueInUsd(user);
    }
    // Returns how close to liquidation a user is
    // if a user goes below,1 then they can get liquidated
    function _healthFactor(address user) private view returns (uint256) {
        (
            uint256 totalDscMinted,
            uint256 collateralValueInUsed
        ) = _getAccountInformation(user);
        // return (collateralValueInUsd/totalDscMinted);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = _healthFACOTR(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreakHealthFACTOR(userHealthFactor);
        }
    }

    // Public & External View Functions

    function getAccountCollateralValue(
        address user
    ) public view returns (uint256) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValuedInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValuedInUsd;
    }

    function getUsdValue(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return
            ((uint256(price) = ADDITIONAL_FEED_PREISION) * amount) / PRECISION;
    }
}
