// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ETEEPay} from "../src/ETEEPay.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ETEEPayTest is Test {
    ETEEPay pay;
    MockUSDC usdc;

    address owner = makeAddr("owner");
    address treasury = makeAddr("treasury");
    address provider = makeAddr("provider");
    address payer = makeAddr("payer");

    uint16 constant DEFAULT_FEE_BPS = 500;

    event JobSettled(
        uint256 indexed jobId,
        address indexed provider,
        address indexed payer,
        uint256 providerAmount,
        uint256 treasuryAmount
    );
    event FeeUpdated(uint16 oldBps, uint16 newBps);
    event TreasuryProposed(address indexed newTreasury, uint256 eta);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event TreasuryProposalCancelled(address indexed cancelledTreasury);

    function setUp() public {
        usdc = new MockUSDC();
        pay = new ETEEPay(IERC20(address(usdc)), treasury, DEFAULT_FEE_BPS, owner);

        usdc.mint(payer, 1_000_000e6);
        vm.prank(payer);
        usdc.approve(address(pay), type(uint256).max);
    }

    function test_settleJob_splits95_5() public {
        uint256 amount = 1_000e6;

        vm.expectEmit(true, true, true, true, address(pay));
        emit JobSettled(42, provider, payer, 950e6, 50e6);

        vm.prank(payer);
        pay.settleJob(provider, 42, amount);

        assertEq(usdc.balanceOf(provider), 950e6);
        assertEq(usdc.balanceOf(treasury), 50e6);
        assertTrue(pay.settled(42));
    }

    function test_settleJob_dustGoesToProvider() public {
        vm.prank(payer);
        pay.settleJob(provider, 1, 999);

        assertEq(usdc.balanceOf(treasury), 49);
        assertEq(usdc.balanceOf(provider), 950);
    }

    function test_settleJob_revertsOnDuplicateJobId() public {
        vm.startPrank(payer);
        pay.settleJob(provider, 7, 100e6);

        vm.expectRevert(abi.encodeWithSelector(ETEEPay.AlreadySettled.selector, 7));
        pay.settleJob(provider, 7, 100e6);
        vm.stopPrank();
    }

    function test_settleJob_revertsOnZeroAmount() public {
        vm.prank(payer);
        vm.expectRevert(ETEEPay.ZeroAmount.selector);
        pay.settleJob(provider, 1, 0);
    }

    function test_setFee_updatesAndEmits() public {
        vm.expectEmit(false, false, false, true, address(pay));
        emit FeeUpdated(DEFAULT_FEE_BPS, 1_000);

        vm.prank(owner);
        pay.setFee(1_000);

        assertEq(pay.feeBps(), 1_000);
    }

    function test_setFee_revertsOnNonOwner() public {
        vm.prank(payer);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, payer));
        pay.setFee(1_000);
    }

    function test_treasury_proposeAndApplyAfterDelay() public {
        address newTreasury = makeAddr("newTreasury");
        uint256 eta = block.timestamp + pay.TIMELOCK_DELAY();

        vm.expectEmit(true, false, false, true, address(pay));
        emit TreasuryProposed(newTreasury, eta);

        vm.prank(owner);
        pay.proposeTreasury(newTreasury);

        assertEq(pay.pendingTreasury(), newTreasury);
        assertEq(pay.treasuryEta(), eta);

        vm.warp(eta);

        vm.expectEmit(true, true, false, true, address(pay));
        emit TreasuryUpdated(treasury, newTreasury);

        vm.prank(owner);
        pay.applyTreasury();

        assertEq(pay.treasury(), newTreasury);
        assertEq(pay.pendingTreasury(), address(0));
        assertEq(pay.treasuryEta(), 0);
    }

    function test_applyTreasury_revertsBeforeDelay() public {
        address newTreasury = makeAddr("newTreasury");

        vm.startPrank(owner);
        pay.proposeTreasury(newTreasury);

        uint256 eta = pay.treasuryEta();
        vm.warp(eta - 1);

        vm.expectRevert(abi.encodeWithSelector(ETEEPay.TimelockNotReady.selector, eta, eta - 1));
        pay.applyTreasury();
        vm.stopPrank();
    }

    function test_applyTreasury_revertsWithoutPending() public {
        vm.prank(owner);
        vm.expectRevert(ETEEPay.NoPendingTreasury.selector);
        pay.applyTreasury();
    }

    function test_cancelTreasury_clearsPending() public {
        address newTreasury = makeAddr("newTreasury");

        vm.startPrank(owner);
        pay.proposeTreasury(newTreasury);

        vm.expectEmit(true, false, false, true, address(pay));
        emit TreasuryProposalCancelled(newTreasury);
        pay.cancelTreasury();
        vm.stopPrank();

        assertEq(pay.pendingTreasury(), address(0));
        assertEq(pay.treasuryEta(), 0);
        assertEq(pay.treasury(), treasury);
    }
}
