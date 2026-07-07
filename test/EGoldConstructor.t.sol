// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EGold} from "../src/EGold.sol";

contract EGoldConstructorTest is Test {
    address internal minter = address(0xA11CE);
    address internal attester1 = address(0xB0B);
    address internal attester2 = address(0xCAFE);
    address internal attester3 = address(0xD00D);

    function testDeploymentFaaltBijLegeMinterArray() public {
        address[] memory minters = new address[](0);
        address[] memory attesters = _attesters();

        vm.expectRevert(EGold.EmptyMinterSet.selector);
        new EGold(minters, attesters, 2);
    }

    function testDeploymentFaaltBijLegeAttesterArray() public {
        address[] memory minters = _minters();
        address[] memory attesters = new address[](0);

        vm.expectRevert(EGold.EmptyAttesterSet.selector);
        new EGold(minters, attesters, 1);
    }

    function testDeploymentFaaltBijZeroMinterAddress() public {
        address[] memory minters = new address[](1);
        address[] memory attesters = _attesters();

        vm.expectRevert(abi.encodeWithSelector(EGold.InvalidAccount.selector, address(0)));
        new EGold(minters, attesters, 2);
    }

    function testDeploymentFaaltBijZeroAttesterAddress() public {
        address[] memory minters = _minters();
        address[] memory attesters = _attesters();
        attesters[1] = address(0);

        vm.expectRevert(abi.encodeWithSelector(EGold.InvalidAccount.selector, address(0)));
        new EGold(minters, attesters, 2);
    }

    function testDeploymentFaaltBijDuplicateMinter() public {
        address[] memory minters = new address[](2);
        address[] memory attesters = _attesters();
        minters[0] = minter;
        minters[1] = minter;

        vm.expectRevert(abi.encodeWithSelector(EGold.DuplicateAccount.selector, minter));
        new EGold(minters, attesters, 2);
    }

    function testDeploymentFaaltBijDuplicateAttester() public {
        address[] memory minters = _minters();
        address[] memory attesters = _attesters();
        attesters[2] = attester1;

        vm.expectRevert(abi.encodeWithSelector(EGold.DuplicateAccount.selector, attester1));
        new EGold(minters, attesters, 2);
    }

    function testDeploymentFaaltBijThresholdNul() public {
        address[] memory minters = _minters();
        address[] memory attesters = _attesters();

        vm.expectRevert(abi.encodeWithSelector(EGold.InvalidThreshold.selector, 0, 3));
        new EGold(minters, attesters, 0);
    }

    function testDeploymentFaaltBijThresholdGroterDanAttesterCount() public {
        address[] memory minters = _minters();
        address[] memory attesters = _attesters();

        vm.expectRevert(abi.encodeWithSelector(EGold.InvalidThreshold.selector, 4, 3));
        new EGold(minters, attesters, 4);
    }

    function testDeploymentFaaltBijAccountDatMinterEnAttesterIs() public {
        address[] memory minters = _minters();
        address[] memory attesters = _attesters();
        attesters[1] = minter;

        vm.expectRevert(abi.encodeWithSelector(EGold.RoleSeparationViolation.selector, minter));
        new EGold(minters, attesters, 2);
    }

    function testDeploymentSlaagtMetEenMinterDrieAttestersThresholdTwee() public {
        address[] memory minters = _minters();
        address[] memory attesters = _attesters();

        EGold token = new EGold(minters, attesters, 2);

        assertEq(token.name(), "E-gold");
        assertEq(token.symbol(), "EGOLD");
        assertEq(token.decimals(), 4);
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
        assertTrue(token.hasRole(token.RESERVE_ATTESTER_ROLE(), attester1));
        assertTrue(token.hasRole(token.RESERVE_ATTESTER_ROLE(), attester2));
        assertTrue(token.hasRole(token.RESERVE_ATTESTER_ROLE(), attester3));
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(this)));
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), minter));
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), attester1));
        assertEq(token.attestationThreshold(), 2);
        assertEq(token.attesterCount(), 3);
    }

    function _minters() internal view returns (address[] memory minters) {
        minters = new address[](1);
        minters[0] = minter;
    }

    function _attesters() internal view returns (address[] memory attesters) {
        attesters = new address[](3);
        attesters[0] = attester1;
        attesters[1] = attester2;
        attesters[2] = attester3;
    }
}
