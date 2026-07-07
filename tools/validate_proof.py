#!/usr/bin/env python3
import json
import re
import sys


ADDRESS_RE = re.compile(r"^0x[a-fA-F0-9]{40}$")
BYTES32_RE = re.compile(r"^0x[a-fA-F0-9]{64}$")
INTEGER_STRING_RE = re.compile(r"^[0-9]+$")
AMOUNT_GRAMS_RE = re.compile(r"^[0-9]+\.[0-9]{4}$")
FORBIDDEN_FIELDS = {"privatekey", "secret", "signature", "signatures", "apikey"}

REQUIRED_FIELDS = [
    "schemaVersion",
    "network",
    "chainId",
    "contractAddress",
    "tokenSymbol",
    "tokenDecimals",
    "operationType",
    "operationId",
    "reserveId",
    "proofGeneratedAt",
    "validAfter",
    "validBefore",
    "operator",
    "account",
    "amountUnits",
    "amountGrams",
    "custody",
    "vaultId",
    "custodianName",
    "jurisdiction",
    "bars",
    "totalFineGoldMilligrams",
    "audit",
    "auditReportHash",
    "reserveLedger",
    "previousLedgerRoot",
    "newLedgerRoot",
    "externalReferences",
]


def find_forbidden_fields(value, path="$"):
    errors = []
    if isinstance(value, dict):
        for key, item in value.items():
            if key.lower() in FORBIDDEN_FIELDS:
                errors.append(f"forbidden field {path}.{key}")
            errors.extend(find_forbidden_fields(item, f"{path}.{key}"))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            errors.extend(find_forbidden_fields(item, f"{path}[{index}]"))
    return errors


def require_string(payload, field, errors):
    value = payload.get(field)
    if not isinstance(value, str) or value == "":
        errors.append(f"{field} must be a non-empty string")
    return value


def validate(payload):
    errors = []

    if not isinstance(payload, dict):
        return ["proof payload must be a JSON object"]

    for field in REQUIRED_FIELDS:
        if field not in payload:
            errors.append(f"missing required field: {field}")

    errors.extend(find_forbidden_fields(payload))

    if payload.get("schemaVersion") != "EGOLD_PROOF_V1":
        errors.append("schemaVersion must be EGOLD_PROOF_V1")
    if payload.get("tokenSymbol") != "EGOLD":
        errors.append("tokenSymbol must be EGOLD")
    if payload.get("tokenDecimals") != 4:
        errors.append("tokenDecimals must be 4")
    if payload.get("operationType") not in {"MINT", "BURN"}:
        errors.append("operationType must be MINT or BURN")

    if not isinstance(payload.get("chainId"), int):
        errors.append("chainId must be an integer")
    if not isinstance(payload.get("validAfter"), int):
        errors.append("validAfter must be an integer Unix timestamp")
    if not isinstance(payload.get("validBefore"), int):
        errors.append("validBefore must be an integer Unix timestamp")
    if (
        isinstance(payload.get("validAfter"), int)
        and isinstance(payload.get("validBefore"), int)
        and payload["validBefore"] <= payload["validAfter"]
    ):
        errors.append("validBefore must be greater than validAfter")

    for field in ("contractAddress", "operator", "account"):
        value = require_string(payload, field, errors)
        if isinstance(value, str) and not ADDRESS_RE.fullmatch(value):
            errors.append(f"{field} must match ^0x[a-fA-F0-9]{{40}}$")

    for field in ("operationId", "reserveId", "auditReportHash", "previousLedgerRoot", "newLedgerRoot"):
        value = require_string(payload, field, errors)
        if isinstance(value, str) and not BYTES32_RE.fullmatch(value):
            errors.append(f"{field} must match ^0x[a-fA-F0-9]{{64}}$")

    for field in ("amountUnits", "totalFineGoldMilligrams"):
        value = require_string(payload, field, errors)
        if isinstance(value, str) and not INTEGER_STRING_RE.fullmatch(value):
            errors.append(f"{field} must be an integer string")

    amount_grams = require_string(payload, "amountGrams", errors)
    if isinstance(amount_grams, str) and not AMOUNT_GRAMS_RE.fullmatch(amount_grams):
        errors.append("amountGrams must be a string with exactly four decimal places")

    for field in ("custody", "audit", "reserveLedger"):
        if not isinstance(payload.get(field), dict):
            errors.append(f"{field} must be an object")

    if not isinstance(payload.get("bars"), list) or not payload.get("bars"):
        errors.append("bars must be a non-empty array")
    if not isinstance(payload.get("externalReferences"), list):
        errors.append("externalReferences must be an array")

    return errors


def main():
    if len(sys.argv) != 2:
        print("usage: tools/validate_proof.py <proof.json>", file=sys.stderr)
        return 2

    path = sys.argv[1]
    try:
        with open(path, "r", encoding="utf-8") as proof_file:
            payload = json.load(proof_file)
    except json.JSONDecodeError as exc:
        print(f"INVALID: invalid JSON in {path}: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"INVALID: could not read {path}: {exc}", file=sys.stderr)
        return 1

    errors = validate(payload)
    if errors:
        print("INVALID", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
