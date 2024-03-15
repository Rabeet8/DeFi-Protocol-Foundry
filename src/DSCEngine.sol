//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
 * @title DECEngine
 * @author Syed Rabeet
 *
 *
 * This is system is designed to be as minimal as possible and have the tokens maintain a 1 token ==  1peg.
 *
 * This stable coin has the properties:
 * Exogenous Collateral
 * Dolalr Peged
 * Algorithmically Stable
 *
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

    //State Variable
    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    DecentralizedStableCoin private i_dsc;

    //Events
    event CollateralDeposited(address indexed user,address indexed token,uint256 indexed amount);


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

    function depositCollateralAndMintDsc() external {}

    /*
    @notice follows CEI
    @param tokenCollateralAddress the address of the token to deposit as collateral
    @param amountCollateral The amount of collateral to deposit
    */

    //Functions
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddress, address dscAddress) {
        //USD Price Feeds
        if (tokenAddress.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        //For eg: ETH/ USD,BTC/USD/ MKR/USD,etc
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeesAddresses[i];
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    //External Function

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, address(this),amountCollateral);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateral() external {}

    function mintDsc() external {}

    function redeemCollateralForDsc() external {}

    function burnDsc() external {}

    function getHealthFactor() external view {}
}
