// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EGold} from "../src/EGold.sol";

contract EGoldAuthorizationEdgesTest is Test {
    uint256 internal constant MINTER_PK = 0xA11CE;
    uint256 internal constant NON_ATTESTER_PK = 0xBAD;
    uint256 internal constant THRESHOLD = 2;

    EGold internal token;
    address internal minter;
    uint256[] internal attesterKeys;
    address[] internal attesters;

    function setUp() public {
        vm.warp(10_000);
        minter = vm.addr(MINTER_PK);

        attesterKeys.push(0xB0B);
        attesterKeys.push(0xCAFE);
        attesterKeys.push(0xD00D);
        _sortAttesterKeys();

        token = _deploy();
    }

    function testMintAmountNulFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 0, "mint-zero-amount", 1);
        bytes[] memory signatures = _thresholdSignatures(token.hashMintAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.InvalidAmount.selector);
        token.mint(auth, signatures);
    }

    function testMintToZeroAddressFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0), 100_000, "mint-zero-to", 1);
        bytes[] memory signatures = _thresholdSignatures(token.hashMintAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(EGold.InvalidAccount.selector, address(0)));
        token.mint(auth, signatures);
    }

    function testMintOperationIdNulFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-zero-operation", 1);
        auth.operationId = bytes32(0);
        bytes[] memory signatures = _thresholdSignatures(token.hashMintAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.InvalidOperationId.selector);
        token.mint(auth, signatures);
    }

    function testMintReserveIdNulFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-zero-reserve", 1);
        auth.reserveId = bytes32(0);
        bytes[] memory signatures = _thresholdSignatures(token.hashMintAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.InvalidReserveId.selector);
        token.mint(auth, signatures);
    }

    function testMintProofHashNulFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-zero-proof", 1);
        auth.proofHash = bytes32(0);
        bytes[] memory signatures = _thresholdSignatures(token.hashMintAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.InvalidProofHash.selector);
        token.mint(auth, signatures);
    }

    function testMintValidBeforeKleinerOfGelijkAanValidAfterFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-bad-window", 1);
        auth.validBefore = auth.validAfter;
        bytes[] memory signatures = _thresholdSignatures(token.hashMintAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.InvalidValidityWindow.selector);
        token.mint(auth, signatures);
    }

    function testMintVoorValidAfterFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-too-early", 1);
        auth.validAfter = block.timestamp + 1 hours;
        auth.validBefore = block.timestamp + 2 hours;
        bytes[] memory signatures = _thresholdSignatures(token.hashMintAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.AuthorizationNotActive.selector);
        token.mint(auth, signatures);
    }

    function testMintNaValidBeforeFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-expired", 1);
        auth.validAfter = block.timestamp - 2 hours;
        auth.validBefore = block.timestamp - 1 hours;
        bytes[] memory signatures = _thresholdSignatures(token.hashMintAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.AuthorizationNotActive.selector);
        token.mint(auth, signatures);
    }

    function testMintSignatureVanNietAttesterFaalt() public {
        EGold.MintAuthorization memory auth = _mintAuth(address(0xCAFE), 100_000, "mint-non-attester", 1);
        bytes32 digest = token.hashMintAuthorization(auth);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = _sign(NON_ATTESTER_PK, digest);
        signatures[1] = _sign(attesterKeys[0], digest);

        vm.prank(minter);
        vm.expectRevert();
        token.mint(auth, signatures);
    }

    function testMintSignatureVoorGewijzigdeAmountFaalt() public {
        EGold.MintAuthorization memory signedAuth = _mintAuth(address(0xCAFE), 100_000, "mint-change-amount", 1);
        bytes[] memory signatures = _thresholdSignatures(token.hashMintAuthorization(signedAuth));
        signedAuth.amount = 200_000;

        vm.prank(minter);
        vm.expectRevert();
        token.mint(signedAuth, signatures);
    }

    function testMintSignatureVoorGewijzigdeRecipientFaalt() public {
        EGold.MintAuthorization memory signedAuth = _mintAuth(address(0xCAFE), 100_000, "mint-change-recipient", 1);
        bytes[] memory signatures = _thresholdSignatures(token.hashMintAuthorization(signedAuth));
        signedAuth.to = address(0xBEEF);

        vm.prank(minter);
        vm.expectRevert();
        token.mint(signedAuth, signatures);
    }

    function testMintSignatureVoorGewijzigdeOperationIdFaalt() public {
        EGold.MintAuthorization memory signedAuth = _mintAuth(address(0xCAFE), 100_000, "mint-change-operation", 1);
        bytes[] memory signatures = _thresholdSignatures(token.hashMintAuthorization(signedAuth));
        signedAuth.operationId = keccak256("changed-operation");

        vm.prank(minter);
        vm.expectRevert();
        token.mint(signedAuth, signatures);
    }

    function testMintSignatureVoorGewijzigdeProofHashFaalt() public {
        EGold.MintAuthorization memory signedAuth = _mintAuth(address(0xCAFE), 100_000, "mint-change-proof", 1);
        bytes[] memory signatures = _thresholdSignatures(token.hashMintAuthorization(signedAuth));
        signedAuth.proofHash = keccak256("changed-proof");

        vm.prank(minter);
        vm.expectRevert();
        token.mint(signedAuth, signatures);
    }

    function testBurnAmountNulFaalt() public {
        EGold.BurnAuthorization memory auth = _burnAuth(address(0xCAFE), 0, "burn-zero-amount", 1);
        bytes[] memory signatures = _thresholdSignatures(token.hashBurnAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.InvalidAmount.selector);
        token.burnFrom(auth, signatures);
    }

    function testBurnFromZeroAddressFaalt() public {
        EGold.BurnAuthorization memory auth = _burnAuth(address(0), 100_000, "burn-zero-from", 1);
        bytes[] memory signatures = _thresholdSignatures(token.hashBurnAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(EGold.InvalidAccount.selector, address(0)));
        token.burnFrom(auth, signatures);
    }

    function testBurnOperationIdNulFaalt() public {
        EGold.BurnAuthorization memory auth = _burnAuth(address(0xCAFE), 100_000, "burn-zero-operation", 1);
        auth.operationId = bytes32(0);
        bytes[] memory signatures = _thresholdSignatures(token.hashBurnAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.InvalidOperationId.selector);
        token.burnFrom(auth, signatures);
    }

    function testBurnReserveIdNulFaalt() public {
        EGold.BurnAuthorization memory auth = _burnAuth(address(0xCAFE), 100_000, "burn-zero-reserve", 1);
        auth.reserveId = bytes32(0);
        bytes[] memory signatures = _thresholdSignatures(token.hashBurnAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.InvalidReserveId.selector);
        token.burnFrom(auth, signatures);
    }

    function testBurnProofHashNulFaalt() public {
        EGold.BurnAuthorization memory auth = _burnAuth(address(0xCAFE), 100_000, "burn-zero-proof", 1);
        auth.proofHash = bytes32(0);
        bytes[] memory signatures = _thresholdSignatures(token.hashBurnAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.InvalidProofHash.selector);
        token.burnFrom(auth, signatures);
    }

    function testBurnValidBeforeKleinerOfGelijkAanValidAfterFaalt() public {
        EGold.BurnAuthorization memory auth = _burnAuth(address(0xCAFE), 100_000, "burn-bad-window", 1);
        auth.validBefore = auth.validAfter;
        bytes[] memory signatures = _thresholdSignatures(token.hashBurnAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.InvalidValidityWindow.selector);
        token.burnFrom(auth, signatures);
    }

    function testBurnVoorValidAfterFaalt() public {
        EGold.BurnAuthorization memory auth = _burnAuth(address(0xCAFE), 100_000, "burn-too-early", 1);
        auth.validAfter = block.timestamp + 1 hours;
        auth.validBefore = block.timestamp + 2 hours;
        bytes[] memory signatures = _thresholdSignatures(token.hashBurnAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.AuthorizationNotActive.selector);
        token.burnFrom(auth, signatures);
    }

    function testBurnNaValidBeforeFaalt() public {
        EGold.BurnAuthorization memory auth = _burnAuth(address(0xCAFE), 100_000, "burn-expired", 1);
        auth.validAfter = block.timestamp - 2 hours;
        auth.validBefore = block.timestamp - 1 hours;
        bytes[] memory signatures = _thresholdSignatures(token.hashBurnAuthorization(auth));

        vm.prank(minter);
        vm.expectRevert(EGold.AuthorizationNotActive.selector);
        token.burnFrom(auth, signatures);
    }

    function testBurnSignatureVanNietAttesterFaalt() public {
        EGold.BurnAuthorization memory auth = _burnAuth(address(0xCAFE), 100_000, "burn-non-attester", 1);
        bytes32 digest = token.hashBurnAuthorization(auth);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = _sign(NON_ATTESTER_PK, digest);
        signatures[1] = _sign(attesterKeys[0], digest);

        vm.prank(minter);
        vm.expectRevert();
        token.burnFrom(auth, signatures);
    }

    function testBurnSignatureVoorGewijzigdeAmountFaalt() public {
        _mintTo(address(0xCAFE), 300_000, "mint-for-burn-change-amount", 1);
        EGold.BurnAuthorization memory signedAuth = _burnAuth(address(0xCAFE), 100_000, "burn-change-amount", 2);
        bytes[] memory signatures = _thresholdSignatures(token.hashBurnAuthorization(signedAuth));
        signedAuth.amount = 200_000;

        vm.prank(address(0xCAFE));
        token.approve(minter, signedAuth.amount);

        vm.prank(minter);
        vm.expectRevert();
        token.burnFrom(signedAuth, signatures);
    }

    function testBurnSignatureVoorGewijzigdeFromFaalt() public {
        _mintTo(address(0xCAFE), 300_000, "mint-for-burn-change-from", 1);
        EGold.BurnAuthorization memory signedAuth = _burnAuth(address(0xCAFE), 100_000, "burn-change-from", 2);
        bytes[] memory signatures = _thresholdSignatures(token.hashBurnAuthorization(signedAuth));
        signedAuth.from = address(0xBEEF);

        vm.prank(address(0xBEEF));
        token.approve(minter, signedAuth.amount);

        vm.prank(minter);
        vm.expectRevert();
        token.burnFrom(signedAuth, signatures);
    }

    function testBurnSignatureVoorGewijzigdeOperationIdFaalt() public {
        _mintTo(address(0xCAFE), 300_000, "mint-for-burn-change-operation", 1);
        EGold.BurnAuthorization memory signedAuth = _burnAuth(address(0xCAFE), 100_000, "burn-change-operation", 2);
        bytes[] memory signatures = _thresholdSignatures(token.hashBurnAuthorization(signedAuth));
        signedAuth.operationId = keccak256("changed-burn-operation");

        vm.prank(address(0xCAFE));
        token.approve(minter, signedAuth.amount);

        vm.prank(minter);
        vm.expectRevert();
        token.burnFrom(signedAuth, signatures);
    }

    function testBurnReplayFaalt() public {
        address holder = address(0xCAFE);
        _mintTo(holder, 300_000, "mint-for-burn-replay", 1);

        EGold.BurnAuthorization memory auth = _burnAuth(holder, 100_000, "burn-replay", 2);
        bytes32 digest = token.hashBurnAuthorization(auth);
        bytes[] memory signatures = _thresholdSignatures(digest);

        vm.prank(holder);
        token.approve(minter, auth.amount);

        vm.prank(minter);
        token.burnFrom(auth, signatures);

        vm.prank(holder);
        token.approve(minter, auth.amount);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(EGold.AuthorizationAlreadyUsed.selector, digest));
        token.burnFrom(auth, signatures);
    }

    function testBurnOperationIdReplayMetAndereDigestFaalt() public {
        address holder = address(0xCAFE);
        _mintTo(holder, 500_000, "mint-for-burn-operation-replay", 1);

        EGold.BurnAuthorization memory auth = _burnAuth(holder, 100_000, "same-burn-operation", 2);
        bytes32 digest = token.hashBurnAuthorization(auth);

        vm.prank(holder);
        token.approve(minter, auth.amount);

        vm.prank(minter);
        token.burnFrom(auth, _thresholdSignatures(digest));

        EGold.BurnAuthorization memory replay = _burnAuth(holder, 200_000, "same-burn-operation", 3);
        bytes32 replayDigest = token.hashBurnAuthorization(replay);

        vm.prank(holder);
        token.approve(minter, replay.amount);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(EGold.OperationAlreadyUsed.selector, replay.operationId));
        token.burnFrom(replay, _thresholdSignatures(replayDigest));
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
