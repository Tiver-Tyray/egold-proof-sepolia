#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: tools/hash_public_bundle.sh <bundle-dir>" >&2
  exit 2
fi

if ! command -v cast >/dev/null 2>&1; then
  echo "error: cast is not installed or not on PATH" >&2
  exit 1
fi

bundle_dir="$1"
material="$(
  python3 - "$bundle_dir" <<'PY'
import json
import pathlib
import sys

bundle = pathlib.Path(sys.argv[1])
manifest = json.loads((bundle / "manifest.json").read_text(encoding="utf-8"))
manifest["bundleHash"] = ""
files = {
    "canonical-proof.json": (bundle / "canonical-proof.json").read_text(encoding="utf-8"),
    "manifest.json": json.dumps(manifest, sort_keys=True, separators=(",", ":"), ensure_ascii=False),
    "onchain-event.json": json.dumps(json.loads((bundle / "onchain-event.json").read_text(encoding="utf-8")), sort_keys=True, separators=(",", ":"), ensure_ascii=False),
    "proof-hash.txt": (bundle / "proof-hash.txt").read_text(encoding="utf-8").strip(),
    "proof.json": json.dumps(json.loads((bundle / "proof.json").read_text(encoding="utf-8")), sort_keys=True, separators=(",", ":"), ensure_ascii=False),
    "tx-receipt.json": json.dumps(json.loads((bundle / "tx-receipt.json").read_text(encoding="utf-8")), sort_keys=True, separators=(",", ":"), ensure_ascii=False),
}
print(json.dumps(files, sort_keys=True, separators=(",", ":"), ensure_ascii=False))
PY
)"

bundle_hash="$(cast keccak "$material")"
echo "bundleHash: $bundle_hash"
