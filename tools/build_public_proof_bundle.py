#!/usr/bin/env python3
import argparse
import copy
import datetime as dt
import json
import shutil
import subprocess
import sys
from pathlib import Path

from canonicalize_proof import remove_proof_hash
from validate_proof import validate


MINT_EVENT = "ReserveMint(address,address,uint256,bytes32,bytes32,bytes32,bytes32)"
BURN_EVENT = "ReserveBurn(address,address,uint256,bytes32,bytes32,bytes32,bytes32)"
FORBIDDEN_TEXT = [
    "privatekey",
    "private_key",
    "private key",
    "apikey",
    "api_key",
    "etherscan_api_key",
    "secret",
    "signature",
    "signatures",
    "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    "59c6995e998f97a5a0044966f0945383b49f7dcb9b654ca7c66d8afd4fbd968",
    "5de4111a56be78f6e3e392fb0f3f5aa3e971f1b351d4a5f5d78b8d93e3fbd0e3",
]


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


def cast_keccak(text):
    return run(["cast", "keccak", text])


def load_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        die(f"invalid JSON in {path}: {exc}")
    except OSError as exc:
        die(f"could not read {path}: {exc}")


def write_json(path, payload):
    Path(path).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def parse_int(value):
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        return int(value, 16) if value.startswith("0x") else int(value)
    die(f"cannot parse integer value {value!r}")


def normalize_hex(value):
    if not isinstance(value, str):
        die(f"expected hex string, got {value!r}")
    return value.lower()


def topic_to_address(topic):
    topic = normalize_hex(topic)
    return "0x" + topic[-40:]


def words(data):
    data = normalize_hex(data)
    raw = data[2:] if data.startswith("0x") else data
    return ["0x" + raw[i : i + 64] for i in range(0, len(raw), 64) if raw[i : i + 64]]


def receipt_status(receipt):
    value = receipt.get("status")
    if value is None and "receipt" in receipt:
        value = receipt["receipt"].get("status")
    return parse_int(value)


def receipt_logs(receipt):
    if isinstance(receipt.get("logs"), list):
        return receipt["logs"]
    if isinstance(receipt.get("receipt"), dict) and isinstance(receipt["receipt"].get("logs"), list):
        return receipt["receipt"]["logs"]
    die("receipt JSON does not contain logs")


def receipt_block_number(receipt):
    value = receipt.get("blockNumber")
    if value is None and "receipt" in receipt:
        value = receipt["receipt"].get("blockNumber")
    return parse_int(value)


def decode_event(receipt, contract, operation_type):
    event_name = "ReserveMint" if operation_type == "MINT" else "ReserveBurn"
    event_signature = MINT_EVENT if operation_type == "MINT" else BURN_EVENT
    topic0 = cast_keccak(event_signature).lower()
    contract_lower = contract.lower()

    for log in receipt_logs(receipt):
        if log.get("address", "").lower() != contract_lower:
            continue
        topics = log.get("topics") or []
        if len(topics) < 4 or topics[0].lower() != topic0:
            continue

        data_words = words(log.get("data", "0x"))
        if len(data_words) < 4:
            die(f"{event_name} log has insufficient data words")

        return {
            "eventName": event_name,
            "contractAddress": contract,
            "operator": topic_to_address(topics[1]),
            "account": topic_to_address(topics[2]),
            "amountUnits": str(parse_int(data_words[0])),
            "operationId": topics[3].lower(),
            "reserveId": data_words[1].lower(),
            "proofHash": data_words[2].lower(),
            "digest": data_words[3].lower(),
            "logIndex": parse_int(log.get("logIndex", "0x0")),
            "topic0": topic0,
        }

    die(f"{event_name} event not found in receipt")


def fetch_receipt(tx_hash, rpc_url):
    return json.loads(run(["cast", "receipt", tx_hash, "--rpc-url", rpc_url, "--json"]))


def assert_equal(label, left, right):
    if str(left).lower() != str(right).lower():
        die(f"{label} mismatch: {left!r} != {right!r}")


def validate_against_event(proof, args, proof_hash, event):
    assert_equal("operationType", proof["operationType"], args.operation_type)
    assert_equal("contractAddress", proof["contractAddress"], args.contract)
    assert_equal("chainId", proof["chainId"], args.chain_id)
    assert_equal("operator", proof["operator"], event["operator"])
    assert_equal("account", proof["account"], event["account"])
    assert_equal("amountUnits", proof["amountUnits"], event["amountUnits"])
    assert_equal("operationId", proof["operationId"], event["operationId"])
    assert_equal("reserveId", proof["reserveId"], event["reserveId"])
    assert_equal("proofHash", proof_hash, event["proofHash"])
    if proof.get("tokenDecimals") != 4:
        die("tokenDecimals must be 4")


