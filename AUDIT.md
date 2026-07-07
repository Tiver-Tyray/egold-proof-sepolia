# E-gold Audit Pack

## 1. Scope

This audit pack covers:

- `src/EGold.sol`
- Foundry tests under `test/`
- Deployment scripts under `script/`
- Foundry, Slither, gas, snapshot, and coverage workflows

The reviewed contract is an immutable ERC-20 token with threshold Proof-of-Reserve authorization for minting and redemption burns.

## 2. Security Properties

- ERC-20 correctness is inherited from OpenZeppelin Contracts v5.x.
- Roles are immutable after deployment.
- `DEFAULT_ADMIN_ROLE` is never granted.
- There is no owner.
- There is no admin key.
- There is no pause mechanism.
- There is no freeze mechanism.
- There is no blacklist mechanism.
- There is no proxy.
- There is no upgradeability path.
- There are no forced transfers.
- Minting requires threshold reserve attestations.
- Burning requires threshold reserve/redemption attestations.
- Authorization digest replay is blocked.
- `operationId` replay is blocked across mint and burn operations.
- Burning another holder's balance requires ERC-20 allowance through `_spendAllowance`.
- Burning the minter's own balance can occur without allowance, preserving normal self-custody burn semantics.

## 3. Invariants

The stateful invariant suite checks:

- `totalSupply == modelMinted - modelBurned`
- `totalSupply <= modelMinted`
- roles remain immutable
- `MINTER_ROLE` remains assigned to the same minter
- `RESERVE_ATTESTER_ROLE` remains assigned to the same attesters
- `DEFAULT_ADMIN_ROLE` remains empty for checked actors
- `attestationThreshold` remains immutable
- `attesterCount` remains immutable

## 4. Known Trust Boundary

Physical gold is off-chain. The contract can verify threshold signatures over typed authorization data, but it cannot independently verify physical custody, vault inventory, assay quality, legal title, or redemption operations.

Reserve proof integrity depends on:

- the fixed attester set
- custody procedures
- audit procedures
- operational key security
- publication and interpretation of `proofHash` contents
- off-chain mapping between `reserveId`, `operationId`, physical vault records, and public audit artifacts

Threshold signing reduces single-key risk, but it does not remove the need for rigorous custody governance and transparent reserve reporting.

## 5. Pre-Deploy Checklist

Run and archive:

- `forge fmt`
- `forge test -vvv`
- `FOUNDRY_PROFILE=ci forge test -vvv`
- `forge test --gas-report`
- `forge snapshot`
- `forge coverage`
- `slither . --config-file slither.config.json`

Before broadcasting:

- verify constructor args
- verify bytecode
- publish deployment config
- publish attester addresses
- publish minter address
- publish reserve proof format
- publish operation ID derivation rules
- publish attester signing policy
- publish hardware custody policy

## 6. Executed Audit Gates - 2026-07-05

Artifacts are archived under `audit-results/`.

| Gate | Result |
| --- | --- |
| `forge fmt` | Pass. `audit-results/forge-fmt.txt` is empty, indicating no formatter output. |
| `forge test -vvv` | Pass. 65 tests passed, 0 failed, 0 skipped. |
| `FOUNDRY_PROFILE=ci forge test -vvv` | Pass. 65 tests passed, 0 failed, 0 skipped. |
| `forge test --gas-report` | Pass. 65 tests passed, 0 failed, 0 skipped. |
| `forge snapshot` | Pass. `.gas-snapshot` was created with 64 entries. |
| `forge coverage` | Pass. `src/EGold.sol` has 100.00% line, statement, branch, and function coverage. |
| `slither . --config-file slither.config.json` | Completed after workspace-local Slither install. 2 findings remain documented below. |

Default profile execution details:

- Tests: 65 total.
- Fuzz: `testFuzzMintSupplyReplayEnOperationReplay` ran 4096 cases.
- Invariants: 8 invariant properties.
- Invariant runs: 512 per invariant property, 4096 aggregate runs.
- Invariant calls: 65536 per invariant property, 524288 aggregate calls.

CI profile execution details:

