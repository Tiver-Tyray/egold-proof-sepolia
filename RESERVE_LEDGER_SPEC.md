# E-gold Reserve Ledger Specification

## Scope

The reserve ledger is an append-only off-chain record of physical gold reserve events. It links each physical reserve transition to the `operationId`, `reserveId`, and `proofHash` used in EGold mint and burn authorizations.

The ledger is not stored in the EGold smart contract. It must be published and independently reproducible so that attesters, auditors, and users can verify how an on-chain authorization maps to off-chain reserve activity.

## Entry Types

Each ledger entry must have one of these operation types:

- `MINT`
- `BURN`
- `AUDIT_ADJUSTMENT`
- `BAR_ADDED`
- `BAR_REMOVED`
- `CUSTODY_TRANSFER`

`MINT` and `BURN` entries correspond to on-chain EGold operations. The other entry types record reserve state transitions that do not directly mint or burn tokens.

## Append-Only Model

- Ledger entries are never edited in place.
- Corrections are appended as new entries.
- Every entry includes the previous ledger root.
- Every entry produces a new ledger root.
- `previousLedgerRoot` and `newLedgerRoot` are included in the proof payload.
- Public audit artifacts should identify the exact ledger version and root sequence they reviewed.

## Canonical Ledger Root

Ledger roots are computed from canonical ledger entries:

1. Serialize each entry as UTF-8 JSON.
2. Sort all object keys alphabetically.
3. Use compact JSON separators with no extra whitespace.
4. Store large integers as strings.
5. Hash each canonical entry with `keccak256`.
6. Build the published ledger root from the ordered entry hashes.

The concrete tree or accumulator method must be published before production use and kept stable for a deployed reserve ledger. The proof payload records `previousLedgerRoot` and `newLedgerRoot` so that every mint or burn can be tied to a specific state transition.

## Operation ID Construction

`operationId` must never be reused.

Recommended construction:

```text
operationId = keccak256("EGOLD:V1:" + chainId + ":" + contractAddress + ":" + operationType + ":" + reserveId + ":" + externalOperationRef)
```

Requirements:

- `chainId` is the decimal chain ID string.
- `contractAddress` is the EGold contract address.
- `operationType` is one of the ledger entry types.
- `reserveId` is the bytes32 reserve identifier.
- `externalOperationRef` is a unique custody, audit, redemption, or ledger reference.
- The exact input string used to derive `operationId` must be retained with the public operation record.

## Reserve ID Construction

Recommended construction:

```text
reserveId = keccak256("EGOLD:RESERVE:V1:" + vaultId + ":" + custodianName + ":" + jurisdiction + ":" + barSetId)
```

Requirements:

- `vaultId` identifies the vault or custody location without exposing secret access details.
- `custodianName` is the public custodian name.
- `jurisdiction` is the legal custody jurisdiction.
- `barSetId` identifies the reserve batch or bar set.
- The input material must be stable across proofs for the same reserve set.

## Numeric Rules

- No floating point numbers.
- All masses are integer milligrams.
- All token amounts are integer token units.
- `1 EGOLD = 1 gram`.
- `decimals = 4`.
- `1 token unit = 0.0001 gram = 0.1 milligram`.
- `10000` token units = `1 gram` = `1000` milligrams.

## Ledger Publication Requirements

For every mint or burn, publish:

- proof JSON
- canonical proof JSON
- `proofHash`
- ledger entry
- canonical ledger entry
- `previousLedgerRoot`
- `newLedgerRoot`
- external custody or audit references
- transaction hash after on-chain execution

The ledger process must be externally auditable before production L2 or mainnet deployment.
