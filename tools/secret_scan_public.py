#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path


FORBIDDEN_HEX = {
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
    "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",
    "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6",
    "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba",
}

FORBIDDEN_PATTERNS = [
    re.compile(r"\bprivateKey\b", re.IGNORECASE),
    re.compile(r"\bPRIVATE_KEY\b"),
    re.compile(r"\bETHERSCAN_API_KEY\b"),
    re.compile(r"\bapiKey\b", re.IGNORECASE),
    re.compile(r"(?i)(^|[^a-z0-9_])secret([^a-z0-9_]|$)"),
    re.compile(r"\bmnemonic\b", re.IGNORECASE),
    re.compile(r"\bseed phrase\b", re.IGNORECASE),
]

SKIP_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".ico", ".pdf"}


def scan_file(path):
    lowered_path = str(path).lower()
    if "/.git/" in lowered_path or path.suffix.lower() in SKIP_SUFFIXES:
        return []

    text = path.read_text(encoding="utf-8", errors="ignore")
    lowered = text.lower()
    findings = []

    for value in FORBIDDEN_HEX:
        if value in lowered:
            findings.append(f"forbidden known test/private key value in {path}")

    for pattern in FORBIDDEN_PATTERNS:
        if pattern.search(text):
            findings.append(f"forbidden sensitive token matching {pattern.pattern!r} in {path}")

    return findings


def main():
    parser = argparse.ArgumentParser(description="Scan public output for sensitive material.")
    parser.add_argument("path")
    args = parser.parse_args()

    root = Path(args.path)
    if not root.exists():
        print(f"error: path does not exist: {root}", file=sys.stderr)
        return 1

    findings = []
    for path in root.rglob("*"):
        if path.is_file():
            findings.extend(scan_file(path))

    if findings:
        print("PUBLIC_SECRET_SCAN_FAILED", file=sys.stderr)
        for finding in findings:
            print(f"- {finding}", file=sys.stderr)
        return 1

    print("PUBLIC_SECRET_SCAN_PASSED")
    print(f"path: {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
