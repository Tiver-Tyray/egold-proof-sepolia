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

## 8. Caveat

GitHub Pages publication is public. Only `docs/` should be served.

This is a Sepolia rehearsal, not production proof of physical custody.
