#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: tools/hash_proof.sh <proof.json>" >&2
  exit 2
fi

if ! command -v cast >/dev/null 2>&1; then
  echo "error: cast is not installed or not on PATH" >&2
  exit 1
fi

proof_file="$1"
canonical_json="$(python3 tools/canonicalize_proof.py "$proof_file")"
canonical_byte_length="$(printf '%s' "$canonical_json" | wc -c | tr -d ' ')"
proof_hash="$(cast keccak "$canonical_json")"

echo "file: $proof_file"
echo "canonical byte length: $canonical_byte_length"
echo "proofHash: $proof_hash"
