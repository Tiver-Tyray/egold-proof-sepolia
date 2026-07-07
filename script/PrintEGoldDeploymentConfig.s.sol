// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Script.sol";
import {EGoldDeploymentBase} from "./EGoldDeploymentBase.s.sol";

contract PrintEGoldDeploymentConfig is EGoldDeploymentBase {
    function run() external view {
        DeploymentConfig memory config = _loadDeploymentConfig();
        (uint256 privateKey, bool usePrivateKey, bool privateKeyEnvSet) = _optionalPrivateKey();

        console2.log("EGold deployment config");
        console2.log("chainid:", block.chainid);
        console2.log("deployer / msg.sender:", msg.sender);

        if (usePrivateKey) {
            console2.log("PRIVATE_KEY derived deployer:", vm.addr(privateKey));
        }
        if (privateKeyEnvSet) {
            console2.log("WARNING: PRIVATE_KEY is set. Keep it out of git and prefer keystore or hardware flows.");
        }

        _logDeploymentConfig(config, msg.sender);
    }
}
