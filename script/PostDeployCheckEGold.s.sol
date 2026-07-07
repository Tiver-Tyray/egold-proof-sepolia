// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Script.sol";
import {EGold} from "../src/EGold.sol";
import {EGoldDeploymentBase} from "./EGoldDeploymentBase.s.sol";

contract PostDeployCheckEGold is EGoldDeploymentBase {
    function run() external view {
        DeploymentConfig memory config = _loadDeploymentConfig();
        address egoldAddress = _loadEGoldAddress();
        EGold token = EGold(egoldAddress);
        bytes32 runtimeCodeHash = _runtimeCodeHash(egoldAddress);

        console2.log("EGold post-deploy check");
        console2.log("chainid:", block.chainid);
        console2.log("contract address:", egoldAddress);
        console2.log("runtime codehash:", vm.toString(runtimeCodeHash));
        console2.log("minter:", config.minter);
        console2.log("attester 1:", config.attester1);
        console2.log("attester 2:", config.attester2);
        console2.log("attester 3:", config.attester3);
        console2.log("threshold:", config.threshold);

        bool passed = _runPostDeployChecks(token, config);
        console2.log(passed ? "POST_DEPLOY_STATUS: PASSED" : "POST_DEPLOY_STATUS: FAILED");
        if (!passed) revert PostDeployCheckFailed();
    }
}
