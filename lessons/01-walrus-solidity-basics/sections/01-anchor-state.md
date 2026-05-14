# Section 1 — Anchor state

We're starting from a bare Foundry project. The only file under `src/` is `WalrusAnchor.sol` with the SPDX header and pragma already in place. Open it.

In this section you'll declare:

1. The contract itself: `contract WalrusAnchor { ... }`.
2. A private state mapping that maps each address to the **single most recent** Walrus blob ID they've anchored: `mapping(address => bytes32) private _anchors;`.
3. An event that off-chain indexers (subgraphs, simple ethers listeners) can use to follow new anchors as they happen: `event Anchored(address indexed owner, bytes32 indexed blobId);`.

## What you'll write

- `src/WalrusAnchor.sol` — just the three things above; no functions yet.

## The key moment

**Pick `bytes32`, not `string`, not `bytes`, for the blob ID.** A Walrus blob ID is the BLAKE2b-256 hash of the blob's content, encoded as base64url for display but always exactly 32 raw bytes on the wire. Storing it as `bytes32`:

- Fits in **one** storage word → one `SSTORE` per anchor → ~22k gas, flat for any blob size.
- Stays comparable in a single EVM word (cheap equality checks downstream).
- Is `indexed`-able in events, so off-chain indexers can filter `Anchored(_, <blobId>)` without scanning every log.

Using `string` would store the base64url representation (~44 chars) as a length-prefixed byte array — at least two storage slots per anchor and much more expensive log filtering. The off-chain client (not the contract) is the right place to do the `bytes32 ↔ base64url` conversion.

## Verification

Run `forge build` from your workspace. It should compile with no warnings. (`forge test` will still report 0 tests passing — that's expected; we haven't written the functions yet.)
