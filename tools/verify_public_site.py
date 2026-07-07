#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from pathlib import Path


DOCS_DIR = Path("docs")


def die(message):
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def run(args):
    try:
        return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()
    except subprocess.CalledProcessError as exc:
        die(f"{' '.join(args)} failed: {exc.stderr.strip()}")


def load_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        die(f"invalid JSON in {path}: {exc}")
    except OSError as exc:
        die(f"could not read {path}: {exc}")


def main():
    parser = argparse.ArgumentParser(description="Verify the static EGold public proof site.")
    parser.parse_args()

    index_html = DOCS_DIR / "index.html"
    manifest_path = DOCS_DIR / "verification-manifest.json"
    if not index_html.exists():
        die("missing docs/index.html")
    if not manifest_path.exists():
        die("missing docs/verification-manifest.json")

    manifest = load_json(manifest_path)
    proof_index_path = DOCS_DIR / manifest["publicProofIndexPath"]
    if not proof_index_path.exists():
        die(f"missing public proof index: {proof_index_path}")

    proof_index = load_json(proof_index_path)
    by_operation = {entry["operationId"].lower(): entry for entry in proof_index.get("proofs", [])}

    for bundle in manifest.get("proofBundles", []):
        operation_id = bundle["operationId"].lower()
        if operation_id not in by_operation:
            die(f"manifest bundle missing from proof index: {operation_id}")

        index_entry = by_operation[operation_id]
        if bundle["proofHash"].lower() != index_entry["proofHash"].lower():
            die(f"proofHash mismatch for {operation_id}")
        if bundle["bundleHash"].lower() != index_entry["bundleHash"].lower():
            die(f"bundleHash mismatch for {operation_id}")

        bundle_path = DOCS_DIR / bundle["bundlePath"]
        if not bundle_path.exists():
            die(f"missing bundle path: {bundle_path}")
        if not (bundle_path / "README.md").exists():
            die(f"missing bundle README: {bundle_path}")

    run(["python3", "tools/verify_public_proofs_index.py", "--index", str(proof_index_path)])
    run(["python3", "tools/secret_scan_public.py", "docs"])
    print("PUBLIC_SITE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
