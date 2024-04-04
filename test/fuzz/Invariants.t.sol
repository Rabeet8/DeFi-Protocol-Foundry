//SPSX-License-identifier: MIT

// Have our invariant aka properties

// What are our invariants

//1 THe total supply of DSC should be less than the total value of collateral
//2 Getter view function should never revert <- evergreen invariant

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InvariantTest is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    IERC20 weth;
    IERC20 wbtc;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (, , weth, btc) = helperConfig.activeNetworkConfig();
        targetContract(address(dsce));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        //get the value of all the collateral in the protocol
        //compare it all the debt (dsc)

        uint256 totalSupply = dsc.totalSupply();
        uint256 totalwethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(dsce));
        uint256 wethValue = dsce.getUsdValue(wbtc, totalwethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalDeposited);

        assert(wethValue + wbtcValue >= totalSupply);
    }
}
