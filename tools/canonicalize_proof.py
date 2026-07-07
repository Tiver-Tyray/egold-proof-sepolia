#!/usr/bin/env python3
import json
import sys


def remove_proof_hash(value):
    if isinstance(value, dict):
        return {
            key: remove_proof_hash(item)
            for key, item in value.items()
            if key != "proofHash"
        }
    if isinstance(value, list):
        return [remove_proof_hash(item) for item in value]
    return value


def main():
    if len(sys.argv) != 2:
        print("usage: tools/canonicalize_proof.py <proof.json>", file=sys.stderr)
        return 2

    path = sys.argv[1]
    try:
        with open(path, "r", encoding="utf-8") as proof_file:
            payload = json.load(proof_file)
    except json.JSONDecodeError as exc:
        print(f"invalid JSON in {path}: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"could not read {path}: {exc}", file=sys.stderr)
        return 1

    canonical_payload = remove_proof_hash(payload)
    print(
        json.dumps(
            canonical_payload,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
