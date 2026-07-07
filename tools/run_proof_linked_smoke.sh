#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || { [ "$1" != "dry" ] && [ "$1" != "broadcast" ]; }; then
  echo "usage: tools/run_proof_linked_smoke.sh dry|broadcast" >&2
  exit 2
fi

mode="$1"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ -d "$repo_root/work/foundry-bin" ]; then
  export PATH="$repo_root/work/foundry-bin:$PATH"
fi

if [ -f ".env.sepolia" ]; then
  set -a
  # shellcheck disable=SC1091
  . ".env.sepolia"
  set +a
fi

: "${RPC_URL:?RPC_URL must be set in the environment or .env.sepolia}"
: "${EGOLD_ADDRESS:?EGOLD_ADDRESS must be set}"
: "${EGOLD_MINTER:?EGOLD_MINTER must be set}"
: "${EGOLD_SMOKE_USER:?EGOLD_SMOKE_USER must be set}"

mkdir -p audit-results

proof_output="$(python3 tools/create_smoke_proofs.py)"
printf '%s\n' "$proof_output"

mint_proof="$(printf '%s\n' "$proof_output" | awk -F= '/^MINT_PROOF_PATH=/{print $2}')"
burn_proof="$(printf '%s\n' "$proof_output" | awk -F= '/^BURN_PROOF_PATH=/{print $2}')"

if [ -z "$mint_proof" ] || [ -z "$burn_proof" ]; then
  echo "error: could not determine generated proof paths" >&2
  exit 1
fi

python3 tools/validate_proof.py "$mint_proof"
python3 tools/validate_proof.py "$burn_proof"

eval "$(python3 tools/export_proof_auth_env.py --mint "$mint_proof" --burn "$burn_proof")"

echo "mint proof: $mint_proof"
echo "burn proof: $burn_proof"
echo "mint proofHash: $EGOLD_MINT_PROOF_HASH"
echo "burn proofHash: $EGOLD_BURN_PROOF_HASH"

if [ "$mode" = "dry" ]; then
  forge script script/ProofLinkedSmokeTestEGold.s.sol --rpc-url "$RPC_URL" -vvvv \
    | tee audit-results/proof-linked-smoke-dry.txt
else
  forge script script/ProofLinkedSmokeTestEGold.s.sol --rpc-url "$RPC_URL" --broadcast -vvvv \
    | tee audit-results/proof-linked-smoke.txt
fi
