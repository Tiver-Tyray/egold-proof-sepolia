# E-gold Deployment Rehearsal

This guide prepares a testnet deployment rehearsal for the immutable EGold contract.

## 1. Pre-Deploy Audit Checks

Run and archive the local gates:

```sh
make audit
```

Before deployment, review:

- Slither findings in `audit-results/slither.txt`
- coverage in `audit-results/coverage-summary.txt`
- gas report in `audit-results/gas-report.txt`
- gas snapshot in `.gas-snapshot`

The known Slither findings are non-blocking for the current design only if their documented assumptions in `AUDIT.md` are still accepted.

Before any public testnet deployment, the local Anvil rehearsal must pass:

- `make post-deploy-check`
- `make smoke-local-dry`
- `make smoke-local`

These commands depend on a running Anvil instance, a deployed local `EGOLD_ADDRESS`, and local-only Anvil keys in `.env`.

## 2. Environment Setup

Create a local environment file:

```sh
cp .env.example .env
```

Fill:

- `RPC_URL`
- `EGOLD_MINTER`
- `EGOLD_ATTESTER_1`
- `EGOLD_ATTESTER_2`
- `EGOLD_ATTESTER_3`
- `EGOLD_THRESHOLD`

Leave `PRIVATE_KEY` empty when using Foundry keystore, `--account`, or a hardware wallet flow. Never commit `.env`, never commit real private keys, use separate testnet keys, and do not use production attester keys on testnet.

## 3. Print Config

```sh
make print-config
```

Check the chain id, deployer, minter, attesters, threshold, and constructor args before dry-running deployment.

## 4. Dry-Run Deployment

```sh
make deploy-dry
```

This executes the deployment script without broadcasting a transaction. It validates constructor config, deploys in simulation, runs post-deploy checks, logs constructor args, logs the runtime codehash, and writes a local manifest if the script reaches the manifest step.

## 5. Testnet Broadcast

With explorer verification:

```sh
make deploy-testnet
```

Without explorer verification:

```sh
make deploy-testnet-no-verify
```

The deployment script supports two broadcast modes:

- If `PRIVATE_KEY` is set and non-zero, it uses `vm.startBroadcast(PRIVATE_KEY)`.
- If `PRIVATE_KEY` is missing, empty, or zero, it uses `vm.startBroadcast()` for Foundry `--account`, keystore, or hardware wallet flows.

## 6. Post-Deploy Check

After broadcast, set:

```sh
EGOLD_ADDRESS=<deployed contract address>
```

Then run:

```sh
make post-deploy-check
```

The check validates metadata, threshold, attester count, minter role, reserve attester roles, runtime codehash, and absence of `DEFAULT_ADMIN_ROLE` for the contract, minter, and attesters.

## 7. Contract Verification

Print constructor args:

```sh
make constructor-args
```

Use the printed hex with explorer verification when needed:

```sh
forge verify-contract \
  --rpc-url "$RPC_URL" \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  --constructor-args <constructor-args-hex> \
  <EGOLD_ADDRESS> \
  src/EGold.sol:EGold
```

If `make deploy-testnet` already ran with `--verify`, keep the constructor args output with the deployment record anyway.

## 8. Local Smoke Test

After local Anvil deployment and a passing post-deploy check, set these local-only keys in `.env`:

- `EGOLD_MINTER_PRIVATE_KEY`
- `EGOLD_ATTESTER_1_PRIVATE_KEY`
- `EGOLD_ATTESTER_2_PRIVATE_KEY`
- `EGOLD_SMOKE_USER_PRIVATE_KEY`

Use only local Anvil or disposable testnet keys. Never use mainnet keys and never place production attester keys in `.env`.
Use a fresh smoke user key or reset Anvil before rerunning the smoke test; the script expects the smoke user to start with zero EGOLD.

Dry-run the end-to-end mint/approve/burn flow:

```sh
make smoke-local-dry
```

Broadcast the local smoke flow to Anvil:

```sh
make smoke-local
```

The smoke script checks deployed metadata, role assignment, absence of `DEFAULT_ADMIN_ROLE`, private-key/address consistency, threshold mint authorization, user approval, threshold burn authorization, replay markers, balance deltas, and total supply deltas.

## 9. Public Testnet Rehearsal

Public testnet rehearsal is mandatory before any production L2 or mainnet deployment.

