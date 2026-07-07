// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface Vm {
    function addr(uint256 privateKey) external returns (address);
    function assume(bool condition) external;
    function expectRevert() external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert(bytes4 selector) external;
    function prank(address sender) external;
    function sign(uint256 privateKey, bytes32 digest) external returns (uint8 v, bytes32 r, bytes32 s);
}

abstract contract MinimalTest {
    struct FuzzSelector {
        address addr;
        bytes4[] selectors;
    }

    struct FuzzArtifactSelector {
        string artifact;
        bytes4[] selectors;
    }

    struct FuzzInterface {
        address addr;
        string[] artifacts;
    }

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address[] private _excludedContracts;
    address[] private _excludedSenders;
    address[] private _targetedContracts;
    address[] private _targetedSenders;

    string[] private _excludedArtifacts;
    string[] private _targetedArtifacts;

    FuzzArtifactSelector[] private _targetedArtifactSelectors;
    FuzzSelector[] private _excludedSelectors;
    FuzzSelector[] private _targetedSelectors;
    FuzzInterface[] private _targetedInterfaces;

    error AssertionFailed();
    error UintAssertionFailed(uint256 left, uint256 right);
    error AddressAssertionFailed(address left, address right);
    error BoolAssertionFailed(bool left, bool right);

    function targetContract(address target) internal {
        _targetedContracts.push(target);
    }

    function excludeArtifacts() public view returns (string[] memory) {
        return _excludedArtifacts;
    }

    function excludeContracts() public view returns (address[] memory) {
        return _excludedContracts;
    }

    function excludeSelectors() public view returns (FuzzSelector[] memory) {
        return _excludedSelectors;
    }

    function excludeSenders() public view returns (address[] memory) {
        return _excludedSenders;
    }

    function targetArtifactSelectors() public view returns (FuzzArtifactSelector[] memory) {
        return _targetedArtifactSelectors;
    }

    function targetArtifacts() public view returns (string[] memory) {
        return _targetedArtifacts;
    }

    function targetContracts() public view returns (address[] memory) {
        return _targetedContracts;
    }

    function targetInterfaces() public view returns (FuzzInterface[] memory) {
        return _targetedInterfaces;
    }

    function targetSelectors() public view returns (FuzzSelector[] memory) {
        return _targetedSelectors;
    }

    function targetSenders() public view returns (address[] memory) {
        return _targetedSenders;
    }

    function assertEq(uint256 left, uint256 right) internal pure {
        if (left != right) revert UintAssertionFailed(left, right);
    }

    function assertEq(address left, address right) internal pure {
        if (left != right) revert AddressAssertionFailed(left, right);
    }

    function assertTrue(bool value) internal pure {
        if (!value) revert BoolAssertionFailed(value, true);
    }

    function assertFalse(bool value) internal pure {
        if (value) revert BoolAssertionFailed(value, false);
    }

    function _bound(uint256 value, uint256 min, uint256 max) internal pure returns (uint256) {
        if (max < min) revert AssertionFailed();
        if (value < min) return min;
        if (value > max) return min + (value % (max - min + 1));
        return value;
    }

    function _signature(uint256 privateKey, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