def bundle_hash_material(bundle_dir):
    manifest = load_json(bundle_dir / "manifest.json")
    manifest["bundleHash"] = ""
    files = {
        "canonical-proof.json": (bundle_dir / "canonical-proof.json").read_text(encoding="utf-8"),
        "manifest.json": json.dumps(manifest, sort_keys=True, separators=(",", ":"), ensure_ascii=False),
        "onchain-event.json": json.dumps(load_json(bundle_dir / "onchain-event.json"), sort_keys=True, separators=(",", ":"), ensure_ascii=False),
        "proof-hash.txt": (bundle_dir / "proof-hash.txt").read_text(encoding="utf-8").strip(),
        "proof.json": json.dumps(load_json(bundle_dir / "proof.json"), sort_keys=True, separators=(",", ":"), ensure_ascii=False),
        "tx-receipt.json": json.dumps(load_json(bundle_dir / "tx-receipt.json"), sort_keys=True, separators=(",", ":"), ensure_ascii=False),
    }
    return json.dumps(files, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def scan_public_output(bundle_dir):
    for path in bundle_dir.rglob("*"):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore").lower()
        for token in FORBIDDEN_TEXT:
            if token in text:
                die(f"forbidden public bundle content {token!r} found in {path}")


def update_index(index_path, entry, network, chain_id, contract):
    if index_path.exists():
        index = load_json(index_path)
    else:
        index = {
            "schemaVersion": "EGOLD_PUBLIC_PROOFS_INDEX_V1",
            "network": network,
            "chainId": chain_id,
            "contractAddress": contract,
            "generatedAt": "",
            "proofs": [],
        }

    for existing in index.get("proofs", []):
        if existing.get("operationId", "").lower() == entry["operationId"].lower():
            die(f"operationId already exists in index: {entry['operationId']}")

    index["generatedAt"] = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    index.setdefault("proofs", []).append(entry)
    write_json(index_path, index)


def main():
    parser = argparse.ArgumentParser(description="Build a public EGold proof bundle.")
    parser.add_argument("--proof", required=True)
    parser.add_argument("--tx-hash", required=True)
    parser.add_argument("--operation-type", required=True, choices=["MINT", "BURN"])
    parser.add_argument("--rpc-url", required=True)
    parser.add_argument("--out-dir", default="proofs")
    parser.add_argument("--contract", required=True)
    parser.add_argument("--network", default="sepolia")
    parser.add_argument("--chain-id", type=int, default=11155111)
    args = parser.parse_args()

    if not shutil.which("cast"):
        die("cast is required to build public proof bundles")

    proof = load_json(args.proof)
    errors = validate(proof)
    if errors:
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        die("proof validation failed")

    canonical = canonical_json(proof)
    proof_hash = cast_keccak(canonical).lower()
    receipt = fetch_receipt(args.tx_hash, args.rpc_url)
    if receipt_status(receipt) != 1:
        die("transaction receipt status is not 1")

    event = decode_event(receipt, args.contract, args.operation_type)
    validate_against_event(proof, args, proof_hash, event)

    operation_id = proof["operationId"].lower()
    base_dir = Path(args.out_dir) / args.network / str(args.chain_id) / args.contract
    bundle_dir = base_dir / operation_id
    if bundle_dir.exists():
        die(f"bundle directory already exists; refusing to overwrite: {bundle_dir}")
    bundle_dir.mkdir(parents=True, exist_ok=False)

    generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    manifest = {
        "schemaVersion": "EGOLD_PUBLIC_PROOF_BUNDLE_V1",
        "network": args.network,
        "chainId": args.chain_id,
        "contractAddress": args.contract,
        "operationType": args.operation_type,
        "operationId": operation_id,
        "reserveId": proof["reserveId"].lower(),
        "proofHash": proof_hash,
        "txHash": args.tx_hash.lower(),
        "blockNumber": receipt_block_number(receipt),
        "eventName": event["eventName"],
        "operator": proof["operator"],
        "account": proof["account"],
        "amountUnits": proof["amountUnits"],
        "proofPath": "proof.json",
        "canonicalProofPath": "canonical-proof.json",
        "txReceiptPath": "tx-receipt.json",
        "onchainEventPath": "onchain-event.json",
        "generatedAt": generated_at,
        "verificationStatus": "PASSED",
        "bundleHash": "",
    }

    write_json(bundle_dir / "proof.json", proof)
    (bundle_dir / "canonical-proof.json").write_text(canonical, encoding="utf-8")
    (bundle_dir / "proof-hash.txt").write_text(proof_hash + "\n", encoding="utf-8")
    write_json(bundle_dir / "tx-receipt.json", receipt)
    write_json(bundle_dir / "onchain-event.json", event)
    write_json(bundle_dir / "manifest.json", manifest)
    (bundle_dir / "README.md").write_text(
        "# E-gold Public Proof Bundle\n\n"
        f"- Operation type: `{args.operation_type}`\n"
        f"- Operation ID: `{operation_id}`\n"
        f"- Proof hash: `{proof_hash}`\n"
        f"- Transaction: `{args.tx_hash.lower()}`\n\n"
        "Run repository verification tooling to reproduce this bundle.\n",
        encoding="utf-8",
    )

    bundle_hash = cast_keccak(bundle_hash_material(bundle_dir)).lower()
    manifest["bundleHash"] = bundle_hash
    write_json(bundle_dir / "manifest.json", manifest)
    (bundle_dir / "bundle-hash.txt").write_text(bundle_hash + "\n", encoding="utf-8")

    scan_public_output(bundle_dir)

    index_entry = {
        "operationType": args.operation_type,
        "operationId": operation_id,
        "reserveId": proof["reserveId"].lower(),
        "proofHash": proof_hash,
        "txHash": args.tx_hash.lower(),
        "blockNumber": manifest["blockNumber"],
        "amountUnits": proof["amountUnits"],
        "account": proof["account"],
        "operator": proof["operator"],
        "path": operation_id,
        "bundleHash": bundle_hash,
    }
    update_index(base_dir / "index.json", index_entry, args.network, args.chain_id, args.contract)

    print(f"PUBLIC_PROOF_BUNDLE_BUILT: {bundle_dir}")
    print(f"proofHash: {proof_hash}")
    print(f"bundleHash: {bundle_hash}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
