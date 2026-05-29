# Section 3 — `tokenURI` building the deterministic aggregator URL

The override that turns a `tokenId` into the canonical Walrus aggregator URL for that token's metadata. No mapping lookup, no per-token state.

In this section you'll write:

1. The `tokenURI` override:

```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory) {
    _requireOwned(tokenId);
    return string.concat(
        aggregator,
        "/v1/blobs/by-quilt-id/",
        quiltId,
        "/",
        tokenId.toString(),
        ".json"
    );
}
```

`_requireOwned` is the `MiniERC721` helper from `src/lib/`. It reverts if the token id has never been minted, which is the ERC-721 contract's behavior — `tokenURI` for an unminted token is undefined.

## What you'll write

- `src/QuiltedCollection.sol` — add `tokenURI` below `totalMinted`. The contract should now compile cleanly.

## The key moment

**`tokenURI` is a PURE STRING-CONCAT — no SLOAD other than the two storage strings, no mapping lookup, no per-token state.**

Look at what's NOT here:

- No `mapping(uint256 => string) private _tokenURIs` — which is the textbook ERC-721 approach.
- No per-token field on a struct.
- No call to `_baseURI()` returning a per-collection prefix that's still backed by storage.

What IS here:

- Two storage reads — `aggregator` and `quiltId` — both shared by every token in the collection.
- One arithmetic conversion — `tokenId.toString()` — which is gas-free in view-call terms.
- Six `string.concat` arguments — `string.concat` is a Solidity 0.8.12+ feature that emits efficient memory-copy bytecode.

The URL shape is uniform across every token:

```
<aggregator>/v1/blobs/by-quilt-id/<quiltId>/<tokenId>.json
```

The only thing that differs per-token is the decimal id at the end. Which means:

- **Off-chain URL derivation is RPC-free.** A wallet or marketplace that knows `aggregator` and `quiltId` (one Etherscan lookup at deploy time) can compute every token's URL with no eth_call per render. Compare to IPFS-pinned collections where the marketplace either does one eth_call per token or trusts an indexer's cache.
- **Storage cost is O(1) per collection, not O(n) per token.** A 10 000-token IPFS-pinned collection would store 10 000 CID strings; this one stores two strings.
- **Migrating the canonical aggregator (Section 4) shifts EVERY token's URL** in one transaction. Same shape, same per-token suffix, different prefix.

The trade-off you make to get all of this: per-token metadata is fixed at quilt-pack time. You can't issue a metadata patch for token #42 — you'd have to repack the whole metadata quilt and either redeploy or migrate aggregators to a new resolver serving the patched quilt. For a launch drop where metadata is canonical, this is a feature; for protocols that need mutable per-token state (revealable traits, level-up systems), it isn't.

`_requireOwned(tokenId)` is the small but important guard at the top. Without it, `tokenURI(999)` for an unminted token would silently return a valid-looking URL pointing at a quilt entry that probably doesn't exist. The aggregator would 404, but the contract would have appeared to confirm the token exists. `_requireOwned` is the ERC-721 standard's defense against that confusion.

## Verification

Run `forge build` — the contract should now compile cleanly. `forge test` will fail at the **compile** step (not the run step), because the test file references `c.setAggregator(...)` in three functions and that method lands in Section 4. Solidity compiles `test/QuiltedCollection.t.sol` as a unit, so the whole file fails to compile until Section 4 ships `setAggregator`.

Two `tokenURI` tests are queued for the final equivalence gate at Section 4:

- `test_tokenURI_buildsExpectedAggregatorURL`
- `test_tokenURI_revertsForUnmintedToken`
