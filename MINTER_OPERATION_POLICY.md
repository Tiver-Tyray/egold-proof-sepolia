# E-gold Minter Operation Policy

## Scope

The minter submits EGold mint and burn transactions after collecting valid threshold signatures from immutable reserve attesters. The minter does not create reserve truth by itself; it only operates after the proof payload, authorization, and signatures are complete.

## Minter Rules

- The minter may only submit mint or burn transactions with valid threshold signatures.
- The minter must never reuse `operationId`.
- The minter must not alter `proofHash` after attester signatures are collected.
- The minter must not alter `amount`, `reserveId`, `operationId`, account, operator, or validity window after signatures are collected.
- The minter must not burn another holder's balance without ERC-20 allowance.
- The minter must preserve all public artifacts for every operation.
- The minter must stop operations off-chain if reserve integrity, key integrity, or ledger integrity is disputed.

## Required Public Artifacts

For every mint or burn, preserve and publish:

- proof JSON
- canonical proof JSON
- `proofHash`
- EIP-712 authorization
- attester signatures
- transaction hash
- `operationId`
- `reserveId`
- `previousLedgerRoot`
- `newLedgerRoot`
- external audit and custody references

## Mint Flow

1. Receive custody or audit evidence that gold has been added to the reserve.
2. Create or reference the append-only reserve ledger entry.
3. Derive `reserveId`.
4. Derive a unique `operationId`.
5. Prepare Proof-of-Reserve JSON with `operationType = MINT`.
6. Validate the proof payload with `tools/validate_proof.py`.
7. Canonicalize the proof payload with `tools/canonicalize_proof.py`.
8. Compute `proofHash` with `tools/hash_proof.sh`.
9. Prepare the EIP-712 `MintAuthorization`.
10. Confirm `amountUnits` exactly matches `MintAuthorization.amount`.
11. Collect threshold attester signatures.
12. Submit the mint transaction from the minter/operator account.
13. Publish the transaction hash and all public artifacts.

## Burn Flow

1. Receive a redemption or physical withdrawal request.
2. Confirm the holder/from account and requested `amountUnits`.
3. If burning another account's balance, confirm ERC-20 allowance exists before submission.
4. Create or reference the append-only reserve ledger entry.
5. Derive `reserveId`.
6. Derive a unique `operationId`.
7. Prepare Proof-of-Reserve JSON with `operationType = BURN`.
8. Validate the proof payload with `tools/validate_proof.py`.
9. Canonicalize the proof payload with `tools/canonicalize_proof.py`.
10. Compute `proofHash` with `tools/hash_proof.sh`.
11. Prepare the EIP-712 `BurnAuthorization`.
12. Confirm `amountUnits` exactly matches `BurnAuthorization.amount`.
13. Collect threshold attester signatures.
14. Submit the burn transaction from the minter/operator account.
15. Publish the transaction hash and all public artifacts.

## Failure Modes

| Failure | Expected Result |
| --- | --- |
| Duplicate `operationId` | Contract reverts through operation replay protection. |
| Expired authorization | Contract reverts because the validity window is closed. |
| Insufficient signatures | Contract reverts because threshold is not met. |
| Unsorted signatures | Contract reverts because signer order is invalid. |
| Missing allowance | `burnFrom` reverts when burning another holder's balance. |
| Invalid `proofHash` | Honest attesters refuse to sign; if submitted with mismatched signatures, the contract rejects it. |

## Operational Stop Conditions

Minter operations must stop off-chain when:

- any minter key compromise is suspected
- threshold attester compromise is suspected
- reserve ledger corruption is suspected
- custody or audit records are disputed
- proof publication becomes unavailable
- minter and attester separation is violated
