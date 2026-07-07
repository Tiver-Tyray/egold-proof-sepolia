#!/usr/bin/env python3
import argparse
import json
import shlex
import subprocess
import sys

from canonicalize_proof import remove_proof_hash
from validate_proof import validate


def load_proof(path):
    try:
        with open(path, "r", encoding="utf-8") as proof_file:
            payload = json.load(proof_file)
    except json.JSONDecodeError as exc:
        print(f"invalid JSON in {path}: {exc}", file=sys.stderr)
        raise SystemExit(1)
    except OSError as exc:
        print(f"could not read {path}: {exc}", file=sys.stderr)
        raise SystemExit(1)

    errors = validate(payload)
    if errors:
        print(f"invalid proof {path}", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        raise SystemExit(1)

    return payload


def canonical_json(payload):
    return json.dumps(
        remove_proof_hash(payload),
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    )


def proof_hash(payload):
    canonical = canonical_json(payload)
    try:
        result = subprocess.run(
            ["cast", "keccak", canonical],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        print("cast is not installed or not on PATH", file=sys.stderr)
        raise SystemExit(1)
    except subprocess.CalledProcessError as exc:
        print(f"cast keccak failed: {exc.stderr.strip()}", file=sys.stderr)
        raise SystemExit(1)
    return result.stdout.strip()


def nonce_from_operation_id(operation_id):
    return str(int(operation_id, 16))


def emit_export(name, value):
    print(f"export {name}={shlex.quote(str(value))}")


def emit_auth(prefix, proof):
    emit_export(f"EGOLD_{prefix}_OPERATOR", proof["operator"])
    emit_export(f"EGOLD_{prefix}_ACCOUNT", proof["account"])
    emit_export(f"EGOLD_{prefix}_AMOUNT_UNITS", proof["amountUnits"])
    emit_export(f"EGOLD_{prefix}_OPERATION_ID", proof["operationId"])
    emit_export(f"EGOLD_{prefix}_RESERVE_ID", proof["reserveId"])
    emit_export(f"EGOLD_{prefix}_PROOF_HASH", proof_hash(proof))
    emit_export(f"EGOLD_{prefix}_VALID_AFTER", proof["validAfter"])
    emit_export(f"EGOLD_{prefix}_VALID_BEFORE", proof["validBefore"])
    emit_export(f"EGOLD_{prefix}_NONCE", nonce_from_operation_id(proof["operationId"]))


def main():
    parser = argparse.ArgumentParser(description="Export EGold proof-linked authorization env vars.")
    parser.add_argument("--mint", required=True, help="mint proof path")
    parser.add_argument("--burn", required=True, help="burn proof path")
    args = parser.parse_args()

    mint = load_proof(args.mint)
    burn = load_proof(args.burn)

    if mint["operationType"] != "MINT":
        print("mint proof operationType must be MINT", file=sys.stderr)
        return 1
    if burn["operationType"] != "BURN":
        print("burn proof operationType must be BURN", file=sys.stderr)
        return 1
    if mint["operationId"] == burn["operationId"]:
        print("mint and burn operationId must differ", file=sys.stderr)
        return 1

    emit_auth("MINT", mint)
    emit_auth("BURN", burn)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
