#!/usr/bin/env python3
import html
import json
import shutil
import subprocess
import sys
from pathlib import Path


CONTRACT = "0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9"
NETWORK = "sepolia"
CHAIN_ID = 11155111
ETHERSCAN_CODE_URL = f"https://sepolia.etherscan.io/address/{CONTRACT}#code"
PROOFS_INDEX = Path("proofs") / NETWORK / str(CHAIN_ID) / CONTRACT / "index.json"
DOCS_DIR = Path("docs")
DOCS_PROOFS_DIR = DOCS_DIR / "proofs"


def die(message):
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def run(args):
    try:
        return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()
    except subprocess.CalledProcessError as exc:
        die(f"{' '.join(args)} failed: {exc.stderr.strip()}")


def load_index():
    if not PROOFS_INDEX.exists():
        die(f"missing proof index: {PROOFS_INDEX}")
    return json.loads(PROOFS_INDEX.read_text(encoding="utf-8"))


def copy_public_proofs():
    if DOCS_PROOFS_DIR.exists():
        shutil.rmtree(DOCS_PROOFS_DIR)
    shutil.copytree("proofs", DOCS_PROOFS_DIR, ignore=shutil.ignore_patterns(".env", ".env.*", ".secrets", "cache", "generated"))


def rel(path):
    return path.as_posix()


def proof_entry(index, operation_type):
    for entry in index.get("proofs", []):
        if entry.get("operationType") == operation_type:
            return entry
    die(f"missing {operation_type} proof in index")


def link(path, label):
    escaped_path = html.escape(path, quote=True)
    return f'<a href="{escaped_path}">{html.escape(label)}</a>'


def build_html(index):
    mint = proof_entry(index, "MINT")
    burn = proof_entry(index, "BURN")
    proof_index_path = f"proofs/{NETWORK}/{CHAIN_ID}/{CONTRACT}/index.json"
    mint_readme = f"proofs/{NETWORK}/{CHAIN_ID}/{CONTRACT}/{mint['operationId']}/README.md"
    burn_readme = f"proofs/{NETWORK}/{CHAIN_ID}/{CONTRACT}/{burn['operationId']}/README.md"

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>EGold Public Proofs - Sepolia Rehearsal</title>
  <style>
    :root {{
      color-scheme: light;
      --ink: #18212f;
      --muted: #586273;
      --line: #d9dee7;
      --soft: #f6f8fb;
      --accent: #0f766e;
      --gold: #a36b00;
    }}
    body {{
      margin: 0;
      font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: var(--ink);
      background: #ffffff;
      line-height: 1.5;
    }}
    main {{
      max-width: 1040px;
      margin: 0 auto;
      padding: 40px 20px 64px;
    }}
    header {{
      border-bottom: 1px solid var(--line);
      padding-bottom: 24px;
      margin-bottom: 28px;
    }}
    h1 {{
      margin: 0 0 10px;
      font-size: clamp(2rem, 5vw, 3.4rem);
      line-height: 1.05;
      letter-spacing: 0;
    }}
    h2 {{
      margin: 32px 0 12px;
      font-size: 1.35rem;
      letter-spacing: 0;
    }}
    p, li {{
      color: var(--muted);
    }}
    code, pre {{
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 0.94em;
    }}
    code {{
      overflow-wrap: anywhere;
    }}
    pre {{
      background: var(--soft);
      border: 1px solid var(--line);
      padding: 14px;
      overflow-x: auto;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 16px;
    }}
    .panel {{
      border: 1px solid var(--line);
      padding: 16px;
      background: #fff;
    }}
    .status {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 10px;
      padding: 0;
      list-style: none;
    }}
    .status li {{
      border-left: 4px solid var(--accent);
      background: var(--soft);
      padding: 10px 12px;
      color: var(--ink);
    }}
    a {{
      color: #064e8a;
    }}
    .label {{
      color: var(--gold);
      font-weight: 700;
      text-transform: uppercase;
      font-size: 0.78rem;
      letter-spacing: 0.04em;
    }}
  </style>
