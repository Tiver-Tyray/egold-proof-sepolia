#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from pathlib import Path


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
    except subprocess.CalledProcessError as exc:
        die(f"{' '.join(redact_args(args))} failed: {exc.stderr.strip()}")


def main():
    parser = argparse.ArgumentParser(description="Verify an EGold public proofs index.")
    parser.add_argument("--index", required=True)
    parser.add_argument("--rpc-url", default="")
    args = parser.parse_args()

    index_path = Path(args.index)
    if not index_path.exists():
        die(f"missing index: {index_path}")
    index = json.loads(index_path.read_text(encoding="utf-8"))
    base_dir = index_path.parent

    for entry in index.get("proofs", []):
        bundle_dir = base_dir / entry["path"]
        command = ["python3", "tools/verify_public_proof_bundle.py", "--bundle", str(bundle_dir)]
        if args.rpc_url:
            command.extend(["--rpc-url", args.rpc_url])
        print(run(command))

    print("PUBLIC_PROOFS_INDEX_VALID")
    print(f"index: {index_path}")
    print(f"proof count: {len(index.get('proofs', []))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
