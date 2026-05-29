# QuiltedCollection — A 10K-Token ERC-721 Backed by Walrus Quilts

A 10 000-token NFT drop on IPFS today is 10 000 separate pinning
operations, 10 000 lifetimes that can independently expire, and a vendor
contract holding the keys to all of them. OpenSea improved metadata
reliability "by 99.2%" when they switched to Pinata — i.e. the
centralization tax for collection drops is enormous because each token
needs its own pin.

Two Walrus Quilts collapse the same drop into two store operations with
deterministic per-file identifiers: one quilt for images, one for
metadata. Per-token: zero pinning ops, zero on-chain state beyond the
ERC-721 ownership records.

In this lesson you'll write `QuiltedCollection.sol` — about 70 lines of
Solidity on top of pre-vendored MiniERC721 / MiniOwnable / MiniStrings
substitutes — covering:

1. **Storage + constructor** — the `quiltId` + `aggregator` strings,
   `maxSupply` immutable, the `_nextTokenId` counter, and the three
   `require` guards (empty-quilt, empty-aggregator, zero-maxSupply).
2. **Self-mint with sequential ids + sold-out cap** — `mint()` returns
   the new id, uses post-increment to start at `1`, and caps with `<=`
   so the (maxSupply+1)-th call reverts.
3. **`tokenURI`** — a pure string-concat that assembles the canonical
   `<aggregator>/v1/blobs/by-quilt-id/<quiltId>/<tokenId>.json` URL. No
   mapping lookup, no per-token state, derivable off-chain.
4. **`setAggregator` migration knob** — owner-only setter that lets the
   collection survive an aggregator-host sunset (testnet → mainnet, host
   shutdown). The quilt itself is content-addressed, so only the URL
   prefix changes.

The reference-app's Foundry test suite (10 tests) is the equivalence gate
— constructor validation, sequential mint ids, sold-out cap, URL shape,
unminted-token revert, owner-only setter, and the aggregator-migration
flow.

The TWO-QUILT story (images + metadata) is the design context but lives
outside the contract: the artist runs `walrus store-quilt` twice and
deploys this contract against the metadata quilt's id. The contract just
serves URLs; the quilts hold the bytes.
