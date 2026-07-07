# E-gold Public Proof Publication

## 1. Scope

This document defines the public publication format for EGold Proof-of-Reserve proof bundles.

The publication layer makes `proofHash` publicly reproducible. A third party can download a bundle, canonicalize `proof.json`, hash it, compare the result to the on-chain `ReserveMint` or `ReserveBurn` event, and verify that the published proof fields match the emitted event fields.

This layer does not prove physical custody by itself. Physical reserve truth still depends on custody controls, external audits, reserve-ledger integrity, public proof publication, and attester integrity.

## 2. Directory Layout

```text
proofs/
  README.md
  sepolia/
    11155111/
      <contractAddress>/
        index.json
        <operationId>/
          proof.json
          canonical-proof.json
          proof-hash.txt
          onchain-event.json
          tx-receipt.json
          manifest.json
          bundle-hash.txt
          README.md
```

Runtime artifacts under `generated/` are temporary local output and remain ignored. Public proof output is written under:

```text
proofs/sepolia/11155111/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9/<operationId>/
```

## 3. Verification Flow

To verify a public proof bundle:

1. Download the operation directory.
2. Canonicalize `proof.json`.
3. Compute `keccak256(canonical-proof.json)`.
4. Compare the result with `proof-hash.txt`.
5. Compare `proofHash` with the on-chain `ReserveMint` or `ReserveBurn` event.
6. Compare `operationId`, `reserveId`, `account`, `operator`, and `amountUnits`.
7. Check `tx-receipt.json` has `status == 1`.
8. Check `contractAddress` equals the expected EGold address.
9. Check `chainId` equals the expected network.
10. Check `tokenDecimals == 4`.
11. Check `operationType` is `MINT` or `BURN`.

With repository tooling:

```sh
make verify-public-proofs-offline
```

With live RPC receipt re-checks:

```sh
make verify-public-proofs
```

The Sepolia proof-linked smoke publication rehearsal has produced two verified public bundles:

- Mint operation: `0xe9396bc6a2411b20d9bfa07caa89fa61373408d02c8cb829cf570589cf865958`.
- Burn operation: `0x6b5f69ab483efc91f02afcdbabda48caef32ce8f863208d4ff418c9e91af53ea`.
- Index: `proofs/sepolia/11155111/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9/index.json`.

## 4. Public Bundle Manifest

`manifest.json` contains:

- `schemaVersion`: `EGOLD_PUBLIC_PROOF_BUNDLE_V1`
- `network`
- `chainId`
- `contractAddress`
- `operationType`
- `operationId`
- `reserveId`
- `proofHash`
- `txHash`
- `blockNumber`
- `eventName`
- `operator`
- `account`
- `amountUnits`
- `proofPath`
- `canonicalProofPath`
- `txReceiptPath`
- `onchainEventPath`
- `generatedAt`
- `verificationStatus`
- `bundleHash`

The bundle hash is computed deterministically from the public bundle content with `manifest.bundleHash` blanked during hashing, so the hash remains reproducible.

## 5. Security Notes

- Public bundles must not contain private keys.
- Public bundles must not contain API keys.
- Public bundles must not contain `.env` files.
- Public bundles must not contain `cache/`.
- Public bundles must not contain authorization witness material beyond public event and proof data.
- `proofHash` is reproducible, but physical custody remains off-chain.
- Publication should be treated as append-only.
- Old proof bundles must not be silently overwritten.

## 6. Non-Goals

This publication layer does not define:

- a legal claim model
- a pricing oracle
- a physical audit by itself
- a guarantee that a custodian is honest
- a replacement for external reserve review

## 7. Static Public Site

The static public site under `docs/` is generated from `proofs/`.

- `docs/` is safe to publish if `make public-site-check` passes.
- `docs/` contains a static `index.html`, verification manifest, and copied public proof bundles.
- GitHub Pages can use `docs/` as the publishing source.
- Proof verification remains possible offline through the copied `docs/proofs/` bundle tree.
- The site contains no external dependencies, no CDN references, no tracking, and no required JavaScript.

Build and verify:

```sh
make public-site-check
```