- Tests: 65 total.
- Fuzz: `testFuzzMintSupplyReplayEnOperationReplay` ran 10000 cases.
- Invariants: 8 invariant properties.
- Invariant runs: 2048 per invariant property, 16384 aggregate runs.
- Invariant calls: 524288 per invariant property, 4194304 aggregate calls.

Gas summary:

- Deployment gas: 1612741.
- Foundry gas-report deployment size: 8911.
- Deployed runtime bytecode size from `forge inspect`: 6378 bytes.
- `mint` average gas: 107117.
- `burnFrom` average gas: 106674.

Coverage summary:

| Scope | Lines | Statements | Branches | Functions |
| --- | --- | --- | --- | --- |
| `src/EGold.sol` | 100.00% (95/95) | 100.00% (103/103) | 100.00% (21/21) | 100.00% (16/16) |
| Total project | 58.18% (128/220) | 60.58% (146/241) | 44.23% (23/52) | 47.73% (21/44) |

Slither execution notes:

- `slither` was not available on `PATH`.
- `python3 -m pip install slither-analyzer` was attempted and failed because the environment could not write to `/Users/tyray/.local`.
- `python3 -m pip install --target work/slither-py slither-analyzer` succeeded.
- Final Slither run analyzed 21 contracts with 101 detectors and reported 2 findings.

## 7. Open Findings

### Slither: `timestamp`

`_validateCommonAuthorization` checks `block.timestamp` against `validAfter` and `validBefore`.

Disposition: accepted for this design. The timestamp window is part of the EIP-712 authorization validity model. Operational signing policy should use conservative validity windows and avoid single-block precision assumptions.

### Slither: `solc-version`

Slither flags the `^0.8.20` pragma used by `src/EGold.sol` and OpenZeppelin Contracts.

Disposition: accepted for this pass. Foundry pins compilation to `solc_version = "0.8.20"` in `foundry.toml`, and all executed gates pass against that compiler. A future compiler upgrade can be evaluated separately with the same invariant and Slither gates.

### Resolved During This Run: `uninitialized-local`

Slither initially flagged `previousSigner` in `_verifyThresholdSignatures` as an uninitialized local. It is now explicitly initialized to `address(0)`. This does not alter role authority, mint authority, burn consent, pause/freeze/blacklist behavior, proxy behavior, or upgradeability.

## 8. Deployment Gate Verdict

According to the executed automated checks, deployment is technically cleared with the two documented Slither findings accepted as non-blocking design/tooling findings.

This verdict covers only the smart-contract gate results above. Production deployment still depends on off-chain controls that the contract cannot prove by itself: vault custody, attester key security, reserve audit quality, redemption operations, proof publication, and independent review of deployment parameters.

## 9. Deployment Readiness

- Local audit gates are green for the current contract and test suite.
- Testnet rehearsal is mandatory before any mainnet or production L2 deployment.
- Constructor args must be generated with `make constructor-args` and published with the deployment record.
- The deployed runtime codehash must be recorded in `deployments/<chainid>/EGold.json`.
- `EGOLD_ADDRESS` must be set after deployment and checked with `make post-deploy-check`.
- The Slither `timestamp` finding is non-blocking because timestamps are used only for signed authorization validity windows.
- The Slither `solc-version` finding is non-blocking for this pass because `foundry.toml` pins `solc_version = "0.8.20"`.
- Deployment remains blocked operationally if minter and attester keys are not separated, if attester keys are not hardware/offline governed, or if the `proofHash` format is not published before real minting.

## 10. Local Anvil End-to-End Rehearsal

Local rehearsal status:

- Post-deploy check: passed.
- `make smoke-local-dry`: passed.
- `make smoke-local`: broadcast passed.
- Final `totalSupply`: 6000.
- Final smoke user balance: 6000.

Local artifacts:

- Smoke test log: `audit-results/local-smoke-test.txt`.
- Broadcast artifact: `broadcast/SmokeTestEGoldLocal.s.sol/31337/run-latest.json`.

The local smoke flow proved metadata checks, immutable role assignment, empty `DEFAULT_ADMIN_ROLE`, threshold mint authorization, user allowance before third-party burn, threshold burn authorization, replay marker updates, and supply/balance accounting on a local Anvil chain.

