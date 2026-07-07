// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EGold} from "../src/EGold.sol";

contract EGoldTest is Test {
    uint256 internal constant MINTER_PK = 0xA11CE;
    uint256 internal constant ATTACKER_PK = 0xBAD;
    uint256 internal constant THRESHOLD = 2;

    EGold internal token;
    address internal minter;
    address internal attacker;
    uint256[] internal attesterKeys;
    address[] internal attesters;

    function setUp() public {
        minter = vm.addr(MINTER_PK);
        attacker = vm.addr(ATTACKER_PK);

        attesterKeys.push(0xB0B);
        attesterKeys.push(0xCAFE);
        attesterKeys.push(0xD00D);
        _sortAttesterKeys();

        token = _deploy();
    }

    function testMetadataKlopt() public view {
        assertEq(token.name(), "E-gold");
        assertEq(token.symbol(), "EGOLD");
        assertEq(token.decimals(), 4);
    }

    function testMinterRoleKlopt() public view {
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
        assertFalse(token.hasRole(token.MINTER_ROLE(), attacker));
    }

    function testAttesterRolesKloppen() public view {
        for (uint256 i; i < attesters.length; ++i) {
            assertTrue(token.hasRole(token.RESERVE_ATTESTER_ROLE(), attesters[i]));
        }
        assertEq(token.attestationThreshold(), THRESHOLD);
        assertEq(token.attesterCount(), attesters.length);
    }

    function testDefaultAdminRoleIsAanNiemandGegeven() public view {
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(this)));
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), minter));
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), attesters[0]));
    }

    function testGrantRoleRevertAltijd() public {
        bytes32 role = token.MINTER_ROLE();

        vm.expectRevert(EGold.RolesAreImmutable.selector);
        token.grantRole(role, attacker);
    }

    function testRevokeRoleRevertAltijd() public {
        bytes32 role = token.MINTER_ROLE();

        vm.expectRevert(EGold.RolesAreImmutable.selector);
        token.revokeRole(role, minter);
    }

    function testRenounceRoleRevertAltijd() public {
        bytes32 role = token.MINTER_ROLE();

        vm.prank(minter);
        vm.expectRevert(EGold.RolesAreImmutable.selector);
        token.renounceRole(role, minter);
    }

    function testMintMetGeldigeThresholdSignaturesWerkt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-1", 1);
        bytes32 digest = token.hashMintAuthorization(auth);

        vm.prank(minter);
        token.mint(auth, _thresholdSignatures(digest));

        assertEq(token.totalSupply(), auth.amount);
        assertEq(token.balanceOf(auth.to), auth.amount);
        assertTrue(token.authorizationUsed(digest));
        assertTrue(token.operationUsed(auth.operationId));
    }

    function testMintReplayMetZelfdeDigestFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-1", 1);
        bytes32 digest = token.hashMintAuthorization(auth);
        bytes[] memory signatures = _thresholdSignatures(digest);

        vm.prank(minter);
        token.mint(auth, signatures);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(EGold.AuthorizationAlreadyUsed.selector, digest));
        token.mint(auth, signatures);
    }

    function testMintMetZelfdeOperationIdMaarAndereDigestFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "same-operation", 1);
        bytes32 digest = token.hashMintAuthorization(auth);

        vm.prank(minter);
        token.mint(auth, _thresholdSignatures(digest));

        EGold.MintAuthorization memory replay = _mintAuth(address(0xBEEF), 200_000, "same-operation", 2);
        bytes32 replayDigest = token.hashMintAuthorization(replay);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(EGold.OperationAlreadyUsed.selector, replay.operationId));
        token.mint(replay, _thresholdSignatures(replayDigest));
    }

    function testMintMetTeWeinigSignaturesFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-1", 1);
        bytes32 digest = token.hashMintAuthorization(auth);
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = _sign(attesterKeys[0], digest);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(EGold.InvalidSignatureCount.selector, 1, THRESHOLD));
        token.mint(auth, signatures);
    }

    function testMintMetDuplicateAttesterSignatureFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-1", 1);
        bytes32 digest = token.hashMintAuthorization(auth);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = _sign(attesterKeys[0], digest);
        signatures[1] = _sign(attesterKeys[0], digest);

        vm.prank(minter);
        vm.expectRevert();
        token.mint(auth, signatures);
    }

    function testMintMetUnsortedSignaturesFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-1", 1);
        bytes32 digest = token.hashMintAuthorization(auth);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = _sign(attesterKeys[1], digest);
        signatures[1] = _sign(attesterKeys[0], digest);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(EGold.UnsortedSignatures.selector, attesters[1], attesters[0]));
        token.mint(auth, signatures);
    }

    function testMintDoorNietMinterFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-1", 1);
        bytes32 digest = token.hashMintAuthorization(auth);

        vm.prank(attacker);
        vm.expectRevert();
        token.mint(auth, _thresholdSignatures(digest));
    }

    function testMintWaarbijCallerNietOperatorIsFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-1", 1);
        auth.operator = address(0xABCD);
        bytes32 digest = token.hashMintAuthorization(auth);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(EGold.InvalidOperator.selector, auth.operator, minter));
        token.mint(auth, _thresholdSignatures(digest));
    }

    function testBurnFromVanAndermansBalanceZonderAllowanceFaalt() public {
        address holder = address(0xCAFE);
        _mintTo(holder, 100_000, "mint-1", 1);

        EGold.BurnAuthorization memory auth = _burnAuth(holder, 40_000, "burn-1", 2);
        bytes32 digest = token.hashBurnAuthorization(auth);

        vm.prank(minter);
        vm.expectRevert();
        token.burnFrom(auth, _thresholdSignatures(digest));

        assertEq(token.totalSupply(), 100_000);
        assertEq(token.balanceOf(holder), 100_000);
    }

    function testBurnFromVanAndermansBalanceMetAllowanceWerkt() public {
        address holder = address(0xCAFE);
        _mintTo(holder, 100_000, "mint-1", 1);

        EGold.BurnAuthorization memory auth = _burnAuth(holder, 40_000, "burn-1", 2);
        bytes32 digest = token.hashBurnAuthorization(auth);

        vm.prank(holder);
        token.approve(minter, auth.amount);

        vm.prank(minter);
        token.burnFrom(auth, _thresholdSignatures(digest));

        assertEq(token.totalSupply(), 60_000);
        assertEq(token.balanceOf(holder), 60_000);
        assertTrue(token.authorizationUsed(digest));
        assertTrue(token.operationUsed(auth.operationId));
    }

    function testBurnFromVanEigenMinterBalanceWerktZonderAllowance() public {
        _mintTo(minter, 100_000, "mint-1", 1);

        EGold.BurnAuthorization memory auth = _burnAuth(minter, 100_000, "burn-1", 2);
        bytes32 digest = token.hashBurnAuthorization(auth);

        vm.prank(minter);
        token.burnFrom(auth, _thresholdSignatures(digest));

        assertEq(token.totalSupply(), 0);
        assertEq(token.balanceOf(minter), 0);
    }

    function testCrossContractReplayFaalt() public {
        EGold tokenB = _deploy();
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-1", 1);

        bytes32 tokenADigest = token.hashMintAuthorization(auth);
        bytes[] memory tokenASignatures = _thresholdSignatures(tokenADigest);

        vm.prank(minter);
        vm.expectRevert();
        tokenB.mint(auth, tokenASignatures);
    }

    function testFuzzMintSupplyReplayEnOperationReplay(
        address to,
        uint96 amountSeed,
        uint256 nonce,
        bytes32 operationId,
        bytes32 reserveId,
        bytes32 proofHash
    ) public {
        if (to == address(0)) to = address(0xCAFE);
        if (operationId == bytes32(0)) operationId = keccak256("operation");
        if (reserveId == bytes32(0)) reserveId = keccak256("reserve");
        if (proofHash == bytes32(0)) proofHash = keccak256("proof");
        uint256 amount = bound(uint256(amountSeed), 1, type(uint96).max);

        EGold.MintAuthorization memory auth = EGold.MintAuthorization({
            operator: minter,
            to: to,
            amount: amount,
            operationId: operationId,
            reserveId: reserveId,
            proofHash: proofHash,
            validAfter: block.timestamp,
            validBefore: block.timestamp + 1 days,
            nonce: nonce
        });
        bytes32 digest = token.hashMintAuthorization(auth);

        vm.prank(minter);
        token.mint(auth, _thresholdSignatures(digest));

        assertEq(token.totalSupply(), amount);
        assertEq(token.balanceOf(to), amount);
        assertTrue(token.authorizationUsed(digest));
        assertTrue(token.operationUsed(operationId));

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(EGold.AuthorizationAlreadyUsed.selector, digest));
        token.mint(auth, _thresholdSignatures(digest));
    }

    function _deploy() internal returns (EGold) {
        address[] memory minters = new address[](1);
        address[] memory initialAttesters = new address[](attesters.length);
        minters[0] = minter;

        for (uint256 i; i < attesters.length; ++i) {
            initialAttesters[i] = attesters[i];
        }

        return new EGold(minters, initialAttesters, THRESHOLD);
    }

    function _mintTo(address to, uint256 amount, string memory label, uint256 nonce) internal {
        EGold.MintAuthorization memory auth = _mintAuth(to, amount, label, nonce);
        bytes32 digest = token.hashMintAuthorization(auth);

        vm.prank(minter);
        token.mint(auth, _thresholdSignatures(digest));
    }

    function _mintAuth(address to, uint256 amount, string memory label, uint256 nonce)
        internal
        view
        returns (EGold.MintAuthorization memory)
    {
        return EGold.MintAuthorization({
            operator: minter,
            to: to,
            amount: amount,
            operationId: keccak256(abi.encode("mint-operation", label)),
            reserveId: keccak256(abi.encode("reserve", label)),
            proofHash: keccak256(abi.encode("proof", label)),
            validAfter: block.timestamp,
            validBefore: block.timestamp + 1 days,
            nonce: nonce
        });
    }

    function _burnAuth(address from, uint256 amount, string memory label, uint256 nonce)
        internal
        view
        returns (EGold.BurnAuthorization memory)
    {
        return EGold.BurnAuthorization({
            operator: minter,
            from: from,
            amount: amount,
            operationId: keccak256(abi.encode("burn-operation", label)),
            reserveId: keccak256(abi.encode("reserve", label)),
            proofHash: keccak256(abi.encode("proof", label)),
            validAfter: block.timestamp,
            validBefore: block.timestamp + 1 days,
            nonce: nonce
        });
    }

    function _thresholdSignatures(bytes32 digest) internal returns (bytes[] memory signatures) {
        signatures = new bytes[](THRESHOLD);
        for (uint256 i; i < THRESHOLD; ++i) {
            signatures[i] = _sign(attesterKeys[i], digest);
        }
    }

    function _sign(uint256 privateKey, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
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
