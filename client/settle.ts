import "dotenv/config";
import {
  createPublicClient,
  createWalletClient,
  http,
  parseUnits,
  formatUnits,
  maxUint256,
  type Address,
  type Hex,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { baseSepolia } from "viem/chains";

const ERC20_ABI = [
  {
    type: "function",
    name: "allowance",
    stateMutability: "view",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "approve",
    stateMutability: "nonpayable",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ type: "bool" }],
  },
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
] as const;

const ETEE_PAY_ABI = [
  {
    type: "function",
    name: "settleJob",
    stateMutability: "nonpayable",
    inputs: [
      { name: "provider", type: "address" },
      { name: "jobId", type: "uint256" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [],
  },
  {
    type: "event",
    name: "JobSettled",
    inputs: [
      { name: "jobId", type: "uint256", indexed: true },
      { name: "provider", type: "address", indexed: true },
      { name: "payer", type: "address", indexed: true },
      { name: "providerAmount", type: "uint256", indexed: false },
      { name: "treasuryAmount", type: "uint256", indexed: false },
    ],
  },
] as const;

function requireEnv(key: string): string {
  const v = process.env[key];
  if (!v) throw new Error(`Missing env var: ${key}`);
  return v;
}

function parseFlag(name: string): string | undefined {
  const idx = process.argv.indexOf(`--${name}`);
  return idx >= 0 ? process.argv[idx + 1] : undefined;
}

const MOCK_DECIMALS = 6;
const DEFAULT_amount = "0.001";
const JOB_ID = BigInt(Date.now());

async function main() {
  const privateKey = requireEnv("PRIVATE_KEY") as Hex;
  const rpcUrl = requireEnv("BASE_SEPOLIA_RPC_URL");
  const payAddress = requireEnv("ETEE_PAY_ADDRESS") as Address;
  const usdcAddress = requireEnv("MOCK_USDC_ADDRESS") as Address;

  const provider = (parseFlag("provider") ?? requireEnv("PROVIDER_ADDRESS")) as Address;
  const amount = parseUnits(parseFlag("amount") ?? DEFAULT_amount, MOCK_DECIMALS);

  const account = privateKeyToAccount(privateKey);
  const transport = http(rpcUrl);
  const publicClient = createPublicClient({ chain: baseSepolia, transport });
  const walletClient = createWalletClient({ account, chain: baseSepolia, transport });

  console.log(`Payer:    ${account.address}`);
  console.log(`ETEEPay:  ${payAddress}`);
  console.log(`USDC:     ${usdcAddress}`);
  console.log(`Provider: ${provider}`);
  console.log(`Amount:   ${formatUnits(amount, MOCK_DECIMALS)} mUSDC`);
  console.log(`Job ID:   ${JOB_ID}`);
  console.log();

  const balance = await publicClient.readContract({
    address: usdcAddress,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: [account.address],
  });
  if (balance < amount) {
    throw new Error(
      `Insufficient mUSDC balance. Have ${formatUnits(balance, MOCK_DECIMALS)}, need ${formatUnits(amount, MOCK_DECIMALS)}.`,
    );
  }

  const allowance = await publicClient.readContract({
    address: usdcAddress,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: [account.address, payAddress],
  });

  if (allowance < amount) {
    console.log("Approving ETEEPay to spend mUSDC (unlimited)...");
    const approveHash = await walletClient.writeContract({
      address: usdcAddress,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [payAddress, maxUint256],
    });
    await publicClient.waitForTransactionReceipt({ hash: approveHash });
    console.log(`  approve tx: https://sepolia.basescan.org/tx/${approveHash}`);
  } else {
    console.log("Allowance already sufficient, skipping approve.");
  }

  console.log("Settling job...");
  const settleHash = await walletClient.writeContract({
    address: payAddress,
    abi: ETEE_PAY_ABI,
    functionName: "settleJob",
    args: [provider, JOB_ID, amount],
  });

  const receipt = await publicClient.waitForTransactionReceipt({ hash: settleHash });

  console.log();
  console.log(`Settled in block ${receipt.blockNumber}, status: ${receipt.status}`);
  console.log(`Tx hash:  ${settleHash}`);
  console.log(`Explorer: https://sepolia.basescan.org/tx/${settleHash}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
