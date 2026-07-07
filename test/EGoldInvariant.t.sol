// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {EGold} from "../src/EGold.sol";

contract EGoldInvariantHandler is Test {
    uint256 internal constant MAX_ACTION_AMOUNT = 1_000_000_000;

    EGold public token;
    uint256 public immutable threshold;
    uint256 public modelMinted;
    uint256 public modelBurned;
    uint256 public nonce;

    uint256[] internal attesterKeys;
    address[] internal attesters;
    address[5] internal actors = [address(0xA11CE), address(0xB0B), address(0xCAFE), address(0xD00D), address(0xEACE)];

    constructor(uint256[] memory sortedAttesterKeys, uint256 threshold_) {
        threshold = threshold_;

        for (uint256 i; i < sortedAttesterKeys.length; ++i) {
            attesterKeys.push(sortedAttesterKeys[i]);
            attesters.push(vm.addr(sortedAttesterKeys[i]));
        }
    }

    function setToken(EGold token_) external {
        require(address(token) == address(0), "TOKEN_ALREADY_SET");
        token = token_;
    }

    function mint(uint256 actorSeed, uint96 amountSeed) external {
        address to = actors[actorSeed % actors.length];
        uint256 amount = bound(uint256(amountSeed), 1, MAX_ACTION_AMOUNT);
        uint256 nextNonce = ++nonce;

        EGold.MintAuthorization memory auth = EGold.MintAuthorization({
            operator: address(this),
            to: to,
            amount: amount,
            operationId: keccak256(abi.encode("mint-operation", nextNonce)),
            reserveId: keccak256(abi.encode("reserve", nextNonce)),
            proofHash: keccak256(abi.encode("proof", nextNonce)),
            validAfter: block.timestamp,
            validBefore: block.timestamp + 1 days,
            nonce: nextNonce
        });
        bytes32 digest = token.hashMintAuthorization(auth);

        token.mint(auth, _thresholdSignatures(digest));
        modelMinted += amount;
    }

    function burnWithConsent(uint256 actorSeed, uint96 amountSeed) external {
        address from = actors[actorSeed % actors.length];
        uint256 balance = token.balanceOf(from);
        if (balance == 0) return;

        uint256 amount = bound(uint256(amountSeed), 1, balance);
        uint256 nextNonce = ++nonce;

        EGold.BurnAuthorization memory auth = EGold.BurnAuthorization({
            operator: address(this),
            from: from,
            amount: amount,
            operationId: keccak256(abi.encode("burn-operation", nextNonce)),
            reserveId: keccak256(abi.encode("reserve", nextNonce)),
            proofHash: keccak256(abi.encode("proof", nextNonce)),
            validAfter: block.timestamp,
            validBefore: block.timestamp + 1 days,
            nonce: nextNonce
        });
        bytes32 digest = token.hashBurnAuthorization(auth);

        vm.prank(from);
        token.approve(address(this), amount);

        token.burnFrom(auth, _thresholdSignatures(digest));
        modelBurned += amount;
    }

    function modelSupply() external view returns (uint256) {
        return modelMinted - modelBurned;
    }

    function attesterAt(uint256 index) external view returns (address) {
        return attesters[index];
    }

    function _thresholdSignatures(bytes32 digest) internal returns (bytes[] memory signatures) {
        signatures = new bytes[](threshold);
        for (uint256 i; i < threshold; ++i) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(attesterKeys[i], digest);
            signatures[i] = abi.encodePacked(r, s, v);
        }
    }
}

contract EGoldInvariantTest is StdInvariant, Test {
    uint256 internal constant THRESHOLD = 2;

    EGold internal token;
    EGoldInvariantHandler internal handler;
    address internal immutable missingAdmin = address(0xDEAD);
    uint256[] internal attesterKeys;
    address[] internal attesters;

    function setUp() public {
        attesterKeys.push(0xB0B);
        attesterKeys.push(0xCAFE);
        attesterKeys.push(0xD00D);
        _sortAttesterKeys();

        handler = new EGoldInvariantHandler(attesterKeys, THRESHOLD);

        address[] memory minters = new address[](1);
        address[] memory initialAttesters = new address[](attesters.length);
        minters[0] = address(handler);

        for (uint256 i; i < attesters.length; ++i) {
            initialAttesters[i] = attesters[i];
        }

        token = new EGold(minters, initialAttesters, THRESHOLD);
        handler.setToken(token);

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = EGoldInvariantHandler.mint.selector;
        selectors[1] = EGoldInvariantHandler.burnWithConsent.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_TotalSupplyMatchesModelMintedMinusBurned() public view {
        assertEq(token.totalSupply(), handler.modelSupply());
    }

    function invariant_TotalSupplyNeverExceedsModelMinted() public view {
        assertLe(token.totalSupply(), handler.modelMinted());
    }

    function invariant_RollenBlijvenImmutable() public {
        bytes32 role = token.MINTER_ROLE();

        vm.expectRevert(EGold.RolesAreImmutable.selector);
        token.grantRole(role, address(0xBAD));

        vm.expectRevert(EGold.RolesAreImmutable.selector);
        token.revokeRole(role, address(handler));

        vm.prank(address(handler));
        vm.expectRevert(EGold.RolesAreImmutable.selector);
        token.renounceRole(role, address(handler));
    }

    function invariant_MinterRoleBlijftBijZelfdeMinter() public view {
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(handler)));
    }

    function invariant_ReserveAttesterRolesBlijvenBijZelfdeAttesters() public view {
        for (uint256 i; i < attesters.length; ++i) {
            assertTrue(token.hasRole(token.RESERVE_ATTESTER_ROLE(), attesters[i]));
            assertEq(handler.attesterAt(i), attesters[i]);
        }
    }

    function invariant_DefaultAdminRoleBlijftLeeg() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(this)));
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(handler)));
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), missingAdmin));
    }

    function invariant_AttestationThresholdBlijftConstant() public view {
        assertEq(token.attestationThreshold(), THRESHOLD);
    }

    function invariant_AttesterCountBlijftConstant() public view {
        assertEq(token.attesterCount(), attesters.length);
    }

    function _sortAttesterKeys() internal {
        uint256 length = attesterKeys.length;
        for (uint256 i; i < length; ++i) {
            for (uint256 j = i + 1; j < length; ++j) {
                if (vm.addr(attesterKeys[j]) < vm.addr(attesterKeys[i])) {
                    uint256 tmp = attesterKeys[i];
                    attesterKeys[i] = attesterKeys[j];
                    attesterKeys[j] = tmp;
                }
            }
        }

        for (uint256 i; i < length; ++i) {
            attesters.push(vm.addr(attesterKeys[i]));
        }
    }
}