Anvil state is ephemeral and disappears when the local Anvil node stops. The rehearsal artifacts are local evidence of the completed flow, not a persistent network deployment record.

This is not a proof of reserve. Physical gold backing remains outside the smart contract and depends on custody, reserve audits, proofHash publication, and attester integrity.

## 11. Public Sepolia End-to-End Rehearsal

Sepolia rehearsal status:

- Contract address: `0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9`.
- Chain ID: 11155111.
- Post-deploy check: passed.
- Smoke test: passed.
- Final `totalSupply`: 6000.
- Final smoke user balance: 6000.
- Runtime codehash: `0x10ca1be035d896ccfa650e9533d5712c737d082b19b40ee05012bbea55358657`.

Transactions:

- Mint tx: `0x1311e85ee19129ebd4670e6c20dfb84a985f6afd677dbb6671b12da2b58dde2a`.
- Approve tx: `0x89ad70f8b8c1ffdcd7b53bb550015baf2e76dc401b4aae2fef52d412cb250b07`.
- BurnFrom tx: `0x1b60df8b0ce254da2b7e89471f9621de47b912538761cc98fc85f5321fb1459b`.

Artifacts:

- Post-deploy check log: `audit-results/sepolia-post-deploy-check.txt`.
- Smoke test log: `audit-results/sepolia-smoke.txt`.
- Broadcast artifact: `broadcast/SmokeTestEGoldLocal.s.sol/11155111/run-latest.json`.

Caveat: this rehearsal is Sepolia only. Sepolia ETH has no real value, and the testnet result proves the smart-contract flow only. It does not prove physical gold backing, custody quality, reserve-ledger correctness, or attester operational integrity.

## 12. Sepolia Source Verification

Sepolia source verification status:

- Etherscan verification: passed.
- Verification output: `Contract successfully verified`.
- Contract address: `0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9`.
- Chain ID: 11155111.
- Runtime codehash: `0x10ca1be035d896ccfa650e9533d5712c737d082b19b40ee05012bbea55358657`.
- Constructor args artifact: `audit-results/sepolia-verify-constructor-args.txt`.
- Verification output artifact: `audit-results/sepolia-etherscan-verify.txt`.
- Etherscan code page: <https://sepolia.etherscan.io/address/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9#code>.

Caveat: this verification is Sepolia only, not production. It confirms that the public Sepolia source-verification path succeeded for the testnet deployment, but it does not prove physical gold backing, reserve custody quality, redemption operations, or production key custody.

## 13. Proof-of-Reserve Operational Layer

The off-chain Proof-of-Reserve operational layer has been added:

- `PROOF_OF_RESERVE_FORMAT.md` defines the canonical `proofHash` format.
- `RESERVE_LEDGER_SPEC.md` defines the append-only reserve ledger model.
- `ATTESTER_KEY_POLICY.md` defines immutable attester key custody and signing rules.
- `MINTER_OPERATION_POLICY.md` defines mint and burn submission procedures.
- `INCIDENT_AND_MIGRATION_POLICY.md` defines response and voluntary migration procedures for immutable deployments.
- `schemas/egold-proof-v1.schema.json` defines the proof payload shape.
- `examples/proofs/mint-proof-v1.example.json` and `examples/proofs/burn-proof-v1.example.json` provide Sepolia examples without private keys or signatures.
- `tools/canonicalize_proof.py`, `tools/validate_proof.py`, and `tools/hash_proof.sh` provide reproducible proof validation and hashing.

Caveat: this is documentation and operational tooling. It is not an external custody audit, legal reserve opinion, vault inspection, or independent attester key custody review. Production deployment remains blocked until the reserve process and key operations are externally reviewable and operationally tested.

## 14. Proof-Linked Smoke Test

Goal: prove that canonical Proof-of-Reserve JSON payloads produce the exact `proofHash` values used in on-chain `MintAuthorization` and `BurnAuthorization`.

The proof-linked smoke tooling:

