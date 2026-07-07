# E-gold Attester Key Policy

## Scope

Attesters are the fixed off-chain control layer that decide whether a Proof-of-Reserve payload is acceptable for EGold mint or burn authorization. The smart contract enforces threshold signatures from immutable attester addresses; it does not manage key rotation.

## Immutable Key Consequences

- Attesters are immutable in the contract.
- There is no on-chain key rotation in this contract.
- Key compromise cannot be repaired on-chain.
- Lost attester keys cannot be replaced on-chain.
- Attesters must not be the same accounts as minters.
- If the attester set becomes unsafe, the mitigation is public disclosure and optional migration to a newly deployed contract.

## Threshold Policy

The Sepolia rehearsal uses 2-of-3 threshold attestations.

Production should use a stronger independent threshold, such as:

- 3-of-5
- 5-of-8
- 7-of-11

Production threshold selection must account for geography, custodian independence, audit independence, hardware custody, operational availability, and emergency disclosure requirements.

## Key Custody Requirements

- Attester keys must be offline or hardware-backed.
- Attester keys must not be stored in `.env`, `.env.sepolia`, source control, CI logs, chat transcripts, or shared cloud drives.
- Attester signing devices must be access-controlled.
- Attester signing must require human review or formally controlled automation.
- Attester logs must record what was reviewed without exposing private key material.

## Independent Attester Checks

Before signing, every attester must independently verify:

- `operationId` is unique and has not been signed before.
- `proofHash` is reproducible from the published canonical proof payload.
- `amountUnits` matches the reserve delta and the EIP-712 authorization.
- The reserve delta is consistent with the ledger transition.
- Vault and custody audit material is present and internally consistent.
- `auditReportHash` is present and matches the external audit artifact.
- `validAfter` and `validBefore` are reasonable for the operation.
- `operator` is the approved minter/operator for the deployment.
- Minter and attester accounts do not overlap.
- The target contract, chain ID, and runtime codehash match the approved deployment record.

## Refusal Rules

Attesters must never sign:

- blank authorizations
- proofs with missing `auditReportHash`
- proofs where `proofHash` is not reproducible
- proofs where minter and attester accounts overlap
- proofs with missing or reused `operationId`
- proofs with unexplained reserve deltas
- authorizations with unexpected chain ID or contract address
- authorizations with validity windows that are too broad for the operation
- payloads containing private keys, secrets, or signatures inside the proof JSON

## Signing Ceremony

Each signing ceremony should retain:

- proof JSON
- canonical proof JSON
- `proofHash`
- EIP-712 typed authorization
- attester address
- signature timestamp
- operator/minter address
- operation checklist result
- reviewed audit artifacts
- reviewed ledger roots

The retained ceremony log must not include private keys or seed material.

## Log Retention

Attester logs should be retained for the lifetime of the deployment plus the public redemption limitation period defined by the issuer's legal and custody process. Logs must be tamper-evident and independently auditable.
