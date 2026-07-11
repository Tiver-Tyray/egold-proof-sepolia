# EGold v0.1.0-sepolia Release Checkpoint

Recorded: 2026-07-11.

This document freezes the technical Sepolia baseline for release
`v0.1.0-sepolia`.

## Release

- Release: `v0.1.0-sepolia`.
- Status: public testnet rehearsal.
- Network: Sepolia.

## Contract

- Address: `0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9`.
- Runtime codehash: `0x10ca1be035d896ccfa650e9533d5712c737d082b19b40ee05012bbea55358657`.
- Chain ID: `11155111`.
- Threshold: 2-of-3.
- Token decimals: 4.
- Unit model: 10000 units = 1.0000 EGOLD = 1 gram.
- Verified source: <https://sepolia.etherscan.io/address/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9#code>.
- Public proofs: <https://tiver-tyray.github.io/egold-proof-sepolia/>.

## Roles

- Minter: `0xAB202fDd7D6Aa4C2c8ee96b184327e8aF635bD59`.
- Attester 1: `0xd06F1701Ca14dD3654bDC911F2F9749A934a6B51`.
- Attester 2: `0x2b1E491122d517dFc4fB041ef92056C1bA7Ba3A9`.
- Attester 3: `0x44ab914Dfe18205E423902A0b6Bdc1683a834694`.

The roles are immutable. `DEFAULT_ADMIN_ROLE` is unused, and the deployment has
no owner or mutable administrator.

## Proof-Linked Smoke Transactions

- Mint: `0xc3b771ae3fbc18ff123624ac25fc256714c0c574c8200fcfc06bafccfb35746b`.
- Approve: `0x86ccc54fe79074c6689c0f2701b1a85a06a2b2d3729d09f49a7c9175476b841f`.
- Burn: `0x2dd0ce5f9f4e8d54682542f52ff272973b1ddeb8c6b4d51ea3205a1a5ebe6604`.

## Public Proof Hashes

- Mint: `0xa4a58510a5ce4ff29fceaa4d8105a59740016197b0ef2800174cc63d2729cb94`.
- Burn: `0xe6b0d4cd8409f6c3f281fd28b08d3efe70fc4056f6c3cb3da539dd195fca331b`.

## Bundle Hashes

- Mint: `0x2758cd4141a1183b434f4c37c22c22c04a5cacd46a3c5e2278c333394b640407`.
- Burn: `0x2afc50f4873ab268b53684b25208ee89f5ec6fb22f20b6484ec313bfa071b7b7`.

## Verification Gates

| Gate | Result |
| --- | --- |
| Forge tests | PASSED |
| CI profile tests | PASSED |
| Proof check | PASSED |
| Offline proof index | PASSED |
| Public site verification | PASSED |
| Public secret scan | PASSED |
| Fresh clone verification | PASSED |
| Etherscan source verification | PASSED |
| GitHub Actions EGold CI | PASSED |
| GitHub Pages deployment | PASSED |

## Release Boundary

This is a Sepolia testnet release. It represents no real gold and proves only
the cryptographic and technical flow exercised by the tests, proof tooling,
public verifier, and Sepolia transactions.

Physical gold backing requires a real custodian, independent audits, a public
reserve ledger, and formal attester procedures. The testnet keys used for this
rehearsal must never be used for production. Mainnet and production L2 deployment
remain blocked.
