# E-gold Incident and Migration Policy

## Scope

The EGold contract is immutable. It has no owner, no admin, no pause, no freeze, no blacklist, no proxy, no upgradeability path, and no forced transfer mechanism. This is intentional, but it means there is no admin rescue path after deployment.

Incidents must be handled by transparent off-chain operations and, if needed, voluntary migration to a newly deployed contract.

## Incident Response Principles

Because the contract is immutable, incident handling relies on:

- public disclosure
- stopping minter operations off-chain
- refusing further attester signatures
- publishing an incident root
- preserving evidence
- coordinating with custodians and auditors
- optional migration to a new contract

The response process must not imply that an admin can freeze users, seize balances, or patch the deployed contract.

## Key Compromise Scenarios

### Minter Key Compromised

- Immediately disclose the suspected compromise.
- Stop all minter operations off-chain.
- Ask attesters to refuse signatures for the compromised minter.
- Publish the last known valid ledger root.
- Publish an incident root that commits to all affected operations.
- Evaluate voluntary migration to a new contract with a new minter set.

### One Attester Key Compromised

- Immediately disclose the suspected compromise.
- Require remaining attesters to refuse suspicious operations.
- Review all recent signatures from the compromised attester.
- Publish an incident root and affected operation list.
- Because this contract cannot rotate keys, evaluate whether threshold safety remains acceptable.

### Threshold Attester Compromise

- Immediately stop minter operations.
- Publish an emergency disclosure.
- Treat all future signatures from the compromised threshold as unsafe.
- Publish the last trusted reserve ledger root.
- Prepare voluntary migration to a new contract with a new independent attester set.

### Custodian or Audit Compromise

- Stop attester signing for affected reserves.
- Publish affected `reserveId` values.
- Obtain independent custody and audit review.
- Publish updated reserve ledger roots and audit findings.
- Do not resume minting until independent review is complete.

### Ledger Corruption

- Stop minter operations and attester signing.
- Publish the last accepted ledger root.
- Publish the corrupted root and affected entries.
- Append corrective ledger entries rather than editing history.
- Resume only after public reconciliation and attester approval.

## Migration Without Admin Backdoors

If migration is required:

1. Deploy a new immutable EGold contract with a new minter and attester set.
2. Publish constructor args, runtime codehash, source verification, and deployment artifacts.
3. Publish a public snapshot of balances, reserve ledger roots, and incident state.
4. Publish the migration rules before any user action.
5. Support voluntary user migration through burn, redeem, or migrate procedures.
6. Preserve old contract history and artifacts indefinitely.

Users cannot be forced to migrate by an admin key because no such key exists. This is a direct consequence of immutable sovereignty.

## Immutable Sovereignty Tradeoff

The same design that prevents owner abuse, freezing, blacklisting, and forced transfers also prevents on-chain key rotation and emergency repair. Operational security must therefore be strong before production deployment.
