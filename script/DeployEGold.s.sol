// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Script.sol";
import {EGold} from "../src/EGold.sol";
import {EGoldDeploymentBase} from "./EGoldDeploymentBase.s.sol";

contract DeployEGold is EGoldDeploymentBase {
    function run() external returns (EGold token) {
        DeploymentConfig memory config = _loadDeploymentConfig();
        (uint256 privateKey, bool usePrivateKey,) = _optionalPrivateKey();
        address deployer = usePrivateKey ? vm.addr(privateKey) : msg.sender;

        console2.log("EGold deployment rehearsal");
        _logDeploymentConfig(config, deployer);

        if (usePrivateKey) {
            vm.startBroadcast(privateKey);
        } else {
            vm.startBroadcast();
        }

        token = new EGold(_initialMinters(config), _initialAttesters(config), config.threshold);
        vm.stopBroadcast();

        bool passed = _runPostDeployChecks(token, config);
        passed = _logCheck("deployer has no DEFAULT_ADMIN_ROLE:", _hasNoDefaultAdmin(token, deployer)) && passed;
        console2.log(passed ? "POST_DEPLOY_STATUS: PASSED" : "POST_DEPLOY_STATUS: FAILED");
        if (!passed) revert PostDeployCheckFailed();

        bytes memory constructorArgs = _constructorArgs(config);
        bytes32 runtimeCodeHash = _runtimeCodeHash(address(token));

        console2.log("deployed address:", address(token));
        console2.log("chainid:", block.chainid);
        console2.log("deployer:", deployer);
        console2.log("minter:", config.minter);
        console2.log("attester 1:", config.attester1);
        console2.log("attester 2:", config.attester2);
        console2.log("attester 3:", config.attester3);
        console2.log("threshold:", config.threshold);
        console2.log("constructor args hex:", vm.toString(constructorArgs));
        console2.log("runtime codehash:", vm.toString(runtimeCodeHash));

        _writeManifest(token, config, deployer, constructorArgs, runtimeCodeHash);
    }

    function _writeManifest(
        EGold token,
        DeploymentConfig memory config,
        address deployer,
        bytes memory constructorArgs,
        bytes32 runtimeCodeHash
    ) private {
        string memory objectKey = "egold";
        vm.serializeUint(objectKey, "chainId", block.chainid);
        vm.serializeString(objectKey, "contractName", "EGold");
        vm.serializeAddress(objectKey, "contractAddress", address(token));
        vm.serializeAddress(objectKey, "deployer", deployer);
        vm.serializeAddress(objectKey, "minter", config.minter);
        vm.serializeAddress(objectKey, "attester1", config.attester1);
        vm.serializeAddress(objectKey, "attester2", config.attester2);
        vm.serializeAddress(objectKey, "attester3", config.attester3);
        vm.serializeUint(objectKey, "threshold", config.threshold);
        vm.serializeString(objectKey, "name", token.name());
        vm.serializeString(objectKey, "symbol", token.symbol());
        vm.serializeUint(objectKey, "decimals", token.decimals());
        vm.serializeUint(objectKey, "attestationThreshold", token.attestationThreshold());
        vm.serializeUint(objectKey, "attesterCount", token.attesterCount());
        vm.serializeBytes32(objectKey, "runtimeCodeHash", runtimeCodeHash);
        vm.serializeString(objectKey, "constructorArgsHex", vm.toString(constructorArgs));
        vm.serializeUint(objectKey, "timestamp", block.timestamp);
        string memory json = vm.serializeUint(objectKey, "blockNumber", block.number);

        string memory directory = string.concat("deployments/", vm.toString(block.chainid));
        string memory path = string.concat(directory, "/EGold.json");
        vm.createDir(directory, true);
        vm.writeJson(json, path);

        console2.log("deployment manifest:", path);
    }
}
