# E-gold Proof-Linked Smoke Rehearsal

## 1. Summary

This rehearsal proves that canonical Proof-of-Reserve JSON payloads provide the `proofHash` values used in on-chain EGold mint and burn authorizations.

Network:

- Network: Sepolia.
- Chain ID: 11155111.
- EGold contract: `0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9`.
- Etherscan verified: yes.

Status:

- `PROOF_LINKED_SMOKE_STATUS: PASSED`.
- `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`.

## 2. What Was Proven

1. Fresh proof JSON files are generated for the smoke run.
2. Proof JSON is validated before use.
3. Canonical JSON is hashed into `proofHash`.
4. `proofHash` is exported into authorization environment variables.
5. `MintAuthorization` uses exactly the mint `proofHash`.
6. `BurnAuthorization` uses exactly the burn `proofHash`.
7. Attester 1 and attester 2 sign the EIP-712 digests.
8. Signatures are sorted in ascending signer address order.
9. Mint succeeds on-chain.
10. The smoke user grants allowance.
11. `burnFrom` succeeds on-chain.
12. `authorizationUsed` is set.
13. `operationUsed` is set.
14. `totalSupply` ends correctly.

## 3. Results

Transactions:

- Mint tx: `0xc3b771ae3fbc18ff123624ac25fc256714c0c574c8200fcfc06bafccfb35746b`.
- Approve tx: `0x86ccc54fe79074c6689c0f2701b1a85a06a2b2d3729d09f49a7c9175476b841f`.
- BurnFrom tx: `0x2dd0ce5f9f4e8d54682542f52ff272973b1ddeb8c6b4d51ea3205a1a5ebe6604`.

Proof hashes:

- Mint `proofHash`: `0xa4a58510a5ce4ff29fceaa4d8105a59740016197b0ef2800174cc63d2729cb94`.
- Burn `proofHash`: `0xe6b0d4cd8409f6c3f281fd28b08d3efe70fc4056f6c3cb3da539dd195fca331b`.

Operation IDs:

- Mint `operationId`: `0xe9396bc6a2411b20d9bfa07caa89fa61373408d02c8cb829cf570589cf865958`.
- Burn `operationId`: `0x6b5f69ab483efc91f02afcdbabda48caef32ce8f863208d4ff418c9e91af53ea`.

Reserve ID:

- `reserveId`: `0x01485f2921b1d7477e8d478dd77a634af64c9bedef51b19ac3fd3259e0c53cb7`.

Balances and supply:

- Start balance smoke user: 12000.
- Final balance smoke user: 18000.
- Start `totalSupply`: 12000.
- Final `totalSupply`: 18000.
- Net supply increase: 6000.

Gas paid:

- Mint paid: 0.00011591489910495 ETH.
- Approve paid: 0.000049566634113583 ETH.
- BurnFrom paid: 0.000113085545085517 ETH.
- Total paid: 0.00027856707830405 ETH.

Artifacts:

- `audit-results/proof-linked-smoke.txt`.
- `broadcast/ProofLinkedSmokeTestEGold.s.sol/11155111/run-latest.json`.
- `cache/ProofLinkedSmokeTestEGold.s.sol/11155111/run-latest.json` contains sensitive values and must never be committed.

Publication path:

- The public proof publication pipeline uses this rehearsal's generated proof JSON and on-chain transactions to build append-only bundles under `proofs/sepolia/11155111/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9/<operationId>/`.
- Only validated public proof bundles should be committed from `proofs/`.
- Temporary `generated/` and `cache/` artifacts remain uncommitted.
- Mint public bundle: `proofs/sepolia/11155111/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9/0xe9396bc6a2411b20d9bfa07caa89fa61373408d02c8cb829cf570589cf865958`.
- Burn public bundle: `proofs/sepolia/11155111/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9/0x6b5f69ab483efc91f02afcdbabda48caef32ce8f863208d4ff418c9e91af53ea`.

## 4. Caveats

- This is Sepolia, not mainnet.
- Sepolia ETH has no real value.
- This proves the cryptographic and operational smart-contract flow.
- This does not prove that physical gold is actually in custody.
- Physical gold backing requires external custody, audits, public proof publication, reserve-ledger integrity, and attester integrity.

## 5. Security Notes

- `cache/` can contain sensitive values.
- `generated/` contains fresh proof artifacts and should not be committed by default.
- `.env.sepolia` must never be committed.
- Production keys must never be used on testnet.
- No private keys or API keys are included in this rehearsal document.
