# ETEEPay

Minimal fee-switch settlement module on Base Sepolia. `settleJob` pulls an ERC-20 payment from the caller and splits it between a provider (95% default) and the protocol treasury (5% default).

## Features

- **Fee-switch settlement** — `settleJob(provider, jobId, amount)` pulls `amount` from the caller via `transferFrom`, splits by `feeBps`, and forwards both legs in a single tx.
- **Basis-point fee** — `feeBps` stored on-chain, adjustable via `setFee` (owner-only, no timelock, uncapped).
- **Dust handling** — rounding truncates the treasury cut; the remainder goes to the provider.
- **Idempotent job IDs** — `settled[jobId]` mapping; re-settling the same ID reverts with `AlreadySettled`.
- **Timelocked treasury rotation** — 2-day delay on treasury changes. `proposeTreasury` → wait `TIMELOCK_DELAY` → `applyTreasury`. `cancelTreasury` aborts a pending proposal.
- **Custom errors** — `AlreadySettled`, `ZeroAmount`, `ZeroProvider`, `ZeroTreasury`, `InvalidFee`, `NoPendingTreasury`, `TimelockNotReady`.
- **Events** — `JobSettled`, `FeeUpdated`, `TreasuryProposed`, `TreasuryUpdated`, `TreasuryProposalCancelled`.
- **SafeERC20** — all token moves use OZ `SafeERC20` for non-standard ERC-20 compatibility.

## Deployed (Base Sepolia)

- **ETEEPay**: [`0x28D85F748f0A0673F5629C49c07273a6A8C572dD`](https://sepolia.basescan.org/address/0x28D85F748f0A0673F5629C49c07273a6A8C572dD#code)
- **MockUSDC**: [`0xd3A0234818F37403bf1Bd5d96e191e171bcA1d2a`](https://sepolia.basescan.org/address/0xd3A0234818F37403bf1Bd5d96e191e171bcA1d2a#code)
- Treasury: `0xF956D4e56b4A42DB7984F46B2497E44129026F59`
- Fee: 500 bps (5%)

## Run the script

1. **Install**

   ```bash
   npm install
   forge install
   ```

2. **Configure `.env`** (copy from `.env.example`)

   ```
   PRIVATE_KEY=0x...
   BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
   ETEE_PAY_ADDRESS=0x28D85F748f0A0673F5629C49c07273a6A8C572dD
   MOCK_USDC_ADDRESS=0xd3A0234818F37403bf1Bd5d96e191e171bcA1d2a
   PROVIDER_ADDRESS=0x...
   ```

3. **Settle a job**

   ```bash
   npm run settle                                      # default 0.001 mUSDC, provider from .env
   npm run settle -- --amount 0.5                      # custom amount
   npm run settle -- --provider 0x... --amount 0.5     # custom both
   ```

   Script handles the `approve` flow automatically (infinite approval, one-time), generates a unique `jobId` from `Date.now()`, and prints the tx hash + Basescan link.

## Project structure

```
.
├── src/
│   ├── ETEEPay.sol          # settlement contract (fee split + treasury timelock)
│   └── MockUSDC.sol         # ERC-20 mock, 6 decimals, public mint
├── test/
│   └── ETEEPay.t.sol        # foundry tests (settle, setFee, timelock)
├── script/
│   └── Deploy.s.sol         # forge deploy script
├── client/
│   └── settle.ts            # viem settle executor
├── foundry.toml
├── package.json
└── .env.example
```

## Contract API

### `settleJob(address provider, uint256 jobId, uint256 amount)`
Pulls `amount` from `msg.sender`, sends `amount * feeBps / 10_000` to the treasury and the remainder to `provider`. Marks `jobId` settled. Reverts on duplicate, zero amount, or zero provider.

### `setFee(uint16 newFeeBps)` — owner
Updates `feeBps` (0–10_000). Emits `FeeUpdated`.

### `proposeTreasury(address newTreasury)` — owner
Queues a new treasury with a 2-day ETA.

### `applyTreasury()` — owner
Commits the pending treasury once `block.timestamp >= treasuryEta`.

### `cancelTreasury()` — owner
Clears a pending treasury proposal.

## Tests

```bash
forge test -vv
```

10 tests cover the settle math, dust, duplicate-jobId guard, fee update access control, and the full timelock lifecycle (propose/apply/cancel + not-ready / no-pending reverts).

## Deploy your own

```bash
forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast
```

Reads `PRIVATE_KEY`, optional `TREASURY_ADDRESS` (defaults to deployer), optional `FEE_BPS` (defaults to 500). Mints 1M mUSDC to the deployer.

To verify on Basescan:

```bash
forge verify-contract <MOCK_USDC_ADDRESS> src/MockUSDC.sol:MockUSDC --chain base-sepolia --watch
forge verify-contract <ETEE_PAY_ADDRESS> src/ETEEPay.sol:ETEEPay --chain base-sepolia \
  --constructor-args $(cast abi-encode "constructor(address,address,uint16,address)" <USDC> <TREASURY> 500 <OWNER>) \
  --watch
```
