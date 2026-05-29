// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title WalrusAnchor
/// @notice Anchors a single Walrus blob ID per EVM address. Off-chain clients
/// fetch the content from a Walrus aggregator using the returned `bytes32`.
/// @dev Walrus blob IDs are exactly 32 bytes (BLAKE2b-256 of the content);
/// `bytes32` keeps the on-chain cost to one SSTORE per anchor regardless of
/// the underlying blob size.
contract WalrusAnchor {
    /// @dev Latest blob anchored by each address. `bytes32(0)` = never anchored.
    mapping(address => bytes32) private _anchors;

    /// @notice Emitted when an address anchors a new blob ID. Both fields are
    /// indexed so off-chain indexers can filter on either dimension.
    event Anchored(address indexed owner, bytes32 indexed blobId);

    /// @notice Anchor `blobId` to msg.sender's slot. Overwrites any previous
    /// anchor. Pass `bytes32(0)` to clear.
    function anchor(bytes32 blobId) external {
        _anchors[msg.sender] = blobId;
        emit Anchored(msg.sender, blobId);
    }

    /// @notice The blob ID anchored by `owner`, or `bytes32(0)` if none.
    function blobOf(address owner) external view returns (bytes32) {
        return _anchors[owner];
    }
}
