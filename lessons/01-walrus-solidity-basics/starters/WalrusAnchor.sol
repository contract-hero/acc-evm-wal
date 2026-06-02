// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Starting point for the lesson. The SPDX header and pragma are in place;
// everything below is yours to build, one section at a time:
//
//   Section 1 — declare `contract WalrusAnchor`, the per-address
//               `mapping(address => bytes32) private _anchors;`, and the
//               `Anchored(address indexed owner, bytes32 indexed blobId)` event.
//   Section 2 — add the write path: `anchor(bytes32 blobId)`.
//   Section 3 — add the read path: `blobOf(address owner)`.
