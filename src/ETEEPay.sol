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

    constructor(IERC20 _token, address _treasury, uint16 _feeBps, address _owner) Ownable(_owner) {
        if (address(_token) == address(0)) revert ZeroProvider();
        if (_treasury == address(0)) revert ZeroTreasury();
        if (_feeBps > BPS_DENOMINATOR) revert InvalidFee();

        token = _token;
        treasury = _treasury;
        feeBps = _feeBps;
    }

    function settleJob(address provider, uint256 jobId, uint256 amount) external {
        if (provider == address(0)) revert ZeroProvider();
        if (amount == 0) revert ZeroAmount();
        if (settled[jobId]) revert AlreadySettled(jobId);

        settled[jobId] = true;

        uint256 treasuryAmount = (amount * feeBps) / BPS_DENOMINATOR;
        uint256 providerAmount = amount - treasuryAmount;

        if (treasuryAmount > 0) {
            token.safeTransferFrom(msg.sender, treasury, treasuryAmount);
        }
        token.safeTransferFrom(msg.sender, provider, providerAmount);

        emit JobSettled(jobId, provider, msg.sender, providerAmount, treasuryAmount);
    }

    function setFee(uint16 newFeeBps) external onlyOwner {
        if (newFeeBps > BPS_DENOMINATOR) revert InvalidFee();
        uint16 oldBps = feeBps;
        feeBps = newFeeBps;
        emit FeeUpdated(oldBps, newFeeBps);
    }

    function proposeTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroTreasury();

        uint256 eta = block.timestamp + TIMELOCK_DELAY;
        pendingTreasury = newTreasury;
        treasuryEta = eta;

        emit TreasuryProposed(newTreasury, eta);
    }

    function applyTreasury() external onlyOwner {
        address newTreasury = pendingTreasury;
        if (newTreasury == address(0)) revert NoPendingTreasury();
        if (block.timestamp < treasuryEta) revert TimelockNotReady(treasuryEta, block.timestamp);

        address oldTreasury = treasury;
        treasury = newTreasury;

        delete pendingTreasury;
        delete treasuryEta;

        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    function cancelTreasury() external onlyOwner {
        address cancelled = pendingTreasury;
        if (cancelled == address(0)) revert NoPendingTreasury();

        delete pendingTreasury;
        delete treasuryEta;

        emit TreasuryProposalCancelled(cancelled);
    }
}
