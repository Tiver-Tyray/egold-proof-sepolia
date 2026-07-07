#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import json
import os
import secrets
import sys
from pathlib import Path


MINT_AMOUNT_UNITS = "10000"
MINT_AMOUNT_GRAMS = "1.0000"
BURN_AMOUNT_UNITS = "4000"
BURN_AMOUNT_GRAMS = "0.4000"


def bytes32_from_text(value):
    return "0x" + hashlib.sha256(value.encode("utf-8")).hexdigest()


def fresh_bytes32():
    return "0x" + secrets.token_hex(32)


def require_env(name):
    value = os.environ.get(name, "").strip()
    if not value:
        print(f"missing required env var: {name}", file=sys.stderr)
        raise SystemExit(1)
    return value


def proof_base(now, chain_id, contract_address, minter, smoke_user, reserve_id):
    unix_now = int(now.timestamp())
    generated_at = now.replace(microsecond=0).isoformat().replace("+00:00", "Z")
    run_ref = now.strftime("%Y%m%dT%H%M%SZ")

    return {
        "schemaVersion": "EGOLD_PROOF_V1",
        "network": "sepolia",
        "chainId": chain_id,
        "contractAddress": contract_address,
        "tokenSymbol": "EGOLD",
        "tokenDecimals": 4,
        "reserveId": reserve_id,
        "proofGeneratedAt": generated_at,
        "validAfter": unix_now - 60,
        "validBefore": unix_now + 86400,
        "operator": minter,
        "account": smoke_user,
        "custody": {
            "vaultId": "SEPOLIA-PROOF-LINKED-SMOKE-VAULT",
            "custodianName": "Example Independent Vault Ltd",
            "jurisdiction": "CH-ZG",
            "barSetId": f"EGOLD-SMOKE-BARSET-{run_ref}",
            "custodyReceiptRef": f"SMOKE-CUSTODY-{run_ref}",
        },
        "vaultId": "SEPOLIA-PROOF-LINKED-SMOKE-VAULT",
        "custodianName": "Example Independent Vault Ltd",
        "jurisdiction": "CH-ZG",
        "audit": {
            "auditorName": "Example Reserve Auditor LLP",
            "auditReportRef": f"SMOKE-AUDIT-{run_ref}",
            "auditReportUri": f"ipfs://egold-smoke-audit-{run_ref.lower()}",
        },
        "reserveLedger": {
            "ledgerId": "EGOLD-SEPOLIA-PROOF-LINKED-SMOKE",
            "runRef": run_ref,
        },
        "externalReferences": [
            f"ipfs://egold-smoke-proof-{run_ref.lower()}",
            f"https://example.invalid/egold/smoke/{run_ref}",
        ],
    }


def build_mint_proof(base, run_ref):
    proof = dict(base)
    proof.update(
        {
            "operationType": "MINT",
            "operationId": fresh_bytes32(),
            "amountUnits": MINT_AMOUNT_UNITS,
            "amountGrams": MINT_AMOUNT_GRAMS,
            "bars": [
                {
                    "barId": f"SMOKE-MINT-BAR-{run_ref}",
                    "barSerialHash": bytes32_from_text(f"SMOKE:MINT:BAR:{run_ref}"),
                    "refinery": "Example Refinery",
                    "finenessPpm": 9999,
                    "grossMassMilligrams": "1000",
                    "fineGoldMilligrams": "1000",
                }
            ],
            "totalFineGoldMilligrams": "1000",
            "auditReportHash": bytes32_from_text(f"SMOKE:MINT:AUDIT:{run_ref}"),
            "previousLedgerRoot": bytes32_from_text(f"SMOKE:MINT:PREVIOUS_LEDGER:{run_ref}"),
            "newLedgerRoot": bytes32_from_text(f"SMOKE:MINT:NEW_LEDGER:{run_ref}"),
        }
    )
    proof["audit"]["auditReportHash"] = proof["auditReportHash"]
    proof["reserveLedger"].update(
        {
            "entryType": "MINT",
            "entryRef": f"SMOKE-LEDGER-MINT-{run_ref}",
            "previousLedgerRoot": proof["previousLedgerRoot"],
            "newLedgerRoot": proof["newLedgerRoot"],
        }
    )
    return proof


def build_burn_proof(base, run_ref):
    proof = dict(base)
    proof.update(
        {
            "operationType": "BURN",
            "operationId": fresh_bytes32(),
            "amountUnits": BURN_AMOUNT_UNITS,
            "amountGrams": BURN_AMOUNT_GRAMS,
            "bars": [
                {
                    "barId": f"SMOKE-BURN-BAR-{run_ref}",
                    "barSerialHash": bytes32_from_text(f"SMOKE:BURN:BAR:{run_ref}"),
                    "refinery": "Example Refinery",
                    "finenessPpm": 9999,
                    "grossMassMilligrams": "400",
                    "fineGoldMilligrams": "400",
                }
            ],
            "totalFineGoldMilligrams": "400",
            "auditReportHash": bytes32_from_text(f"SMOKE:BURN:AUDIT:{run_ref}"),
            "previousLedgerRoot": bytes32_from_text(f"SMOKE:BURN:PREVIOUS_LEDGER:{run_ref}"),
            "newLedgerRoot": bytes32_from_text(f"SMOKE:BURN:NEW_LEDGER:{run_ref}"),
        }
    )
    proof["audit"]["auditReportHash"] = proof["auditReportHash"]
    proof["reserveLedger"].update(
        {
            "entryType": "BURN",
            "entryRef": f"SMOKE-LEDGER-BURN-{run_ref}",
            "previousLedgerRoot": proof["previousLedgerRoot"],
            "newLedgerRoot": proof["newLedgerRoot"],
        }
    )
    return proof


def write_json(path, payload):
    with path.open("w", encoding="utf-8") as proof_file:
        json.dump(payload, proof_file, indent=2, sort_keys=False)
        proof_file.write("\n")


def main():
    parser = argparse.ArgumentParser(description="Create fresh EGold proof-linked smoke proof payloads.")
    parser.add_argument("--chain-id", type=int, default=int(os.environ.get("CHAIN_ID", "11155111")))
    parser.add_argument("--out-dir", default=None)
    args = parser.parse_args()

    contract_address = require_env("EGOLD_ADDRESS")
    minter = require_env("EGOLD_MINTER")
    smoke_user = require_env("EGOLD_SMOKE_USER")
    require_env("EGOLD_THRESHOLD")

    now = dt.datetime.now(dt.timezone.utc)
    run_ref = now.strftime("%Y%m%dT%H%M%SZ")
    out_dir = Path(args.out_dir) if args.out_dir else Path("generated") / "proofs" / run_ref
    out_dir.mkdir(parents=True, exist_ok=True)

    reserve_id = bytes32_from_text(
        f"EGOLD:SMOKE:RESERVE:V1:{args.chain_id}:{contract_address}:{minter}:{smoke_user}:{run_ref}"
    )
    base = proof_base(now, args.chain_id, contract_address, minter, smoke_user, reserve_id)
    mint_proof = build_mint_proof(base, run_ref)
    burn_proof = build_burn_proof(base, run_ref)

    if mint_proof["operationId"] == burn_proof["operationId"]:
        print("generated mint and burn operationId collision", file=sys.stderr)
        return 1

    mint_path = out_dir / "mint-proof.json"
    burn_path = out_dir / "burn-proof.json"
    write_json(mint_path, mint_proof)
    write_json(burn_path, burn_proof)

    print(f"MINT_PROOF_PATH={mint_path}")
    print(f"BURN_PROOF_PATH={burn_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
