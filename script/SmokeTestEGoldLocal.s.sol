// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Script.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EGold} from "../src/EGold.sol";
import {EGoldDeploymentBase} from "./EGoldDeploymentBase.s.sol";

contract SmokeTestEGoldLocal is EGoldDeploymentBase {
    uint256 private constant LOCAL_SMOKE_THRESHOLD = 2;
    uint256 private constant MINT_AMOUNT = 10_000;
    uint256 private constant BURN_AMOUNT = 4_000;

    struct SmokeKeys {
        uint256 minterPrivateKey;
        uint256 attester1PrivateKey;
        uint256 attester2PrivateKey;
        uint256 smokeUserPrivateKey;
    }

    struct SmokeState {
        address smokeUser;
        uint256 balanceBefore;
        uint256 supplyBefore;
        bytes32 mintOperationId;
        bytes32 mintDigest;
        bytes32 burnOperationId;
        bytes32 burnDigest;
    }

    error InvalidSmokePrivateKey(string envVar, address expected, address actual);
    error LocalSmokeRequiresThresholdTwo(uint256 threshold);
    error SmokeCheckFailed(string check);

    function run() external {
        DeploymentConfig memory config = _loadDeploymentConfig();
        if (config.threshold != LOCAL_SMOKE_THRESHOLD) revert LocalSmokeRequiresThresholdTwo(config.threshold);

        EGold token = EGold(_loadEGoldAddress());
        SmokeKeys memory keys = _loadSmokeKeys();
        address smokeUser = vm.addr(keys.smokeUserPrivateKey);

        _checkPrivateKey("EGOLD_MINTER_PRIVATE_KEY", keys.minterPrivateKey, config.minter);
        _checkPrivateKey("EGOLD_ATTESTER_1_PRIVATE_KEY", keys.attester1PrivateKey, config.attester1);
        _checkPrivateKey("EGOLD_ATTESTER_2_PRIVATE_KEY", keys.attester2PrivateKey, config.attester2);

        bool preflightPassed = _runPostDeployChecks(token, config);
        if (!preflightPassed) revert PostDeployCheckFailed();

        SmokeState memory state;
        state.smokeUser = smokeUser;
        state.balanceBefore = token.balanceOf(smokeUser);
        state.supplyBefore = token.totalSupply();
        _requireEq(state.balanceBefore, 0, "SMOKE_USER_INITIAL_BALANCE_ZERO");

        _runMintSmoke(token, config, keys, state);
        _runBurnSmoke(token, config, keys, state);

        uint256 finalBalance = token.balanceOf(smokeUser);
        uint256 finalSupply = token.totalSupply();

        console2.log("contract address:", address(token));
        console2.log("chainid:", block.chainid);
        console2.log("smoke user:", smokeUser);
        console2.log("mint amount:", MINT_AMOUNT);
        console2.log("burn amount:", BURN_AMOUNT);
        console2.log("final balance:", finalBalance);
        console2.log("final totalSupply:", finalSupply);
        console2.log("LOCAL_SMOKE_STATUS: PASSED");
    }

    function _runMintSmoke(EGold token, DeploymentConfig memory config, SmokeKeys memory keys, SmokeState memory state)
        private
    {
        state.mintOperationId =
            keccak256(abi.encode("LOCAL_SMOKE_MINT", block.chainid, address(token), block.timestamp));
        EGold.MintAuthorization memory auth = EGold.MintAuthorization({
            operator: config.minter,
            to: state.smokeUser,
            amount: MINT_AMOUNT,
            operationId: state.mintOperationId,
            reserveId: keccak256("LOCAL_SMOKE_RESERVE"),
            proofHash: keccak256(
                abi.encode("LOCAL_SMOKE_MINT_PROOF", state.mintOperationId, state.smokeUser, MINT_AMOUNT)
            ),
            validAfter: block.timestamp - 1,
            validBefore: block.timestamp + 1 days,
            nonce: uint256(keccak256(abi.encode("LOCAL_SMOKE_MINT_NONCE", block.timestamp, state.smokeUser)))
        });

        state.mintDigest = token.hashMintAuthorization(auth);
        bytes[] memory signatures =
            _sortTwoSignatures(keys.attester1PrivateKey, keys.attester2PrivateKey, state.mintDigest);

        vm.startBroadcast(keys.minterPrivateKey);
        token.mint(auth, signatures);
        vm.stopBroadcast();

        _requireEq(token.balanceOf(state.smokeUser), state.balanceBefore + MINT_AMOUNT, "MINT_BALANCE_DELTA");
        _requireEq(token.totalSupply(), state.supplyBefore + MINT_AMOUNT, "MINT_SUPPLY_DELTA");
        _requireTrue(token.authorizationUsed(state.mintDigest), "MINT_AUTHORIZATION_USED");
        _requireTrue(token.operationUsed(state.mintOperationId), "MINT_OPERATION_USED");
    }

    function _runBurnSmoke(EGold token, DeploymentConfig memory config, SmokeKeys memory keys, SmokeState memory state)
        private
    {
        uint256 balanceAfterMint = token.balanceOf(state.smokeUser);
        uint256 supplyAfterMint = token.totalSupply();

        vm.startBroadcast(keys.smokeUserPrivateKey);
        token.approve(config.minter, BURN_AMOUNT);
        vm.stopBroadcast();

        state.burnOperationId =
            keccak256(abi.encode("LOCAL_SMOKE_BURN", block.chainid, address(token), block.timestamp));
        EGold.BurnAuthorization memory auth = EGold.BurnAuthorization({
            operator: config.minter,
            from: state.smokeUser,
            amount: BURN_AMOUNT,
            operationId: state.burnOperationId,
            reserveId: keccak256("LOCAL_SMOKE_RESERVE"),
            proofHash: keccak256(
                abi.encode("LOCAL_SMOKE_BURN_PROOF", state.burnOperationId, state.smokeUser, BURN_AMOUNT)
            ),
            validAfter: block.timestamp - 1,
            validBefore: block.timestamp + 1 days,
            nonce: uint256(keccak256(abi.encode("LOCAL_SMOKE_BURN_NONCE", block.timestamp, state.smokeUser)))
        });

        state.burnDigest = token.hashBurnAuthorization(auth);
        bytes[] memory signatures =
            _sortTwoSignatures(keys.attester1PrivateKey, keys.attester2PrivateKey, state.burnDigest);

        vm.startBroadcast(keys.minterPrivateKey);
        token.burnFrom(auth, signatures);
        vm.stopBroadcast();

        _requireEq(token.balanceOf(state.smokeUser), balanceAfterMint - BURN_AMOUNT, "BURN_BALANCE_DELTA");
        _requireEq(token.balanceOf(state.smokeUser), MINT_AMOUNT - BURN_AMOUNT, "BURN_FINAL_BALANCE");
        _requireEq(token.totalSupply(), supplyAfterMint - BURN_AMOUNT, "BURN_SUPPLY_DELTA");
        _requireTrue(token.authorizationUsed(state.burnDigest), "BURN_AUTHORIZATION_USED");
        _requireTrue(token.operationUsed(state.burnOperationId), "BURN_OPERATION_USED");
    }

    function _loadSmokeKeys() private view returns (SmokeKeys memory keys) {
        keys = SmokeKeys({
            minterPrivateKey: vm.envUint("EGOLD_MINTER_PRIVATE_KEY"),
            attester1PrivateKey: vm.envUint("EGOLD_ATTESTER_1_PRIVATE_KEY"),
            attester2PrivateKey: vm.envUint("EGOLD_ATTESTER_2_PRIVATE_KEY"),
            smokeUserPrivateKey: vm.envUint("EGOLD_SMOKE_USER_PRIVATE_KEY")
        });
    }

    function _checkPrivateKey(string memory envVar, uint256 privateKey, address expected) private pure {
        address actual = vm.addr(privateKey);
        if (actual != expected) revert InvalidSmokePrivateKey(envVar, expected, actual);
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

        signatures = new bytes[](LOCAL_SMOKE_THRESHOLD);
        if (signerA < signerB) {
            signatures[0] = signatureA;
            signatures[1] = signatureB;
        } else {
            signatures[0] = signatureB;
            signatures[1] = signatureA;
        }
    }

    function _requireTrue(bool value, string memory check) private pure {
        if (!value) revert SmokeCheckFailed(check);
    }

    function _requireEq(uint256 actual, uint256 expected, string memory check) private pure {
        if (actual != expected) revert SmokeCheckFailed(check);
    }
}
