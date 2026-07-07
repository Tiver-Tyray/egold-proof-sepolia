#!/usr/bin/env python3
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

from build_public_proof_bundle import (
    BURN_EVENT,
    FORBIDDEN_TEXT,
    MINT_EVENT,
    bundle_hash_material,
    cast_keccak,
    decode_event,
    fetch_receipt,
    receipt_status,
)
from canonicalize_proof import remove_proof_hash
from validate_proof import validate


def die(message):
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        die(f"invalid JSON in {path}: {exc}")
    except OSError as exc:
        die(f"could not read {path}: {exc}")


def canonical_json(payload):
    return json.dumps(remove_proof_hash(payload), sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def assert_equal(label, left, right):
    if str(left).lower() != str(right).lower():
        die(f"{label} mismatch: {left!r} != {right!r}")


def scan_public_output(bundle_dir):
    for path in Path(bundle_dir).rglob("*"):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore").lower()
        for token in FORBIDDEN_TEXT:
            if token in text:
                die(f"forbidden public bundle content {token!r} found in {path}")


def verify_manifest_links(bundle_dir, manifest, proof, proof_hash):
    assert_equal("proofHash.txt", (bundle_dir / "proof-hash.txt").read_text(encoding="utf-8").strip(), proof_hash)
    assert_equal("manifest.proofHash", manifest["proofHash"], proof_hash)
    assert_equal("manifest.operationId", manifest["operationId"], proof["operationId"])
    assert_equal("manifest.reserveId", manifest["reserveId"], proof["reserveId"])
    assert_equal("manifest.account", manifest["account"], proof["account"])
    assert_equal("manifest.operator", manifest["operator"], proof["operator"])
    assert_equal("manifest.amountUnits", manifest["amountUnits"], proof["amountUnits"])
    assert_equal("manifest.contractAddress", manifest["contractAddress"], proof["contractAddress"])
    assert_equal("manifest.chainId", manifest["chainId"], proof["chainId"])
    assert_equal("manifest.operationType", manifest["operationType"], proof["operationType"])

    event = load_json(bundle_dir / manifest["onchainEventPath"])
    assert_equal("event.proofHash", event["proofHash"], proof_hash)
    assert_equal("event.operationId", event["operationId"], proof["operationId"])
    assert_equal("event.reserveId", event["reserveId"], proof["reserveId"])
    assert_equal("event.account", event["account"], proof["account"])
    assert_equal("event.operator", event["operator"], proof["operator"])
    assert_equal("event.amountUnits", event["amountUnits"], proof["amountUnits"])


def verify_rpc(bundle_dir, manifest, rpc_url):
    receipt = fetch_receipt(manifest["txHash"], rpc_url)
    if receipt_status(receipt) != 1:
        die("live receipt status is not 1")
    event = decode_event(receipt, manifest["contractAddress"], manifest["operationType"])
    assert_equal("live event.proofHash", event["proofHash"], manifest["proofHash"])
    assert_equal("live event.operationId", event["operationId"], manifest["operationId"])
    assert_equal("live event.reserveId", event["reserveId"], manifest["reserveId"])
    assert_equal("live event.account", event["account"], manifest["account"])
    assert_equal("live event.operator", event["operator"], manifest["operator"])
    assert_equal("live event.amountUnits", event["amountUnits"], manifest["amountUnits"])


def main():
    parser = argparse.ArgumentParser(description="Verify a public EGold proof bundle.")
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--rpc-url", default="")
    args = parser.parse_args()

    if not shutil.which("cast"):
        die("cast is required to verify public proof bundles")

    bundle_dir = Path(args.bundle)
    manifest = load_json(bundle_dir / "manifest.json")
    proof = load_json(bundle_dir / manifest["proofPath"])

    errors = validate(proof)
    if errors:
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        die("proof validation failed")

    canonical = canonical_json(proof)
    stored_canonical = (bundle_dir / manifest["canonicalProofPath"]).read_text(encoding="utf-8")
    if stored_canonical != canonical:
        die("canonical-proof.json does not match recomputed canonical JSON")

    proof_hash = cast_keccak(canonical).lower()
    verify_manifest_links(bundle_dir, manifest, proof, proof_hash)

    recomputed_bundle_hash = cast_keccak(bundle_hash_material(bundle_dir)).lower()
    assert_equal("bundle-hash.txt", (bundle_dir / "bundle-hash.txt").read_text(encoding="utf-8").strip(), recomputed_bundle_hash)
    assert_equal("manifest.bundleHash", manifest["bundleHash"], recomputed_bundle_hash)

    if args.rpc_url:
        verify_rpc(bundle_dir, manifest, args.rpc_url)

    scan_public_output(bundle_dir)
    print("PUBLIC_PROOF_BUNDLE_VALID")
    print(f"operationId: {manifest['operationId']}")
    print(f"proofHash: {manifest['proofHash']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
