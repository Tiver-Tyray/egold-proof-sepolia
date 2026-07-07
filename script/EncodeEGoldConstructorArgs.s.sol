// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Script.sol";
import {EGoldDeploymentBase} from "./EGoldDeploymentBase.s.sol";

contract EncodeEGoldConstructorArgs is EGoldDeploymentBase {
    function run() external view {
        DeploymentConfig memory config = _loadDeploymentConfig();
        console2.log(vm.toString(_constructorArgs(config)));
    }
}
