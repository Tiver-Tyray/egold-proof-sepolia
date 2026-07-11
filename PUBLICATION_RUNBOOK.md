# E-gold Public Proof Publication Runbook

## 1. Run Local Checks

```sh
make publication-check
```

## 2. Open Site Locally

```sh
open docs/index.html
```

## 3. Create GitHub Repository

Create a GitHub repository if needed, then connect this local project to it.

## 4. Commit Safe Files Only

Commit:

- `src/`
- `test/`
- `script/`
- `tools/`
- `proofs/`
- `docs/`
- `schemas/`
- `examples/`
- Markdown docs
- `foundry.toml`
- `Makefile`
- `.github/workflows/ci.yml`

## 5. Never Commit

- `.env`
- `.env.sepolia`
- `.secrets/`
- `cache/`
- `generated/`
- private keys
- API keys

## 6. GitHub Pages Setup

1. Open repository Settings.
2. Open Pages.
3. Set Source to `Deploy from a branch`.
4. Set Branch to `main`.
5. Set Folder to `/docs`.
6. Save.

## 7. After Pages Is Live

1. Open the website.
2. Download a proof bundle.
3. Verify from a fresh clone.
4. Record the public URL in `PUBLIC_TESTNET_REHEARSAL.md`.

## 8. Published Sepolia Checkpoint

- Release: `v0.1.0-sepolia`.
- Repository: <https://github.com/Tiver-Tyray/egold-proof-sepolia>.
- GitHub Pages: <https://tiver-tyray.github.io/egold-proof-sepolia/>.
- Contract: `0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9`.
- Chain ID: 11155111.
- GitHub Actions EGold CI: PASSED.
- GitHub Pages deployment: PASSED.
- Fresh clone offline proof verification: PASSED.
- Public site verification: PASSED.
- Public secret scan: PASSED.

The canonical clean-room verification command is:

```sh
make verify-public-proofs-offline
```

## 9. Caveat

GitHub Pages publication is public. Only `docs/` should be served.

This is a Sepolia rehearsal, not production proof of physical custody.
