#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

from canonicalize_proof import remove_proof_hash


DEFAULT_CONTRACT = "0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9"
AUDIT_LOG = Path("audit-results/proof-linked-smoke.txt")
BROADCAST_JSON = Path("broadcast/ProofLinkedSmokeTestEGold.s.sol/11155111/run-latest.json")


def die(message):
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def redact_args(args):
    redacted = []
    skip_next = False
    for arg in args:
        if skip_next:
            redacted.append("<redacted>")
            skip_next = False
            continue
        redacted.append(arg)
        if arg == "--rpc-url":
            skip_next = True
    return redacted


def run(args):
    try:
        return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()
    except FileNotFoundError:
        die(f"{args[0]} is not installed or not on PATH")
    except subprocess.CalledProcessError as exc:
        die(f"{' '.join(redact_args(args))} failed: {exc.stderr.strip()}")


def canonical_json(payload):
    return json.dumps(remove_proof_hash(payload), sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def proof_hash(path):
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    return run(["cast", "keccak", canonical_json(payload)]).lower()


def parse_audit_log():
    if not AUDIT_LOG.exists():
        die(f"missing {AUDIT_LOG}; run make proof-linked-smoke first")
    text = AUDIT_LOG.read_text(encoding="utf-8", errors="ignore")
    patterns = {
        "mintProofHash": r"mint proofHash:\s*(0x[a-fA-F0-9]{64})",
        "burnProofHash": r"burn proofHash:\s*(0x[a-fA-F0-9]{64})",
        "mintOperationId": r"mint operationId:\s*(0x[a-fA-F0-9]{64})",
        "burnOperationId": r"burn operationId:\s*(0x[a-fA-F0-9]{64})",
    }
    values = {}
    for key, pattern in patterns.items():
        match = re.search(pattern, text)
        if not match:
            die(f"could not parse {key} from {AUDIT_LOG}")
        values[key] = match.group(1).lower()
    return values


def find_matching_proof(target_hash, operation_type):
    proof_name = "mint-proof.json" if operation_type == "MINT" else "burn-proof.json"
    candidates = sorted(Path("generated/proofs").glob(f"*/{proof_name}"))
    matches = [path for path in candidates if proof_hash(path) == target_hash.lower()]
    if not matches:
        die(f"no generated proof found for {operation_type} proofHash {target_hash}; run make proof-linked-smoke again")
    return matches[-1]


def parse_broadcast_txs():
    env_mint = os.environ.get("EGOLD_MINT_TX_HASH", "").strip()
    env_burn = os.environ.get("EGOLD_BURN_TX_HASH", "").strip()
    if env_mint and env_burn:
        return env_mint, env_burn

    if not BROADCAST_JSON.exists():
        die(f"missing {BROADCAST_JSON}; set EGOLD_MINT_TX_HASH and EGOLD_BURN_TX_HASH as fallback")
    data = json.loads(BROADCAST_JSON.read_text(encoding="utf-8"))
    mint_tx = ""
    burn_tx = ""
    for tx in data.get("transactions", []):
        function = tx.get("function", "")
        if function.startswith("mint("):
            mint_tx = tx.get("hash", "")
        if function.startswith("burnFrom("):
            burn_tx = tx.get("hash", "")
    if not mint_tx and env_mint:
        mint_tx = env_mint
    if not burn_tx and env_burn:
        burn_tx = env_burn
    if not mint_tx or not burn_tx:
        die("could not parse mint/burn tx hashes from broadcast; set EGOLD_MINT_TX_HASH and EGOLD_BURN_TX_HASH")
    return mint_tx, burn_tx


def build_bundle(proof_path, tx_hash, operation_type, args):
    command = [
        "python3",
        "tools/build_public_proof_bundle.py",
        "--proof",
        str(proof_path),
        "--tx-hash",
        tx_hash,
        "--operation-type",
        operation_type,
        "--rpc-url",
        args.rpc_url,
        "--out-dir",
        args.out_dir,
        "--contract",
        args.contract,
        "--network",
        args.network,
        "--chain-id",
        str(args.chain_id),
    ]
    print(run(command))


def main():
    parser = argparse.ArgumentParser(description="Build public proof bundles from the latest proof-linked smoke run.")
    parser.add_argument("--rpc-url", required=True)
    parser.add_argument("--out-dir", default="proofs")
    parser.add_argument("--contract", default=os.environ.get("EGOLD_ADDRESS", DEFAULT_CONTRACT))
    parser.add_argument("--network", default="sepolia")
    parser.add_argument("--chain-id", type=int, default=11155111)
    args = parser.parse_args()

    values = parse_audit_log()
    mint_proof = find_matching_proof(values["mintProofHash"], "MINT")
    burn_proof = find_matching_proof(values["burnProofHash"], "BURN")
    mint_tx, burn_tx = parse_broadcast_txs()

    build_bundle(mint_proof, mint_tx, "MINT", args)
    build_bundle(burn_proof, burn_tx, "BURN", args)
    print("PUBLIC_PROOF_BUNDLES_FROM_LATEST_SMOKE_BUILT")
    print(f"mint bundle operationId: {values['mintOperationId']}")
    print(f"burn bundle operationId: {values['burnOperationId']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
