# Changelog

All notable changes to this project are documented in this file.

## [v0.1.0-sepolia] - 2026-07-11

### Added

- Immutable ERC-20 EGold contract.
- Four-decimal token accounting.
- Immutable minter and reserve-attester roles with no active default admin.
- 2-of-3 threshold reserve attestations for mint and burn operations.
- EIP-712 mint and burn authorizations.
- Authorization digest replay protection.
- Cross-operation `operationId` replay protection.
- Allowance-based consent for burning another holder's balance.
- Foundry unit, fuzz, and stateful invariant test suite.
- Public Sepolia deployment and post-deploy checks.
- Etherscan source verification with published constructor arguments.
- Canonical Proof-of-Reserve format and validation tooling.
- Public mint and burn proof publication bundles.
- Public GitHub Pages proof site.
- Clean-room offline proof verifier.
- GitHub Actions CI for contract, proof, site, and secret-scan gates.

### Release Scope

- Sepolia testnet only.
- This release proves the technical and cryptographic flow; it is not a
  production gold-backed asset and represents no physical gold.
- Mainnet and production L2 deployment remain blocked pending the production
  gates documented in `AUDIT.md` and `RELEASE_CHECKPOINT.md`.
