# E-gold Public Proofs

This directory contains public EGold Proof-of-Reserve proof bundles.

Each operation bundle publishes:

- `proof.json`
- `canonical-proof.json`
- `proof-hash.txt`
- `onchain-event.json`
- `tx-receipt.json`
- `manifest.json`
- `bundle-hash.txt`
- `README.md`

To verify published bundles offline:

```sh
make verify-public-proofs-offline
```

To verify published bundles against live RPC receipts:

```sh
make verify-public-proofs
```

Proof bundles are public artifacts. They must not contain private keys, API keys, `.env` files, or local cache output.

The bundle proves that canonical proof JSON reproduces the on-chain `proofHash`. It does not prove physical custody by itself.
