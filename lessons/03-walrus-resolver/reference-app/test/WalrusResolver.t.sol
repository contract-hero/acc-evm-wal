// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {WalrusResolver, IENS, IERC165} from "../src/WalrusResolver.sol";

// Minimal forge cheatcode interface — keeps the workspace offline-runnable
// (no `forge install foundry-rs/forge-std`). The cheatcode address is a
// Foundry convention: keccak256("hevm cheat code") truncated to 160 bits.
interface Vm {
    function prank(address sender) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
    function expectRevert(bytes calldata revertData) external;
}

abstract contract MiniTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // Type-suffixed asserts. Solidity 0.8 can't always disambiguate an
    // assertEq overload set when arguments come from tuple destructuring,
    // so we name each variant explicitly. forge-std uses the same trick
    // internally for the same reason.
    function assertEqBytes32(bytes32 a, bytes32 b) internal pure {
        require(a == b, "assertEqBytes32: values differ");
    }
    function assertEqBytes8(bytes8 a, bytes8 b) internal pure {
        require(a == b, "assertEqBytes8: values differ");
    }
    function assertEqAddress(address a, address b) internal pure {
        require(a == b, "assertEqAddress: values differ");
    }
    function assertTrue(bool c) internal pure {
        require(c, "assertTrue: condition is false");
    }
    function assertFalse(bool c) internal pure {
        require(!c, "assertFalse: condition is true");
    }
}

/// In-memory ENS registry stub. Mirrors the two methods WalrusResolver depends on.
contract MockENS is IENS {
    mapping(bytes32 => address) public owners;
    mapping(address => mapping(address => bool)) public operators;

    function setOwner(bytes32 node, address owner_) external {
        owners[node] = owner_;
    }

    function setApprovalForAll(address operator, bool approved) external {
        operators[msg.sender][operator] = approved;
    }

    function owner(bytes32 node) external view returns (address) {
        return owners[node];
    }

    function isApprovedForAll(address owner_, address operator) external view returns (bool) {
        return operators[owner_][operator];
    }
}

contract WalrusResolverTest is MiniTest {
    WalrusResolver internal resolver;
    MockENS internal ens;

    address internal vitalik = address(0xC1FA11);
    address internal mallory = address(0xBAD);
    address internal operator_ = address(0x0BEC);

    bytes32 internal node = keccak256("blog.vitalik.eth");
    bytes32 internal blobId = bytes32(uint256(0xB10B));
    bytes32 internal suiObjectId = bytes32(uint256(0x5111));
    bytes8 internal ct = bytes8("text/md");

    event WalrusBlobChanged(
        bytes32 indexed node,
        bytes32 blobId,
        bytes32 suiObjectId,
        bytes8 contentType,
        uint64 at
    );

    function setUp() public {
        ens = new MockENS();
        resolver = new WalrusResolver(IENS(address(ens)));
        ens.setOwner(node, vitalik);
    }

    function test_setWalrusBlob_storesPointerAndEmits() public {
        vm.expectEmit(true, false, false, true);
        emit WalrusBlobChanged(node, blobId, suiObjectId, ct, uint64(block.timestamp));

        vm.prank(vitalik);
        resolver.setWalrusBlob(node, blobId, suiObjectId, ct);

        (bytes32 b, bytes32 s, bytes8 c) = resolver.walrusBlob(node);
        assertEqBytes32(b, blobId);
        assertEqBytes32(s, suiObjectId);
        assertEqBytes8(c, ct);
    }

    function test_setWalrusBlob_revertsForUnauthorized() public {
        vm.prank(mallory);
        vm.expectRevert(bytes("WalrusResolver: not authorized"));
        resolver.setWalrusBlob(node, blobId, suiObjectId, ct);
    }

    function test_setWalrusBlob_revertsForUnownedNode() public {
        // A node nobody owns (registry returns address(0)) must be rejected
        // before the approval check — no caller is authorized over it.
        bytes32 orphan = keccak256("never.registered.eth");
        vm.prank(mallory);
        vm.expectRevert(bytes("WalrusResolver: node has no owner"));
        resolver.setWalrusBlob(orphan, blobId, suiObjectId, ct);
    }

    function test_setWalrusBlob_allowsApprovedOperator() public {
        vm.prank(vitalik);
        ens.setApprovalForAll(operator_, true);

        vm.prank(operator_);
        resolver.setWalrusBlob(node, blobId, suiObjectId, ct);

        (bytes32 b, , ) = resolver.walrusBlob(node);
        assertEqBytes32(b, blobId);
    }

    function test_setWalrusBlob_overwritePicksUpNewENSOwner() public {
        vm.prank(vitalik);
        resolver.setWalrusBlob(node, blobId, suiObjectId, ct);

        address newOwner = address(0xCAFE);
        ens.setOwner(node, newOwner);

        vm.prank(vitalik);
        vm.expectRevert(bytes("WalrusResolver: not authorized"));
        resolver.setWalrusBlob(node, bytes32(uint256(0xDEAD)), suiObjectId, ct);

        bytes32 nextBlob = bytes32(uint256(0xFEED));
        vm.prank(newOwner);
        resolver.setWalrusBlob(node, nextBlob, suiObjectId, ct);

        (bytes32 b, , ) = resolver.walrusBlob(node);
        assertEqBytes32(b, nextBlob);
    }

    function test_clearWalrusBlob_zerosPointerAndEmits() public {
        vm.prank(vitalik);
        resolver.setWalrusBlob(node, blobId, suiObjectId, ct);

        vm.expectEmit(true, false, false, true);
        emit WalrusBlobChanged(node, bytes32(0), bytes32(0), bytes8(0), uint64(block.timestamp));

        vm.prank(vitalik);
        resolver.clearWalrusBlob(node);

        (bytes32 b, bytes32 s, bytes8 c) = resolver.walrusBlob(node);
        assertEqBytes32(b, bytes32(0));
        assertEqBytes32(s, bytes32(0));
        assertEqBytes8(c, bytes8(0));
    }

    function test_clearWalrusBlob_revertsForUnauthorized() public {
        vm.prank(mallory);
        vm.expectRevert(bytes("WalrusResolver: not authorized"));
        resolver.clearWalrusBlob(node);
    }

    function test_walrusBlob_unsetNodeReturnsZeros() public view {
        bytes32 untouched = keccak256("never.set.eth");
        (bytes32 b, bytes32 s, bytes8 c) = resolver.walrusBlob(untouched);
        assertEqBytes32(b, bytes32(0));
        assertEqBytes32(s, bytes32(0));
        assertEqBytes8(c, bytes8(0));
    }

    function test_supportsInterface_erc165Only() public view {
        assertTrue(resolver.supportsInterface(type(IERC165).interfaceId));
        // Not a full ENS resolver — must NOT advertise resolver-record interfaces.
        assertFalse(resolver.supportsInterface(0x3b3b57de)); // addr(bytes32)
        assertFalse(resolver.supportsInterface(0xbc1c58d1)); // contenthash(bytes32)
        assertFalse(resolver.supportsInterface(0xdeadbeef));
    }
}
