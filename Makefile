-include .env
export

PUBLIC_PROOF_NETWORK ?= sepolia
PUBLIC_PROOF_CHAIN_ID ?= 11155111
PUBLIC_PROOF_CONTRACT ?= 0x99E3Eb7aFA17eaed346F8F7a4524529049aB5Dd9
PUBLIC_PROOF_INDEX ?= proofs/$(PUBLIC_PROOF_NETWORK)/$(PUBLIC_PROOF_CHAIN_ID)/$(PUBLIC_PROOF_CONTRACT)/index.json

.PHONY: test test-ci fmt gas snapshot coverage slither audit print-config constructor-args deploy-dry deploy-testnet deploy-testnet-no-verify post-deploy-check smoke-local-dry smoke-local rehearsal-local validate-proof-examples proof-hash-mint proof-hash-burn proof-check proof-linked-smoke-dry proof-linked-smoke public-proof-bundle-latest verify-public-proofs verify-public-proofs-offline public-proof-check print-public-proof-config build-public-site verify-public-site secret-scan-public public-site-check publication-check

test:
	forge test -vvv

test-ci:
	FOUNDRY_PROFILE=ci forge test -vvv

fmt:
	forge fmt

gas:
	forge test --gas-report

snapshot:
	forge snapshot

coverage:
	forge coverage

slither:
	slither . --config-file slither.config.json

audit:
	forge fmt
	forge test -vvv
	forge test --gas-report
	forge snapshot
	forge coverage
	slither . --config-file slither.config.json

print-config:
	forge script script/PrintEGoldDeploymentConfig.s.sol --rpc-url $(RPC_URL)

constructor-args:
	forge script script/EncodeEGoldConstructorArgs.s.sol --rpc-url $(RPC_URL)

deploy-dry:
	forge script script/DeployEGold.s.sol --rpc-url $(RPC_URL) -vvvv

deploy-testnet:
	forge script script/DeployEGold.s.sol --rpc-url $(RPC_URL) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-testnet-no-verify:
	forge script script/DeployEGold.s.sol --rpc-url $(RPC_URL) --broadcast -vvvv

post-deploy-check:
	forge script script/PostDeployCheckEGold.s.sol --rpc-url $(RPC_URL) -vvvv

smoke-local-dry:
	forge script script/SmokeTestEGoldLocal.s.sol --rpc-url $(RPC_URL) -vvvv

smoke-local:
	forge script script/SmokeTestEGoldLocal.s.sol --rpc-url $(RPC_URL) --broadcast -vvvv

rehearsal-local:
	$(MAKE) test
	$(MAKE) test-ci
	$(MAKE) post-deploy-check
	$(MAKE) smoke-local-dry
	$(MAKE) smoke-local

validate-proof-examples:
	python3 tools/validate_proof.py examples/proofs/mint-proof-v1.example.json
	python3 tools/validate_proof.py examples/proofs/burn-proof-v1.example.json

proof-hash-mint:
	bash tools/hash_proof.sh examples/proofs/mint-proof-v1.example.json

proof-hash-burn:
	bash tools/hash_proof.sh examples/proofs/burn-proof-v1.example.json

proof-check:
	$(MAKE) validate-proof-examples
	$(MAKE) proof-hash-mint
	$(MAKE) proof-hash-burn

proof-linked-smoke-dry:
	bash tools/run_proof_linked_smoke.sh dry

proof-linked-smoke:
	bash tools/run_proof_linked_smoke.sh broadcast

public-proof-bundle-latest:
	@test -n "$(RPC_URL)" || (echo "RPC_URL is required for public-proof-bundle-latest"; exit 1)
	@python3 tools/build_public_bundles_from_latest_smoke.py --rpc-url "$(RPC_URL)" --contract "$(PUBLIC_PROOF_CONTRACT)" --network "$(PUBLIC_PROOF_NETWORK)" --chain-id "$(PUBLIC_PROOF_CHAIN_ID)"

verify-public-proofs:
	@test -n "$(RPC_URL)" || (echo "RPC_URL is required for verify-public-proofs"; exit 1)
	@python3 tools/verify_public_proofs_index.py --index $(PUBLIC_PROOF_INDEX) --rpc-url "$(RPC_URL)"

verify-public-proofs-offline:
	@python3 tools/verify_public_proofs_index.py --index $(PUBLIC_PROOF_INDEX)

public-proof-check:
	$(MAKE) public-proof-bundle-latest
	$(MAKE) verify-public-proofs
	$(MAKE) verify-public-proofs-offline

print-public-proof-config:
	@echo PUBLIC_PROOF_NETWORK=$(PUBLIC_PROOF_NETWORK)
	@echo PUBLIC_PROOF_CHAIN_ID=$(PUBLIC_PROOF_CHAIN_ID)
	@echo PUBLIC_PROOF_CONTRACT=$(PUBLIC_PROOF_CONTRACT)
	@echo PUBLIC_PROOF_INDEX=$(PUBLIC_PROOF_INDEX)
	@test -f "$(PUBLIC_PROOF_INDEX)"

build-public-site:
	python3 tools/build_public_site.py

verify-public-site:
	python3 tools/verify_public_site.py

secret-scan-public:
	python3 tools/secret_scan_public.py docs
	python3 tools/secret_scan_public.py proofs

public-site-check:
	$(MAKE) build-public-site
	$(MAKE) verify-public-site
	$(MAKE) secret-scan-public

publication-check:
	$(MAKE) test
	$(MAKE) test-ci
	$(MAKE) proof-check
	$(MAKE) verify-public-proofs-offline
	$(MAKE) public-site-check
