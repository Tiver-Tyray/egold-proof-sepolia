# E-gold Local Rehearsal Checkpoint

## Rehearsal Summary

- Rehearsal date/time: 2026-07-06 21:21:17 CEST (UTC+02:00).
- Network: local Anvil.
- Chain ID: 31337.
- Contract address: `0x5FbDB2315678afecb367f032d93F642f64180aa3`.
- Runtime codehash: `0xddc87b14a4ff500e9e88625db49541baaea9c63a5c353c2cc9b08a97941107df`.
- Minter: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`.
- Attester 1: `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`.
- Attester 2: `0x90F79bf6EB2c4f870365E785982E1f101E93b906`.
- Attester 3: `0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65`.
- Threshold: 2.
- Smoke user: `0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc`.
- Mint amount: 10000.
- Burn amount: 4000.
- Final balance: 6000.
- Final `totalSupply`: 6000.

Artifacts:

- Smoke test log: `audit-results/local-smoke-test.txt`.
- Broadcast artifact: `broadcast/SmokeTestEGoldLocal.s.sol/31337/run-latest.json`.

## Proven Locally

1. EGold is deployable.
2. Constructor args work.
3. Metadata is correct.
4. `decimals == 4`.
5. `attestationThreshold == 2`.
6. `attesterCount == 3`.
7. The minter role is assigned correctly.
8. Reserve attester roles are assigned correctly.
9. `DEFAULT_ADMIN_ROLE` remains empty.
10. Mint works with threshold attestations.
11. Burn works with threshold attestations.
12. Burning another account's balance requires allowance.
13. `operationUsed` is set after mint and burn.
14. `authorizationUsed` is set after mint and burn.
15. `totalSupply` changes correctly after mint and burn.

## Boundary

This was only a local Anvil rehearsal. Anvil state disappears when Anvil stops. The Anvil private keys are publicly known test keys and must never be used on mainnet or real public testnets.

This rehearsal proves the smart-contract deployment and transaction flow. It does not prove physical gold backing. Physical gold backing remains dependent on custody, reserve audits, proofHash publication, and attester integrity.