The Sepolia rehearsal for this checkpoint has passed:

- Contract: `0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9`.
- Chain ID: 11155111.
- Runtime codehash: `0x10ca1be035d896ccfa650e9533d5712c737d082b19b40ee05012bbea55358657`.
- Post-deploy check: passed.
- Smoke test: passed.
- Final `totalSupply`: 6000.
- Final smoke user balance: 6000.

Etherscan/Sepolia source verification has passed:

- Verification output: `Contract successfully verified`.
- Code page: <https://sepolia.etherscan.io/address/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9#code>.
- Constructor args artifact: `audit-results/sepolia-verify-constructor-args.txt`.
- Verification output artifact: `audit-results/sepolia-etherscan-verify.txt`.

When rehearsing on any public testnet, use fresh keys and public artifacts.

Rules:

- Never use Anvil keys on a public testnet.
- Create new testnet deployer, minter, and attester wallets.
- Testnet minter and attesters must be separate addresses.
- The deployer must have testnet ETH.
- The minter must have testnet ETH for mint and burn calls.
- Attesters normally do not need ETH because they sign authorizations off-chain.
- Publish constructor args and runtime codehash after deployment.
- Run `make post-deploy-check`.
- Run the smoke test against testnet with testnet keys only.

Production L2 or mainnet deployment may happen only after:

- verified source code
- public constructor args
- public runtime codehash
- published `proofHash` format
- published reserve custody process
- published attester key custody policy
- confirmed minter/attester key separation

## 10. Deployment Manifest

The deployment script writes:

```text
deployments/<chainid>/EGold.json
```

Publish the following together:

- contract address
- chain id
- minter
- attesters
- threshold
- constructor args
- runtime codehash
- `AUDIT.md`
- `SECURITY_ASSUMPTIONS.md`

If JSON writing is unavailable in a future Foundry runtime, use the console output from `script/DeployEGold.s.sol` to manually store the same fields under `deployments/<chainid>/EGold.json`.

## 11. Mainnet/L2 Deployment Policy

Mainnet or production L2 deployment should happen only after a successful testnet rehearsal and post-deploy check.

Operational requirements:

- Do not reuse production attester keys on testnet.
- Attester keys must follow hardware-backed or offline signing policy.
- The minter key must be separate from all attester keys.
- Publish the `proofHash` format before real minting begins.
- Publish deterministic `operationId` derivation rules.
- Keep all deployment manifests and audit artifacts immutable and publicly available.

The smart-contract flow has been proven through local and Sepolia rehearsals, including deployment, post-deploy checks, source verification, threshold minting, allowance-gated third-party burn, replay markers, supply accounting, and proof-linked JSON-to-authorization hashing. The contract still cannot prove physical gold backing by itself.

The following technical gates are green before mainnet/L2:

- local rehearsal
- Sepolia deploy
- Sepolia post-deploy check
- Sepolia smoke test
- Etherscan verification
- Proof-of-Reserve format tools
- `make proof-check`
- proof-linked smoke test
- public proof bundle pipeline rehearsal
- live and offline public proof index verification

The operational standards now exist in this repository:

1. `PROOF_OF_RESERVE_FORMAT.md`
2. `RESERVE_LEDGER_SPEC.md`
3. `ATTESTER_KEY_POLICY.md`
4. `MINTER_OPERATION_POLICY.md`
5. `INCIDENT_AND_MIGRATION_POLICY.md`

Mainnet/L2 deployment remains blocked until:

- external Solidity audit is complete
- `proofHash` publication pipeline is public
- reserve custody and audit process is externally verified
- attester key ceremony is tested
- production threshold and attester set are determined
- incident and migration policy is formally accepted
- proof publication hosting is chosen
- append-only publication policy is documented
- external auditors can reproduce the `proofHash` format
- public proof website is published and independently verifiable
- the reserve ledger process is externally audited
- attester key custody is operationally tested
- minter policy is signed and published by the operating entity
- incident and migration policy is published with public stakeholder access

Before any production deployment:

- `proofHash` must be publicly reproducible from published reserve data.
- Attester signing policy must be formally documented.
- Custody and audit process must be externally controllable and independently reviewable.
- Reserve-ledger integrity must be specified outside the contract.
- Minter and attester operational responsibilities must remain separated.
- The smart-contract flow is proven, but physical gold backing is not proven by the contract.
