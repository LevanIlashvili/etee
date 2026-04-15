// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ETEEPay is Ownable {
    using SafeERC20 for IERC20;

    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant TIMELOCK_DELAY = 2 days;

    IERC20 public immutable token;

    address public treasury;
    uint16 public feeBps;

    address public pendingTreasury;
    uint256 public treasuryEta;

    mapping(uint256 => bool) public settled;

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

    error AlreadySettled(uint256 jobId);
    error ZeroAmount();
    error ZeroProvider();
    error ZeroTreasury();
    error InvalidFee();
    error NoPendingTreasury();
    error TimelockNotReady(uint256 eta, uint256 nowTs);

    constructor(IERC20 _token, address _treasury, uint16 _feeBps, address _owner) Ownable(_owner) {}

    function settleJob(address provider, uint256 jobId, uint256 amount) external {}

    function setFee(uint16 newFeeBps) external onlyOwner {}

    function proposeTreasury(address newTreasury) external onlyOwner {}

    function applyTreasury() external onlyOwner {}

    function cancelTreasury() external onlyOwner {}
}
