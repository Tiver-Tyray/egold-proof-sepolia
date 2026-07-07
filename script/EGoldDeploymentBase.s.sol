// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {EGold} from "../src/EGold.sol";

abstract contract EGoldDeploymentBase is Script {
    uint256 internal constant ATTESTER_COUNT = 3;

    struct DeploymentConfig {
        address minter;
        address attester1;
        address attester2;
        address attester3;
        uint256 threshold;
    }

    error MissingOrZeroAddress(string envVar);
    error DuplicateAttester(address attester);
    error MinterIsAttester(address account);
    error InvalidDeploymentThreshold(uint256 threshold);
    error PostDeployCheckFailed();

    function _loadDeploymentConfig() internal view returns (DeploymentConfig memory config) {
        config = DeploymentConfig({
            minter: vm.envOr("EGOLD_MINTER", address(0)),
            attester1: vm.envOr("EGOLD_ATTESTER_1", address(0)),
            attester2: vm.envOr("EGOLD_ATTESTER_2", address(0)),
            attester3: vm.envOr("EGOLD_ATTESTER_3", address(0)),
            threshold: vm.envOr("EGOLD_THRESHOLD", uint256(0))
        });

        _validateDeploymentConfig(config);
    }

    function _loadEGoldAddress() internal view returns (address egoldAddress) {
        egoldAddress = vm.envOr("EGOLD_ADDRESS", address(0));
        if (egoldAddress == address(0)) revert MissingOrZeroAddress("EGOLD_ADDRESS");
    }

    function _initialMinters(DeploymentConfig memory config) internal pure returns (address[] memory minters) {
        minters = new address[](1);
        minters[0] = config.minter;
    }

    function _initialAttesters(DeploymentConfig memory config) internal pure returns (address[] memory attesters) {
        attesters = new address[](ATTESTER_COUNT);
        attesters[0] = config.attester1;
        attesters[1] = config.attester2;
        attesters[2] = config.attester3;
    }

    function _constructorArgs(DeploymentConfig memory config) internal pure returns (bytes memory encodedArgs) {
        encodedArgs = abi.encode(_initialMinters(config), _initialAttesters(config), config.threshold);
    }

    function _optionalPrivateKey()
        internal
        view
        returns (uint256 privateKey, bool usePrivateKey, bool privateKeyEnvSet)
    {
        string memory rawPrivateKey = vm.envOr("PRIVATE_KEY", string(""));
        privateKeyEnvSet = bytes(rawPrivateKey).length != 0;

        if (privateKeyEnvSet) {
            privateKey = vm.parseUint(rawPrivateKey);
            usePrivateKey = privateKey != 0;
        }
    }

    function _validateDeploymentConfig(DeploymentConfig memory config) internal pure {
        if (config.minter == address(0)) revert MissingOrZeroAddress("EGOLD_MINTER");
        if (config.attester1 == address(0)) revert MissingOrZeroAddress("EGOLD_ATTESTER_1");
        if (config.attester2 == address(0)) revert MissingOrZeroAddress("EGOLD_ATTESTER_2");
        if (config.attester3 == address(0)) revert MissingOrZeroAddress("EGOLD_ATTESTER_3");

        if (config.attester1 == config.attester2) revert DuplicateAttester(config.attester1);
        if (config.attester1 == config.attester3) revert DuplicateAttester(config.attester1);
        if (config.attester2 == config.attester3) revert DuplicateAttester(config.attester2);

        if (config.minter == config.attester1) revert MinterIsAttester(config.minter);
        if (config.minter == config.attester2) revert MinterIsAttester(config.minter);
        if (config.minter == config.attester3) revert MinterIsAttester(config.minter);

        if (config.threshold == 0 || config.threshold > ATTESTER_COUNT) {
            revert InvalidDeploymentThreshold(config.threshold);
        }
    }

    function _runtimeCodeHash(address target) internal view returns (bytes32) {
        return target.codehash;
    }

    function _logDeploymentConfig(DeploymentConfig memory config, address deployer) internal view {
        console2.log("chainid:", block.chainid);
        console2.log("deployer:", deployer);
        console2.log("minter:", config.minter);
        console2.log("attester 1:", config.attester1);
        console2.log("attester 2:", config.attester2);
        console2.log("attester 3:", config.attester3);
        console2.log("threshold:", config.threshold);
        console2.log("constructor args hex:", vm.toString(_constructorArgs(config)));
    }

    function _runPostDeployChecks(EGold token, DeploymentConfig memory config) internal view returns (bool passed) {
        passed = true;
        passed = _logCheck("name == E-gold:", keccak256(bytes(token.name())) == keccak256(bytes("E-gold"))) && passed;
        passed = _logCheck("symbol == EGOLD:", keccak256(bytes(token.symbol())) == keccak256(bytes("EGOLD"))) && passed;
        passed = _logCheck("decimals == 4:", token.decimals() == 4) && passed;
        passed = _logCheck("threshold matches:", token.attestationThreshold() == config.threshold) && passed;
        passed = _logCheck("attester count == 3:", token.attesterCount() == ATTESTER_COUNT) && passed;
        passed = _logCheck("minter has MINTER_ROLE:", token.hasRole(token.MINTER_ROLE(), config.minter)) && passed;
        passed = _logCheck(
            "attester 1 has RESERVE_ATTESTER_ROLE:", token.hasRole(token.RESERVE_ATTESTER_ROLE(), config.attester1)
        ) && passed;
        passed = _logCheck(
            "attester 2 has RESERVE_ATTESTER_ROLE:", token.hasRole(token.RESERVE_ATTESTER_ROLE(), config.attester2)
        ) && passed;
        passed = _logCheck(
            "attester 3 has RESERVE_ATTESTER_ROLE:", token.hasRole(token.RESERVE_ATTESTER_ROLE(), config.attester3)
        ) && passed;
        passed =
            _logCheck("EGOLD_ADDRESS has no DEFAULT_ADMIN_ROLE:", _hasNoDefaultAdmin(token, address(token))) && passed;
        passed = _logCheck("minter has no DEFAULT_ADMIN_ROLE:", _hasNoDefaultAdmin(token, config.minter)) && passed;
        passed =
            _logCheck("attester 1 has no DEFAULT_ADMIN_ROLE:", _hasNoDefaultAdmin(token, config.attester1)) && passed;
        passed =
            _logCheck("attester 2 has no DEFAULT_ADMIN_ROLE:", _hasNoDefaultAdmin(token, config.attester2)) && passed;
        passed =
            _logCheck("attester 3 has no DEFAULT_ADMIN_ROLE:", _hasNoDefaultAdmin(token, config.attester3)) && passed;
    }

    function _hasNoDefaultAdmin(EGold token, address account) internal view returns (bool) {
        return !token.hasRole(token.DEFAULT_ADMIN_ROLE(), account);
    }

    function _logCheck(string memory label, bool value) internal pure returns (bool) {
        console2.log(label, value);
        return value;
    }
}
