# UniV4 Migration Integration Test

Self-contained example demonstrating Uniswap v4 position migration to Arrakis vaults on Base.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Base RPC URL (e.g., from Alchemy or Infura)

## Setup

```bash
# Clone the repository
git clone https://github.com/ArrakisFinance/univ4-migration-example
cd univ4-migration-example

# Install dependencies
forge soldeer install --recursive-deps

# Copy environment file
cp .env.example .env
# Edit .env with your BASE_RPC_URL
```

## Run Tests

```bash
forge test -vvv
```

## What This Demonstrates

1. Minting a Uniswap v4 position with WETH/USDC on Base
2. Migrating the position to an Arrakis vault using the UniV4 Migration Helper
3. Basic verification that the vault was created

## Test Flow

1. Fork Base mainnet
2. Create a test user and fund with WETH/USDC
3. Set up Permit2 approvals for the Position Manager
4. Mint a Uniswap v4 liquidity position
5. Approve the position NFT to the UniV4 Migration Helper
6. Call `migratePositions()` to migrate into an Arrakis vault
7. Verify the vault address is returned

## Contract Addresses (Base)

| Contract | Address |
|----------|---------|
| UniV4 Migration Helper | `0x30D0f4C5A1985667f5C9F848F1D496a537935750` |
| Position Manager | `0x7C5f5A4bBd8fD63184577525326123B519429bDc` |
| Pool Manager | `0x498581fF718922c3f8e6A244956aF099B2652b2b` |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |
| UniV4 Private Beacon | `0x97d42db1B71B1c9a811a73ce3505Ac00f9f6e5fB` |
| WETH | `0x4200000000000000000000000000000000000006` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |

## Vault Creation Parameters

The test uses the following vault creation parameters on Base.
Eventually these can be abstracted away via defaults.

- `maxDeviation`: 20000 (PIPS; 2%)
- `cooldownPeriod`: 60 (seconds)
- `maxSlippage`: 50000 (PIPS; 5%)
- `upgradeableBeacon`: `0x97d42db1B71B1c9a811a73ce3505Ac00f9f6e5fB`
- `executor`: `0x420966bCf2A0351F26048cD07076627Cde4f79ac`

## License

MIT
