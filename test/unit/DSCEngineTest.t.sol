//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deloyer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public user = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, , ) = config
            .activeNetworkConfig();

        ERC20Mock(weth).mint(USER);
    }

    // Constructor Tests

    address[] public tokenAdresses;
    address[] public priceFeedAddresses;
    function testRevertsIfTokenLengthDoesnotMatchPriceFeeds() public {
        tokenAddress.push(weth);
        feedAddresses.push(ethUsdPriceFeed);
        feedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(
            DSCEngine
                .DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLengt
                .selector
        );

        newDSCEngine(tokenAdresses, priceFeedAddresses, address(dsc));
    }

    //Price Tests

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;

        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actual);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsc.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    //deposit collateral tests

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCENGINE.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);

        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN","RAN",USER,AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken),AMOUNT_COLLATERAL);
    }

        modifier depositedCollateral(){
            vm.startPrank(USER);
            ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
            dsce.depositCollateral(weth,AMOUNT_COLLATERAL);
            vm.stopPrank();
            _;
        }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral{
        (uint256 totalDscMinted,uint256 collateralVlaueInUsd) = dsce.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;


        uint256 expectedDepositedAmount = dsce.getTokenAmountFromUsd(weth,collateralValueInUsd);
        assertEq(totalDscMinted,expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL,expectedDepositedAmount);
    }
}
