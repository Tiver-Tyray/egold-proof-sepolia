// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title E-gold
/// @notice Immutable ERC-20 token backed 1:1 by allocated physical gold.
/// @dev No owner, proxy, upgradeability, pause, freeze, blacklist, clawback, or
/// forced-transfer logic. Mint/burn authority is split between on-chain minters
/// and a fixed threshold of off-chain reserve attesters.
contract EGold is ERC20, AccessControl, EIP712 {
    bytes32 public constant MINTER_ROLE = keccak256("EGOLD_MINTER_ROLE");
    bytes32 public constant RESERVE_ATTESTER_ROLE = keccak256("EGOLD_RESERVE_ATTESTER_ROLE");

    uint8 private constant TOKEN_DECIMALS = 4;

    bytes32 private constant MINT_AUTHORIZATION_TYPEHASH = keccak256(
        "MintAuthorization(address operator,address to,uint256 amount,bytes32 operationId,bytes32 reserveId,bytes32 proofHash,uint256 validAfter,uint256 validBefore,uint256 nonce)"
    );

    bytes32 private constant BURN_AUTHORIZATION_TYPEHASH = keccak256(
        "BurnAuthorization(address operator,address from,uint256 amount,bytes32 operationId,bytes32 reserveId,bytes32 proofHash,uint256 validAfter,uint256 validBefore,uint256 nonce)"
    );

    uint256 public immutable attestationThreshold;
    uint256 public immutable attesterCount;

    mapping(bytes32 digest => bool used) private _authorizationUsed;
    mapping(bytes32 operationId => bool used) private _operationUsed;

    struct MintAuthorization {
        address operator;
        address to;
        uint256 amount;
        bytes32 operationId;
        bytes32 reserveId;
        bytes32 proofHash;
        uint256 validAfter;
        uint256 validBefore;
        uint256 nonce;
    }

    struct BurnAuthorization {
        address operator;
        address from;
        uint256 amount;
        bytes32 operationId;
        bytes32 reserveId;
        bytes32 proofHash;
        uint256 validAfter;
        uint256 validBefore;
        uint256 nonce;
    }

    event ReserveMint(
        address indexed operator,
        address indexed to,
        uint256 amount,
        bytes32 indexed operationId,
        bytes32 reserveId,
        bytes32 proofHash,
        bytes32 digest
    );

    event ReserveBurn(
        address indexed operator,
        address indexed from,
        uint256 amount,
        bytes32 indexed operationId,
        bytes32 reserveId,
        bytes32 proofHash,
        bytes32 digest
    );

    error EmptyMinterSet();
    error EmptyAttesterSet();
    error InvalidThreshold(uint256 threshold, uint256 attesterCount);
    error InvalidAccount(address account);
    error DuplicateAccount(address account);
    error RoleSeparationViolation(address account);
    error InvalidAmount();
    error InvalidOperationId();
    error InvalidReserveId();
    error InvalidProofHash();
    error InvalidValidityWindow();
    error AuthorizationNotActive();
    error InvalidOperator(address expected, address actual);
    error InvalidSignatureCount(uint256 actual, uint256 expected);
    error InvalidAttester(address attester);
    error UnsortedSignatures(address previous, address current);
    error AuthorizationAlreadyUsed(bytes32 digest);
    error OperationAlreadyUsed(bytes32 operationId);
    error RolesAreImmutable();

    constructor(address[] memory initialMinters, address[] memory initialAttesters, uint256 threshold)
        ERC20("E-gold", "EGOLD")
        EIP712("E-gold", "1")
    {
        uint256 minterLength = initialMinters.length;
        uint256 attesterLength = initialAttesters.length;

        if (minterLength == 0) revert EmptyMinterSet();
        if (attesterLength == 0) revert EmptyAttesterSet();
        if (threshold == 0 || threshold > attesterLength) {
            revert InvalidThreshold(threshold, attesterLength);
        }

        _grantImmutableSet(MINTER_ROLE, initialMinters);
        _grantImmutableSet(RESERVE_ATTESTER_ROLE, initialAttesters);
        _enforceRoleSeparation(initialMinters, initialAttesters);

        attestationThreshold = threshold;
        attesterCount = attesterLength;
    }

    function decimals() public pure override returns (uint8) {
        return TOKEN_DECIMALS;
    }

    function authorizationUsed(bytes32 digest) external view returns (bool) {
        return _authorizationUsed[digest];
    }

    function operationUsed(bytes32 operationId) external view returns (bool) {
        return _operationUsed[operationId];
    }

    /// @notice Mints EGOLD after exactly `attestationThreshold` sorted reserve signatures.
    function mint(MintAuthorization calldata auth, bytes[] calldata signatures) external onlyRole(MINTER_ROLE) {
        if (auth.to == address(0)) revert InvalidAccount(auth.to);
        _validateCommonAuthorization(
            auth.operator,
            auth.amount,
            auth.operationId,
            auth.reserveId,
            auth.proofHash,
            auth.validAfter,
            auth.validBefore
        );

        bytes32 digest = hashMintAuthorization(auth);
        _consumeAuthorization(digest, auth.operationId);
        _verifyThresholdSignatures(digest, signatures);

        _mint(auth.to, auth.amount);

        emit ReserveMint(msg.sender, auth.to, auth.amount, auth.operationId, auth.reserveId, auth.proofHash, digest);
    }

    /// @notice Burns EGOLD after exactly `attestationThreshold` sorted redemption signatures.
    /// @dev Burning another account always consumes allowance; burning the minter's
    /// own balance does not. This preserves consent and avoids confiscation power.
    function burnFrom(BurnAuthorization calldata auth, bytes[] calldata signatures) external onlyRole(MINTER_ROLE) {
        if (auth.from == address(0)) revert InvalidAccount(auth.from);
        _validateCommonAuthorization(
            auth.operator,
            auth.amount,
            auth.operationId,
            auth.reserveId,
            auth.proofHash,
            auth.validAfter,
            auth.validBefore
        );

        bytes32 digest = hashBurnAuthorization(auth);
        _consumeAuthorization(digest, auth.operationId);
        _verifyThresholdSignatures(digest, signatures);

        if (auth.from != msg.sender) {
            _spendAllowance(auth.from, msg.sender, auth.amount);
        }

        _burn(auth.from, auth.amount);

        emit ReserveBurn(msg.sender, auth.from, auth.amount, auth.operationId, auth.reserveId, auth.proofHash, digest);
    }

    function hashMintAuthorization(MintAuthorization calldata auth) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    MINT_AUTHORIZATION_TYPEHASH,
                    auth.operator,
                    auth.to,
                    auth.amount,
                    auth.operationId,
                    auth.reserveId,
                    auth.proofHash,
                    auth.validAfter,
                    auth.validBefore,
                    auth.nonce
                )
            )
        );
    }

    function hashBurnAuthorization(BurnAuthorization calldata auth) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    BURN_AUTHORIZATION_TYPEHASH,
                    auth.operator,
                    auth.from,
                    auth.amount,
                    auth.operationId,
                    auth.reserveId,
                    auth.proofHash,
                    auth.validAfter,
                    auth.validBefore,
                    auth.nonce
                )
            )
        );
    }

    function grantRole(bytes32, address) public pure override {
        revert RolesAreImmutable();
    }

    function revokeRole(bytes32, address) public pure override {
        revert RolesAreImmutable();
    }

    function renounceRole(bytes32, address) public pure override {
        revert RolesAreImmutable();
    }

    function _validateCommonAuthorization(
        address operator,
        uint256 amount,
        bytes32 operationId,
        bytes32 reserveId,
        bytes32 proofHash,
        uint256 validAfter,
        uint256 validBefore
    ) private view {
        if (operator != msg.sender) revert InvalidOperator(operator, msg.sender);
        if (amount == 0) revert InvalidAmount();
        if (operationId == bytes32(0)) revert InvalidOperationId();
        if (reserveId == bytes32(0)) revert InvalidReserveId();
        if (proofHash == bytes32(0)) revert InvalidProofHash();
        if (validBefore <= validAfter) revert InvalidValidityWindow();
        if (block.timestamp < validAfter || block.timestamp > validBefore) {
            revert AuthorizationNotActive();
        }
    }

    function _consumeAuthorization(bytes32 digest, bytes32 operationId) private {
        if (_authorizationUsed[digest]) {
            revert AuthorizationAlreadyUsed(digest);
        }
        if (_operationUsed[operationId]) {
            revert OperationAlreadyUsed(operationId);
        }

        _authorizationUsed[digest] = true;
        _operationUsed[operationId] = true;
    }

    function _verifyThresholdSignatures(bytes32 digest, bytes[] calldata signatures) private view {
        uint256 threshold = attestationThreshold;
        if (signatures.length != threshold) {
            revert InvalidSignatureCount(signatures.length, threshold);
        }

        address previousSigner = address(0);

        for (uint256 i; i < threshold;) {
            address signer = ECDSA.recover(digest, signatures[i]);

            if (!hasRole(RESERVE_ATTESTER_ROLE, signer)) {
                revert InvalidAttester(signer);
            }
            if (signer <= previousSigner) {
                revert UnsortedSignatures(previousSigner, signer);
            }

            previousSigner = signer;

            unchecked {
                ++i;
            }
        }
    }

    function _grantImmutableSet(bytes32 role, address[] memory accounts) private {
        uint256 length = accounts.length;

        for (uint256 i; i < length;) {
            address account = accounts[i];
            if (account == address(0)) revert InvalidAccount(account);

            for (uint256 j; j < i;) {
                if (account == accounts[j]) revert DuplicateAccount(account);

                unchecked {
                    ++j;
                }
            }

            _grantRole(role, account);

            unchecked {
                ++i;
            }
        }
    }

    function _enforceRoleSeparation(address[] memory minters, address[] memory attesters) private pure {
        uint256 minterLength = minters.length;
        uint256 attesterLength = attesters.length;

        for (uint256 i; i < minterLength;) {
            address minter = minters[i];

            for (uint256 j; j < attesterLength;) {
                if (minter == attesters[j]) {
                    revert RoleSeparationViolation(minter);
                }

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }
}
