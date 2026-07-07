# E-gold Security Assumptions

## Unit Model

- `1 EGOLD = 1 gram` of physical gold.
- `decimals = 4`.
- The smallest on-chain unit is `0.0001 gram`.
- `0.0001 gram = 0.1 milligram`.

## Authorization Model

- Threshold signatures are required for mint operations.
- Threshold signatures are required for burn/redemption operations.
- Attesters are immutable after deployment.
- Minters are immutable after deployment.
- `DEFAULT_ADMIN_ROLE` is never granted.
- There is no admin key.
- There is no owner key.
- There is no emergency pause.
- There is no blacklist.
- There is no freeze.
- There is no forced transfer.
- There is no proxy or upgradeability mechanism.

## Key Management Consequences

- Lost minter keys cannot be replaced on-chain.
- Lost attester keys cannot be replaced on-chain.
- Compromised keys cannot be removed on-chain.
- Key compromise cannot be repaired inside this contract.
- If the fixed trust set becomes unsafe, the mitigation is operational migration to a newly deployed contract with a new minter and attester set.

## Operational Mitigations

Recommended mitigations include:

- threshold signing with independent attesters
- hardware-backed custody for signing keys
- offline signing policies
- strict separation between minter operators and reserve attesters
- public proof publication for every `proofHash`
- deterministic `operationId` derivation rules
- external monitoring for unexpected mint and burn operations
- migration playbooks for catastrophic key loss or compromise

## Off-Chain Reserve Boundary

The smart contract verifies signatures and replay rules. It does not verify physical gold custody directly. Reserve correctness depends on vault controls, audit quality, attester independence, redemption procedures, and public availability of reserve proof material.

## Local Rehearsal Boundary

The local Anvil rehearsal proves deployment mechanics and smart-contract transaction flow only. Anvil private keys are publicly known test keys and must never be reused on public testnets, mainnet, production L2s, or real reserve-attester infrastructure.

Successful local mint and burn smoke tests do not prove physical gold backing. Physical reserve integrity still depends on custody, reserve audits, `proofHash` publication, deterministic operation records, and independent attester integrity.

## Public Testnet Verification Boundary

Sepolia deployment, smoke testing, and Etherscan source verification prove that the testnet smart-contract flow can be deployed, checked, verified, and executed with the published constructor parameters. They do not prove physical gold backing, reserve ownership, custody quality, redemption enforceability, or production attester integrity.

Mainnet or production L2 readiness still requires public operational specifications for `proofHash` construction, reserve-ledger reconciliation, custody audits, attester signing rules, minter operation rules, and incident or migration handling.

Never place production attester private keys, minter private keys, API keys, or other secrets in committed files. `.env.sepolia`, `.secrets/`, and `cache/` must remain uncommitted because they can contain sensitive values.

## Proof-of-Reserve Trust Boundary

`proofHash` proves only that threshold attesters signed the same canonical proof payload hash. It does not prove that gold physically exists, that a custodian is solvent, that legal title is clean, or that redemption will complete.

Physical custody remains off-chain. The contract cannot know whether gold bars exist, whether vault records are accurate, whether assay reports are truthful, or whether a custodian will honor redemption.

The trust boundary is:

- custody controls
- independent attesters
- external audits
- public proof publication
- reserve-ledger integrity
- minter/attester key separation

The Proof-of-Reserve documents and tooling make this boundary reproducible and reviewable, but they do not remove the need for independent operational assurance.
