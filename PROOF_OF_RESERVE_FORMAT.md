# E-gold Proof-of-Reserve Format

## 1. Scope

This standard defines the off-chain proof format used to connect physical gold reserve operations to EGold mint and burn authorizations.

The EGold smart contract accepts `proofHash` as a `bytes32` value. The contract does not parse or validate the underlying physical reserve proof. It only verifies that the required threshold of immutable reserve attesters signed the same `proofHash`, `operationId`, `reserveId`, `amount`, `operator`, account, and validity window in the EIP-712 authorization.

The contract cannot prove physical gold custody by itself. The meaning of `proofHash` must therefore be public, deterministic, and reproducible outside the contract.

Attesters sign EIP-712 authorizations that include:

- `proofHash`
- `operationId`
- `reserveId`
- `amount`
- `operator`
- recipient or holder account
- validity window

## 2. Units

- `1 EGOLD = 1 gram` of physical gold.
- `decimals = 4`.
- `1 token unit = 0.0001 gram = 0.1 milligram`.
- `10000` token units = `1.0000 EGOLD` = `1 gram`.
- `amountUnits` must be an integer string.
- Proof payloads must not use floating point numbers.
- All masses must be represented as integer milligrams or integer token units.
- Human-readable gram amounts, such as `amountGrams`, must be strings with exactly four decimal places.

## 3. Canonical Proof Hashing

`proofHash` is computed as:

```text
proofHash = keccak256(canonicalProofJsonBytes)
```

`canonicalProofJsonBytes` is produced from the proof payload by:

- encoding JSON as UTF-8
- sorting object keys alphabetically at every object level
- using compact JSON separators with no extra whitespace
- storing large integers as strings
- excluding any `proofHash` field from the hashed payload itself
- excluding private keys
- excluding signatures

The repository tooling reproduces this process:

- `tools/canonicalize_proof.py` prints canonical JSON to stdout.
- `tools/hash_proof.sh` hashes the canonical JSON with `cast keccak`.
- `tools/validate_proof.py` performs dependency-free structural validation before publication.
- `tools/create_smoke_proofs.py` creates fresh runtime proof payloads for proof-linked smoke testing.
- `tools/export_proof_auth_env.py` exports authorization fields derived from canonical proof hashes.
- `tools/run_proof_linked_smoke.sh` executes a Sepolia smoke test where `proofHash` comes directly from canonical JSON.

The Sepolia proof-linked smoke rehearsal passed with canonical JSON-derived proof hashes:

- Mint `proofHash`: `0xa4a58510a5ce4ff29fceaa4d8105a59740016197b0ef2800174cc63d2729cb94`.
- Burn `proofHash`: `0xe6b0d4cd8409f6c3f281fd28b08d3efe70fc4056f6c3cb3da539dd195fca331b`.
- Rehearsal artifact: `audit-results/proof-linked-smoke.txt`.

## 4. Required Fields

| Field | Type | Requirement |
| --- | --- | --- |
| `schemaVersion` | string | Must be `EGOLD_PROOF_V1`. |
| `network` | string | Network name, for example `sepolia`, `arbitrum`, or `mainnet`. |
| `chainId` | integer | Chain ID where the EGold contract is deployed. |
| `contractAddress` | address string | EGold contract address. |
| `tokenSymbol` | string | Must be `EGOLD`. |
| `tokenDecimals` | integer | Must be `4`. |
| `operationType` | string | Must be `MINT` or `BURN`. |
| `operationId` | bytes32 string | Unique identifier for the physical gold operation. |
| `reserveId` | bytes32 string | Identifier for the vault, custody context, batch, or bar set. |
| `proofGeneratedAt` | string | ISO-8601 timestamp for proof generation. |
| `validAfter` | integer | Earliest Unix timestamp accepted by the signed authorization. |
| `validBefore` | integer | Latest Unix timestamp accepted by the signed authorization. |
| `operator` | address string | Minter/operator address included in the signed authorization. |
| `account` | address string | Mint recipient for `MINT`; holder/from account for `BURN`. |
| `amountUnits` | integer string | Token amount in smallest EGold units. |
| `amountGrams` | string | Human-readable gram amount with four decimal places. |
| `custody` | object | Custody details for the reserve operation. |
| `vaultId` | string | Public vault identifier used in `reserveId` construction. |
| `custodianName` | string | Public custodian name. |
| `jurisdiction` | string | Custody jurisdiction. |
| `bars` | array | Bar or batch records supporting the reserve delta. |
| `totalFineGoldMilligrams` | integer string | Total fine gold mass represented by the proof. |
| `audit` | object | Audit metadata and report references. |
| `auditReportHash` | bytes32 string | Hash of the external audit report or audit package. |
| `reserveLedger` | object | Ledger metadata for the reserve transition. |
| `previousLedgerRoot` | bytes32 string | Ledger root before the operation. |
| `newLedgerRoot` | bytes32 string | Ledger root after the operation. |
| `externalReferences` | array | Public references such as custody receipts, audit URLs, or IPFS CIDs. |

## 5. Mint Proof

For minting:

- `operationType = MINT`.
- `account` is the recipient.
- `amountUnits` must exactly match `MintAuthorization.amount`.
- `operationId` must exactly match `MintAuthorization.operationId`.
- `reserveId` must exactly match `MintAuthorization.reserveId`.
- `proofHash` must exactly match `MintAuthorization.proofHash`.
- `operator` must exactly match `MintAuthorization.operator`.

The mint proof should demonstrate that physical gold was added to the relevant reserve ledger before the on-chain mint is submitted. Attesters must independently reproduce `proofHash` before signing.

For proof-linked smoke testing, `tools/create_smoke_proofs.py` generates a fresh `MINT` proof, `tools/export_proof_auth_env.py` computes its canonical `proofHash`, and `script/ProofLinkedSmokeTestEGold.s.sol` uses that exact hash in `MintAuthorization`.

## 6. Burn Proof

For redemption burning:

- `operationType = BURN`.
- `account` is the holder/from account.
- `amountUnits` must exactly match `BurnAuthorization.amount`.
- `operationId` must exactly match `BurnAuthorization.operationId`.
- `reserveId` must exactly match `BurnAuthorization.reserveId`.
- `proofHash` must exactly match `BurnAuthorization.proofHash`.
- `operator` must exactly match `BurnAuthorization.operator`.

The burn proof should demonstrate the reserve-ledger transition associated with redemption or physical withdrawal. If the minter burns another holder's balance, the holder must have granted ERC-20 allowance before the burn transaction.

For proof-linked smoke testing, the generated `BURN` proof uses the same `reserveId` as the mint proof but a distinct `operationId`. The canonical burn `proofHash` is exported into `BurnAuthorization`, then checked on-chain through the normal EGold signature and replay rules.

## 7. Non-Goals

This standard does not define:

- proof of physical custody by Solidity itself
- admin emergency controls
- freeze, pause, or blacklist controls
- legal claim terms
- pricing or valuation oracles
- a replacement for independent reserve audits
