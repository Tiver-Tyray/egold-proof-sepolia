# EGold

| Project status | Value |
| --- | --- |
| Project | EGold |
| Release | `v0.1.0-sepolia` |
| Status | public testnet rehearsal |
| Network | Sepolia |
| Chain ID | `11155111` |
| Contract | [`0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9`](https://sepolia.etherscan.io/address/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9) |
| Verified source | [Etherscan Sepolia](https://sepolia.etherscan.io/address/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9#code) |
| Public proofs | [GitHub Pages](https://tiver-tyray.github.io/egold-proof-sepolia/) |
| Tests | 65 passed, 0 failed |
| Public proof bundles | 2 |
| Caveat | Sepolia only, not a production gold-backed asset |

EGold is an immutable ERC-20 testnet implementation with four decimals,
fixed minter and reserve-attester roles, 2-of-3 threshold reserve
attestations, EIP-712 authorizations, replay protection, and allowance-based
consent for third-party burns.

## Verification

Run the complete local publication gate:

```sh
make publication-check
```

Verify the published proof index without an RPC connection:

```sh
make verify-public-proofs-offline
```

The canonical public proof index is:

```text
proofs/sepolia/11155111/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9/index.json
```

See `RELEASE_CHECKPOINT.md` for the frozen Sepolia baseline,
`PUBLIC_TESTNET_REHEARSAL.md` for the on-chain rehearsal evidence, and
`PUBLICATION_RUNBOOK.md` for publication and clean-room verification steps.

## Security Boundary

The contract has no owner, admin authority, pause, freeze, blacklist, proxy,
upgrade path, clawback, or forced-transfer mechanism. `DEFAULT_ADMIN_ROLE` is
never granted, and role mutation functions always revert.

This repository proves a cryptographic and technical testnet flow. It does not
prove physical gold custody or create a production gold-backed asset. Production
requires external custody, independent audits, a public reserve ledger, formal
attester operations, and legal and operational review.
