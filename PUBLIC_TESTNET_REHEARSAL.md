# E-gold Public Testnet Rehearsal

## Rehearsal Summary

- Recorded date: 2026-07-07.
- Network: Sepolia.
- Chain ID: 11155111.
- Contract address: `0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9`.
- Runtime codehash: `0x10ca1be035d896ccfa650e9533d5712c737d082b19b40ee05012bbea55358657`.
- Sepolia source verification: PASSED.
- Etherscan code page: <https://sepolia.etherscan.io/address/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9#code>.

Constructor args hex:

```text
0x000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001000000000000000000000000ab202fdd7d6aa4c2c8ee96b184327e8af635bd590000000000000000000000000000000000000000000000000000000000000003000000000000000000000000d06f1701ca14dd3654bdc911f2f9749a934a6b510000000000000000000000002b1e491122d517dfc4fb041ef92056c1ba7ba3a900000000000000000000000044ab914dfe18205e423902a0b6bdc1683a834694
```

Roles:

- DEPLOYER: `0x127FD53e2d39B771c42a8c8a9C96d7d8Fb21ada9`.
- MINTER: `0xAB202fDd7D6Aa4C2c8ee96b184327e8aF635bD59`.
- ATTESTER_1: `0xd06F1701Ca14dD3654bDC911F2F9749A934a6B51`.
- ATTESTER_2: `0x2b1E491122d517dFc4fB041ef92056C1bA7Ba3A9`.
- ATTESTER_3: `0x44ab914Dfe18205E423902A0b6Bdc1683a834694`.
- SMOKE_USER: `0x2F7548424c958d759976f45AB1b67fa3353Fa42B`.
- THRESHOLD: 2.

Post-deploy check:

- `POST_DEPLOY_STATUS: PASSED`.
- `name == E-gold`: true.
- `symbol == EGOLD`: true.
- `decimals == 4`: true.
- `threshold matches`: true.
- `attester count == 3`: true.
- `minter has MINTER_ROLE`: true.
- `attester 1 has RESERVE_ATTESTER_ROLE`: true.
- `attester 2 has RESERVE_ATTESTER_ROLE`: true.
- `attester 3 has RESERVE_ATTESTER_ROLE`: true.
- `EGOLD_ADDRESS has no DEFAULT_ADMIN_ROLE`: true.
- `minter has no DEFAULT_ADMIN_ROLE`: true.
- `attesters have no DEFAULT_ADMIN_ROLE`: true.

Smoke test:

- `LOCAL_SMOKE_STATUS: PASSED`.
- `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`.
- Mint amount: 10000.
- Burn amount: 4000.
- Final balance: 6000.
- Final `totalSupply`: 6000.

Transactions:

- Mint tx: `0x1311e85ee19129ebd4670e6c20dfb84a985f6afd677dbb6671b12da2b58dde2a`.
- Approve tx: `0x89ad70f8b8c1ffdcd7b53bb550015baf2e76dc401b4aae2fef52d412cb250b07`.
- BurnFrom tx: `0x1b60df8b0ce254da2b7e89471f9621de47b912538761cc98fc85f5321fb1459b`.

Gas paid:

- Mint paid: 0.0001493473896607 ETH.
- Approve paid: 0.00004651549302384 ETH.
- BurnFrom paid: 0.000120083007661601 ETH.
- Total paid: 0.000315945890346141 ETH.

Artifacts:

- `audit-results/sepolia-post-deploy-check.txt`.
- `audit-results/sepolia-smoke.txt`.
- `audit-results/sepolia-etherscan-verify.txt`.
- `audit-results/sepolia-verify-constructor-args.txt`.
- `broadcast/SmokeTestEGoldLocal.s.sol/11155111/run-latest.json`.

## Source Verification

- Etherscan/Sepolia source verification: PASSED.
- Verification output: `Contract successfully verified`.
- Verification artifact: `audit-results/sepolia-etherscan-verify.txt`.
- Constructor args artifact: `audit-results/sepolia-verify-constructor-args.txt`.
- Etherscan code page: <https://sepolia.etherscan.io/address/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9#code>.
- Verified contract address: `0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9`.
- Verified runtime codehash: `0x10ca1be035d896ccfa650e9533d5712c737d082b19b40ee05012bbea55358657`.

## Proven On Sepolia

1. EGold is publicly deployable on Sepolia.
2. Constructor args work.
3. Metadata is correct.
4. `decimals == 4`.
5. `attestationThreshold == 2`.
6. `attesterCount == 3`.
7. The minter role is assigned correctly.
8. Reserve attester roles are assigned correctly.
9. `DEFAULT_ADMIN_ROLE` remains empty.
10. Mint works with 2-of-3 threshold attestations.
11. Burn works with 2-of-3 threshold attestations.
12. Burning another account's balance requires allowance.
13. `authorizationUsed` is set.
14. `operationUsed` is set.
15. `totalSupply` changes correctly.
16. Smoke user ends with 6000 units.
17. `totalSupply` ends with 6000 units.

## Warnings

- This is Sepolia testnet, not mainnet.
- Sepolia ETH has no real value.
- The used testnet private keys must never be used for mainnet.
- This proves the smart-contract flow, not physical gold backing.
- Physical gold backing remains dependent on custody, audits, proofHash publication, reserve-ledger integrity, and attester integrity.
- Never put real production attester keys in `.env`.
- `cache/` can contain sensitive values and must never be committed.
- `.env.sepolia` must never be committed.

## Proof-Linked Sepolia Smoke Test

The proof-linked Sepolia smoke test takes generated Proof-of-Reserve JSON as the source of truth. It canonicalizes the JSON, computes `proofHash`, exports that hash into `MintAuthorization` and `BurnAuthorization`, signs with two attesters, and executes the mint/approve/burn flow.

Status:

- `PROOF_LINKED_SMOKE_STATUS: PASSED`.
- `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`.

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

Final state:

- Final smoke user balance: 18000.
- Final `totalSupply`: 18000.
- Net supply increase: 6000.

Artifact:

- `audit-results/proof-linked-smoke.txt`.

Caveat: Sepolia only. This proves the JSON-to-authorization `proofHash` link for the testnet smart-contract flow, not physical gold custody.