- generates fresh Sepolia smoke proof JSON under `generated/proofs/<timestamp>/`
- validates the generated `MINT` and `BURN` proofs
- canonicalizes each proof payload
- computes each `proofHash` with `cast keccak`
- exports authorization environment variables without private keys
- runs `script/ProofLinkedSmokeTestEGold.s.sol` against `EGOLD_ADDRESS`
- signs the mint and burn authorizations with attester 1 and attester 2
- broadcasts mint, approve, and burn only when `make proof-linked-smoke` is explicitly used

Status: PASSED on Sepolia.

Execution result:

- `PROOF_LINKED_SMOKE_STATUS: PASSED`.
- `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL`.
- Mint tx: `0xc3b771ae3fbc18ff123624ac25fc256714c0c574c8200fcfc06bafccfb35746b`.
- Approve tx: `0x86ccc54fe79074c6689c0f2701b1a85a06a2b2d3729d09f49a7c9175476b841f`.
- BurnFrom tx: `0x2dd0ce5f9f4e8d54682542f52ff272973b1ddeb8c6b4d51ea3205a1a5ebe6604`.
- Mint `proofHash`: `0xa4a58510a5ce4ff29fceaa4d8105a59740016197b0ef2800174cc63d2729cb94`.
- Burn `proofHash`: `0xe6b0d4cd8409f6c3f281fd28b08d3efe70fc4056f6c3cb3da539dd195fca331b`.
- Final smoke user balance: 18000.
- Final `totalSupply`: 18000.
- Artifact: `audit-results/proof-linked-smoke.txt`.

The mint and burn `proofHash` values came from canonical JSON proof payloads, were used in EIP-712 authorizations, were signed by threshold attesters, and were accepted by the deployed Sepolia contract. The mint and burn transactions succeeded on-chain.

Caveat: this proves the JSON-to-authorization hash link for the smart-contract flow. It still does not prove external custody, vault inventory, audit correctness, reserve-ledger truth, or production attester key custody.

## 15. Public Proof Publication Pipeline

Status:

- Public proof publication pipeline: added.
- Public bundle builder: added.
- Public bundle verifier: added.
- Public proof index verifier: added.
- Public bundle hash helper: added.
- `make public-proof-check`: passed.

The publication pipeline writes validated public proof bundles under `proofs/<network>/<chainId>/<contractAddress>/<operationId>/`. Each bundle contains `proof.json`, `canonical-proof.json`, `proof-hash.txt`, `onchain-event.json`, `tx-receipt.json`, `manifest.json`, `bundle-hash.txt`, and `README.md`.

The verifier checks that canonical proof JSON reproduces `proofHash`, that the published event fields match the proof payload, that the receipt status is successful, and that public bundle files do not contain private keys, API keys, local cache material, or authorization witness material that should remain private.

Sepolia public proof bundles were built and verified:

- Mint bundle: `proofs/sepolia/11155111/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9/0xe9396bc6a2411b20d9bfa07caa89fa61373408d02c8cb829cf570589cf865958`.
- Mint bundle hash: `0x2758cd4141a1183b434f4c37c22c22c04a5cacd46a3c5e2278c333394b640407`.
- Burn bundle: `proofs/sepolia/11155111/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9/0x6b5f69ab483efc91f02afcdbabda48caef32ce8f863208d4ff418c9e91af53ea`.
- Burn bundle hash: `0x2afc50f4873ab268b53684b25208ee89f5ec6fb22f20b6484ec313bfa071b7b7`.
- Index: `proofs/sepolia/11155111/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9/index.json`.

Caveat: public proof publication makes the `proofHash` path externally reproducible. It still does not prove physical custody, custodian honesty, audit correctness, reserve-ledger truth, or production attester key custody by itself.

## 16. Public Static Proof Site

Status:

- Static site builder: added.
- Static site verifier: added.
- Public output scanner: added.
- GitHub Actions CI: added.
- External GitHub Pages publication: pending until the repository is pushed and Pages is enabled.

The public site is generated under `docs/` from the validated `proofs/` tree. It exposes the Sepolia contract address, Etherscan code link, proof index, mint and burn bundle links, transaction hashes, proof hashes, bundle hashes, and local verification commands.

`make public-site-check` builds the site, verifies the copied proof index offline, and scans both `docs/` and `proofs/` for sensitive material.

Caveat: the static site improves public reproducibility of the proof publication flow. It still does not prove physical custody by itself.
