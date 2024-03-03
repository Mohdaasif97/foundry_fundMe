// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test,console} from "forge-std/test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE=0.1 ether;
    uint256 constant STARTING_BALANCE=10 ether;
    uint256 constant GAS_PRICE=1;
    

    function setUp() external {
        DeployFundMe deployFundMe=new DeployFundMe();
        fundMe=deployFundMe.run();
        //fundMe=new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        vm.deal(USER,STARTING_BALANCE);
    }

    function testMinimumUSDIsFive() public {
        assertEq(fundMe.MINIMUM_USD(),5e18);
    }

    function testOwnerIsMsgSender() public{
        assertEq(fundMe.getOwner(),msg.sender);
    }

    function testPriceFeedVersion() public {
        assertEq(fundMe.getVersion(),4);
    }
    
    function testFundFailWithoutEnoughETH() public {
        vm.expectRevert();
        fundMe.fund();
    }
    function testFundUpdatesFundedData() public { 

        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded,SEND_VALUE);
    }

    function testAddsfunderToArrayofFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunder(0);
        assertEq(funder,USER);
    }   

    modifier funded()
    {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE};
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded{
        
        vm.expectRevert();
        vm.prank(USER);
        fundMe.cheaperWithdraw();
    }

    function testWithdrawWithASingleFunder() public funded{
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        uint256 gasEnd = gasleft();

        uint256 gasUsed = (gasStart-gasEnd)*tx.gasprice;

        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        console.log(gasUsed);


        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance,0);
        assertEq(startingFundMeBalance+startingOwnerBalance,endingOwnerBalance);
    } 

    function testWithdrawFromMultipleFunderCheaper() public funded{
        uint160 numberOfFunders=10;
        uint160 startingFunderIndex  = 1;
        for(uint160 i = startingFunderIndex;i<numberOfFunders;i++)
        {
            deal(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        assert(address(fundMe).balance==0);
        assert(startingFundMeBalance+startingOwnerBalance==fundMe.getOwner().balance);
    }
}