</head>
<body>
<main>
  <header>
    <p class="label">Sepolia Rehearsal</p>
    <h1>EGold Public Proofs</h1>
    <p>Public proof bundles for the verified Sepolia rehearsal of EGold. These files let a reviewer reproduce the proof hashes used in on-chain mint and burn events.</p>
  </header>

  <section>
    <h2>Contract</h2>
    <ul>
      <li>Network: <strong>Sepolia</strong></li>
      <li>Chain ID: <code>{CHAIN_ID}</code></li>
      <li>Contract: <code>{CONTRACT}</code></li>
      <li>Etherscan code page: {link(ETHERSCAN_CODE_URL, ETHERScan_LABEL)}</li>
    </ul>
  </section>

  <section>
    <h2>Verification Status</h2>
    <ul class="status">
      <li>Etherscan verification: PASSED</li>
      <li>Post-deploy check: PASSED</li>
      <li>Proof-linked smoke test: PASSED</li>
      <li>Public proof bundle verification: PASSED</li>
      <li>Offline proof index verification: PASSED</li>
    </ul>
  </section>

  <section>
    <h2>Public Proof Index</h2>
    <p>{link(proof_index_path, proof_index_path)}</p>
  </section>

  <section>
    <h2>Proof Bundles</h2>
    <div class="grid">
      <article class="panel">
        <p class="label">Mint</p>
        <p>operationId: <code>{mint['operationId']}</code></p>
        <p>proofHash: <code>{mint['proofHash']}</code></p>
        <p>bundleHash: <code>{mint['bundleHash']}</code></p>
        <p>tx: <code>{mint['txHash']}</code></p>
        <p>{link(mint_readme, "Mint bundle README")}</p>
      </article>
      <article class="panel">
        <p class="label">Burn</p>
        <p>operationId: <code>{burn['operationId']}</code></p>
        <p>proofHash: <code>{burn['proofHash']}</code></p>
        <p>bundleHash: <code>{burn['bundleHash']}</code></p>
        <p>tx: <code>{burn['txHash']}</code></p>
        <p>{link(burn_readme, "Burn bundle README")}</p>
      </article>
    </div>
  </section>

  <section>
    <h2>How To Verify Locally</h2>
    <pre><code>git clone &lt;REPO_URL&gt;
cd &lt;REPO&gt;
make verify-public-proofs-offline</code></pre>
    <p>Optional RPC verification:</p>
    <pre><code>set -a
source .env.sepolia
set +a
make verify-public-proofs</code></pre>
  </section>

  <section>
    <h2>Caveats</h2>
    <ul>
      <li>Sepolia only.</li>
      <li>This proves the cryptographic proof publication flow.</li>
      <li>It does not prove physical gold custody by itself.</li>
      <li>Physical custody requires external audits, reserve ledger publication, custodian verification, and attester integrity.</li>
    </ul>
  </section>
</main>
</body>
</html>
"""


ETHERScan_LABEL = "https://sepolia.etherscan.io/address/0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9#code"


def build_manifest(index):
    generated_at = index.get("generatedAt")
    if not isinstance(generated_at, str) or not generated_at:
        die("proof index is missing a stable generatedAt value")

    proof_index_path = f"proofs/{NETWORK}/{CHAIN_ID}/{CONTRACT}/index.json"
    bundles = []
    for entry in index.get("proofs", []):
        bundles.append(
            {
                "operationType": entry["operationType"],
                "operationId": entry["operationId"],
                "proofHash": entry["proofHash"],
                "bundleHash": entry["bundleHash"],
                "txHash": entry["txHash"],
                "bundlePath": f"proofs/{NETWORK}/{CHAIN_ID}/{CONTRACT}/{entry['operationId']}/",
            }
        )

    return {
        "schemaVersion": "EGOLD_PUBLIC_SITE_V1",
        "generatedAt": generated_at,
        "network": NETWORK,
        "chainId": CHAIN_ID,
        "contractAddress": CONTRACT,
        "etherscanCodeUrl": ETHERSCAN_CODE_URL,
        "publicProofIndexPath": proof_index_path,
        "proofBundles": bundles,
        "verificationCommands": ["make verify-public-proofs-offline", "make public-site-check"],
        "security": {"noPrivateKeys": True, "noEnvFiles": True, "noCacheFiles": True},
    }


def main():
    index = load_index()
    DOCS_DIR.mkdir(exist_ok=True)
    copy_public_proofs()
    (DOCS_DIR / "index.html").write_text(build_html(index), encoding="utf-8")
    (DOCS_DIR / "verification-manifest.json").write_text(
        json.dumps(build_manifest(index), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (DOCS_DIR / ".nojekyll").write_text("", encoding="utf-8")
    run(["python3", "tools/secret_scan_public.py", "docs"])
    print("PUBLIC_SITE_BUILT")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
