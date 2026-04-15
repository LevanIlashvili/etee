import "dotenv/config";
import {
  createPublicClient,
  createWalletClient,
  http,
  parseUnits,
  formatUnits,
  type Address,
  type Hex,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { baseSepolia } from "viem/chains";

const MOCK_USDC_ABI = [
  {
    type: "function",
    name: "mint",
    stateMutability: "nonpayable",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
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
const DEFAULT_AMOUNT = "1000";

async function main() {
  const privateKey = requireEnv("PRIVATE_KEY") as Hex;
  const rpcUrl = requireEnv("BASE_SEPOLIA_RPC_URL");
  const usdcAddress = requireEnv("MOCK_USDC_ADDRESS") as Address;

  const account = privateKeyToAccount(privateKey);
  const to = (parseFlag("to") ?? account.address) as Address;
  const amount = parseUnits(parseFlag("amount") ?? DEFAULT_AMOUNT, MOCK_DECIMALS);

  const transport = http(rpcUrl);
  const publicClient = createPublicClient({ chain: baseSepolia, transport });
  const walletClient = createWalletClient({ account, chain: baseSepolia, transport });

  console.log(`USDC:   ${usdcAddress}`);
  console.log(`To:     ${to}`);
  console.log(`Amount: ${formatUnits(amount, MOCK_DECIMALS)} mUSDC`);
  console.log();

  const hash = await walletClient.writeContract({
    address: usdcAddress,
    abi: MOCK_USDC_ABI,
    functionName: "mint",
    args: [to, amount],
  });

  const receipt = await publicClient.waitForTransactionReceipt({ hash });

  const balance = await publicClient.readContract({
    address: usdcAddress,
    abi: MOCK_USDC_ABI,
    functionName: "balanceOf",
    args: [to],
  });

  console.log(`Minted in block ${receipt.blockNumber}, status: ${receipt.status}`);
  console.log(`New balance: ${formatUnits(balance, MOCK_DECIMALS)} mUSDC`);
  console.log(`Tx hash:  ${hash}`);
  console.log(`Explorer: https://sepolia.basescan.org/tx/${hash}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
