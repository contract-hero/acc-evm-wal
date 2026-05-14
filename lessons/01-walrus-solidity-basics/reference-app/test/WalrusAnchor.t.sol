// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/WalrusAnchor.sol";

// Minimal forge cheatcode interface — saves a `forge install foundry-rs/forge-std`
// step so the lesson is fully offline-runnable. The HEVM cheatcode address is
// a Foundry convention: keccak256("hevm cheat code") truncated to 160 bits.
interface Vm {
    function prank(address sender) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
}

abstract contract MiniTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(bytes32 a, bytes32 b) internal pure {
        require(a == b, "assertEq(bytes32): values differ");
    }
}

contract WalrusAnchorTest is MiniTest {
    WalrusAnchor internal anchorContract;

    event Anchored(address indexed owner, bytes32 indexed blobId);

    function setUp() public {
        anchorContract = new WalrusAnchor();
    }

    function test_anchor_storesBlobIdForCaller() public {
        bytes32 blob = keccak256("walrus-blob-1");
        address alice = address(0xA11CE);

        vm.prank(alice);
        anchorContract.anchor(blob);

        assertEq(anchorContract.blobOf(alice), blob);
    }

    function test_anchor_emitsEvent() public {
        bytes32 blob = keccak256("walrus-blob-2");

        // Check both indexed topics + data; we expect Anchored(this, blob).
        vm.expectEmit(true, true, false, true);
        emit Anchored(address(this), blob);

        anchorContract.anchor(blob);
    }

    function test_anchor_overwritesPrevious() public {
        bytes32 first = keccak256("first");
        bytes32 second = keccak256("second");

        anchorContract.anchor(first);
        anchorContract.anchor(second);

        assertEq(anchorContract.blobOf(address(this)), second);
    }

    function test_blobOf_returnsZeroForUnknown() public view {
        assertEq(anchorContract.blobOf(address(0xBEEF)), bytes32(0));
    }
}
