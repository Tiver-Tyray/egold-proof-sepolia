// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Script.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EGold} from "../src/EGold.sol";
import {EGoldDeploymentBase} from "./EGoldDeploymentBase.s.sol";

contract ProofLinkedSmokeTestEGold is EGoldDeploymentBase {
    uint256 private constant SEPOLIA_CHAIN_ID = 11_155_111;
    uint256 private constant PROOF_LINKED_THRESHOLD = 2;
    uint256 private constant MINT_AMOUNT = 10_000;
    uint256 private constant BURN_AMOUNT = 4_000;

    struct SmokeKeys {
        uint256 minterPrivateKey;
        uint256 attester1PrivateKey;
        uint256 attester2PrivateKey;
        uint256 smokeUserPrivateKey;
    }

    struct ProofAuth {
        address operator;
        address account;
        uint256 amount;
        bytes32 operationId;
        bytes32 reserveId;
        bytes32 proofHash;
        uint256 validAfter;
        uint256 validBefore;
        uint256 nonce;
    }

    struct ProofLinkedEnv {
        address smokeUser;
        ProofAuth mint;
        ProofAuth burn;
    }

    struct SmokeState {
        uint256 balanceBefore;
        uint256 supplyBefore;
        bytes32 mintDigest;
        bytes32 burnDigest;
    }

    error InvalidProofLinkedPrivateKey(string envVar, address expected, address actual);
    error ProofLinkedRequiresSepolia(uint256 actualChainId);
    error ProofLinkedRequiresThresholdTwo(uint256 threshold);
    error ProofLinkedSmokeCheckFailed(string check);

    function run() external {
        if (block.chainid != SEPOLIA_CHAIN_ID) revert ProofLinkedRequiresSepolia(block.chainid);

        DeploymentConfig memory config = _loadDeploymentConfig();
        if (config.threshold != PROOF_LINKED_THRESHOLD) revert ProofLinkedRequiresThresholdTwo(config.threshold);

        EGold token = EGold(_loadEGoldAddress());
        SmokeKeys memory keys = _loadSmokeKeys();
        ProofLinkedEnv memory proofEnv = _loadProofLinkedEnv();

        _checkPrivateKey("EGOLD_MINTER_PRIVATE_KEY", keys.minterPrivateKey, config.minter);
        _checkPrivateKey("EGOLD_ATTESTER_1_PRIVATE_KEY", keys.attester1PrivateKey, config.attester1);
        _checkPrivateKey("EGOLD_ATTESTER_2_PRIVATE_KEY", keys.attester2PrivateKey, config.attester2);
        _checkPrivateKey("EGOLD_SMOKE_USER_PRIVATE_KEY", keys.smokeUserPrivateKey, proofEnv.smokeUser);

        _requireEq(proofEnv.mint.operator, config.minter, "MINT_OPERATOR_IS_MINTER");
        _requireEq(proofEnv.mint.account, proofEnv.smokeUser, "MINT_ACCOUNT_IS_SMOKE_USER");
        _requireEq(proofEnv.burn.operator, config.minter, "BURN_OPERATOR_IS_MINTER");
        _requireEq(proofEnv.burn.account, proofEnv.smokeUser, "BURN_ACCOUNT_IS_SMOKE_USER");
        _requireEq(proofEnv.mint.amount, MINT_AMOUNT, "MINT_AMOUNT");
        _requireEq(proofEnv.burn.amount, BURN_AMOUNT, "BURN_AMOUNT");
        _requireTrue(proofEnv.mint.operationId != proofEnv.burn.operationId, "OPERATION_IDS_DIFFER");

        bool preflightPassed = _runPostDeployChecks(token, config);
        if (!preflightPassed) revert PostDeployCheckFailed();

        SmokeState memory state;
        state.balanceBefore = token.balanceOf(proofEnv.smokeUser);
        state.supplyBefore = token.totalSupply();

        _runMintSmoke(token, keys, proofEnv, state);
        _runBurnSmoke(token, keys, proofEnv, state);

        uint256 finalBalance = token.balanceOf(proofEnv.smokeUser);
        uint256 finalSupply = token.totalSupply();

        _requireEq(finalBalance, state.balanceBefore + MINT_AMOUNT - BURN_AMOUNT, "FINAL_BALANCE_NET_DELTA");
        _requireEq(finalSupply, state.supplyBefore + MINT_AMOUNT - BURN_AMOUNT, "FINAL_SUPPLY_NET_DELTA");

        console2.log("PROOF_LINKED_SMOKE_STATUS: PASSED");
        console2.log("contract address:", address(token));
        console2.log("chainid:", block.chainid);
        console2.log("mint proofHash:", vm.toString(proofEnv.mint.proofHash));
        console2.log("burn proofHash:", vm.toString(proofEnv.burn.proofHash));
        console2.log("mint operationId:", vm.toString(proofEnv.mint.operationId));
        console2.log("burn operationId:", vm.toString(proofEnv.burn.operationId));
        console2.log("start balance:", state.balanceBefore);
        console2.log("final balance:", finalBalance);
        console2.log("start totalSupply:", state.supplyBefore);
        console2.log("final totalSupply:", finalSupply);
    }

    function _runMintSmoke(EGold token, SmokeKeys memory keys, ProofLinkedEnv memory proofEnv, SmokeState memory state)
        private
    {
        EGold.MintAuthorization memory auth = EGold.MintAuthorization({
            operator: proofEnv.mint.operator,
            to: proofEnv.mint.account,
            amount: proofEnv.mint.amount,
            operationId: proofEnv.mint.operationId,
            reserveId: proofEnv.mint.reserveId,
            proofHash: proofEnv.mint.proofHash,
            validAfter: proofEnv.mint.validAfter,
            validBefore: proofEnv.mint.validBefore,
            nonce: proofEnv.mint.nonce
        });

        state.mintDigest = token.hashMintAuthorization(auth);
        bytes[] memory signatures =
            _sortTwoSignatures(keys.attester1PrivateKey, keys.attester2PrivateKey, state.mintDigest);

        vm.startBroadcast(keys.minterPrivateKey);
        token.mint(auth, signatures);
        vm.stopBroadcast();

        _requireEq(token.balanceOf(proofEnv.smokeUser), state.balanceBefore + MINT_AMOUNT, "MINT_BALANCE_DELTA");
        _requireEq(token.totalSupply(), state.supplyBefore + MINT_AMOUNT, "MINT_SUPPLY_DELTA");
        _requireTrue(token.authorizationUsed(state.mintDigest), "MINT_AUTHORIZATION_USED");
        _requireTrue(token.operationUsed(proofEnv.mint.operationId), "MINT_OPERATION_USED");
    }

    function _runBurnSmoke(EGold token, SmokeKeys memory keys, ProofLinkedEnv memory proofEnv, SmokeState memory state)
        private
    {
        uint256 balanceAfterMint = token.balanceOf(proofEnv.smokeUser);
        uint256 supplyAfterMint = token.totalSupply();

        vm.startBroadcast(keys.smokeUserPrivateKey);
        token.approve(proofEnv.burn.operator, BURN_AMOUNT);
        vm.stopBroadcast();

        EGold.BurnAuthorization memory auth = EGold.BurnAuthorization({
            operator: proofEnv.burn.operator,
            from: proofEnv.burn.account,
            amount: proofEnv.burn.amount,
            operationId: proofEnv.burn.operationId,
            reserveId: proofEnv.burn.reserveId,
            proofHash: proofEnv.burn.proofHash,
            validAfter: proofEnv.burn.validAfter,
            validBefore: proofEnv.burn.validBefore,
            nonce: proofEnv.burn.nonce
        });

        state.burnDigest = token.hashBurnAuthorization(auth);
        bytes[] memory signatures =
            _sortTwoSignatures(keys.attester1PrivateKey, keys.attester2PrivateKey, state.burnDigest);

        vm.startBroadcast(keys.minterPrivateKey);
        token.burnFrom(auth, signatures);
        vm.stopBroadcast();

        _requireEq(token.balanceOf(proofEnv.smokeUser), balanceAfterMint - BURN_AMOUNT, "BURN_BALANCE_DELTA");
        _requireEq(token.totalSupply(), supplyAfterMint - BURN_AMOUNT, "BURN_SUPPLY_DELTA");
        _requireTrue(token.authorizationUsed(state.burnDigest), "BURN_AUTHORIZATION_USED");
        _requireTrue(token.operationUsed(proofEnv.burn.operationId), "BURN_OPERATION_USED");
    }

    function _loadSmokeKeys() private view returns (SmokeKeys memory keys) {
        keys = SmokeKeys({
            minterPrivateKey: vm.envUint("EGOLD_MINTER_PRIVATE_KEY"),
            attester1PrivateKey: vm.envUint("EGOLD_ATTESTER_1_PRIVATE_KEY"),
            attester2PrivateKey: vm.envUint("EGOLD_ATTESTER_2_PRIVATE_KEY"),
            smokeUserPrivateKey: vm.envUint("EGOLD_SMOKE_USER_PRIVATE_KEY")
        });
    }

    function _loadProofLinkedEnv() private view returns (ProofLinkedEnv memory proofEnv) {
        proofEnv.smokeUser = vm.envAddress("EGOLD_SMOKE_USER");
        proofEnv.mint = _loadProofAuth("EGOLD_MINT");
        proofEnv.burn = _loadProofAuth("EGOLD_BURN");
    }

    function _loadProofAuth(string memory prefix) private view returns (ProofAuth memory auth) {
        auth = ProofAuth({
            operator: vm.envAddress(string.concat(prefix, "_OPERATOR")),
            account: vm.envAddress(string.concat(prefix, "_ACCOUNT")),
            amount: vm.envUint(string.concat(prefix, "_AMOUNT_UNITS")),
            operationId: vm.envBytes32(string.concat(prefix, "_OPERATION_ID")),
            reserveId: vm.envBytes32(string.concat(prefix, "_RESERVE_ID")),
            proofHash: vm.envBytes32(string.concat(prefix, "_PROOF_HASH")),
            validAfter: vm.envUint(string.concat(prefix, "_VALID_AFTER")),
            validBefore: vm.envUint(string.concat(prefix, "_VALID_BEFORE")),
            nonce: vm.envUint(string.concat(prefix, "_NONCE"))
        });
    }

    function _checkPrivateKey(string memory envVar, uint256 privateKey, address expected) private pure {
        address actual = vm.addr(privateKey);
        if (actual != expected) revert InvalidProofLinkedPrivateKey(envVar, expected, actual);
    }

    function _sign(uint256 privateKey, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _sortTwoSignatures(uint256 pkA, uint256 pkB, bytes32 digest)
        internal
        pure
        returns (bytes[] memory signatures)
    {
        bytes memory signatureA = _sign(pkA, digest);
        bytes memory signatureB = _sign(pkB, digest);
        address signerA = ECDSA.recover(digest, signatureA);
        address signerB = ECDSA.recover(digest, signatureB);

        signatures = new bytes[](PROOF_LINKED_THRESHOLD);
        if (signerA < signerB) {
            signatures[0] = signatureA;
            signatures[1] = signatureB;
        } else {
            signatures[0] = signatureB;
            signatures[1] = signatureA;
        }
    }

    function _requireTrue(bool value, string memory check) private pure {
        if (!value) revert ProofLinkedSmokeCheckFailed(check);
    }

    function _requireEq(uint256 actual, uint256 expected, string memory check) private pure {
        if (actual != expected) revert ProofLinkedSmokeCheckFailed(check);
    }

    function _requireEq(address actual, address expected, string memory check) private pure {
        if (actual != expected) revert ProofLinkedSmokeCheckFailed(check);
    }
}
