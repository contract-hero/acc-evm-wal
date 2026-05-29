# Section 4 — `setAggregator` — the sunset-migration knob

The contract is functionally complete after this section: one owner-only setter that lets the collection survive an aggregator-host sunset.

In this section you'll write:

1. The setter:

```solidity
function setAggregator(string calldata newAggregator) external onlyOwner {
    _validateAggregator(bytes(newAggregator));
    emit AggregatorUpdated(aggregator, newAggregator);
    aggregator = newAggregator;
}
```

Note it reuses the SAME `_validateAggregator` helper the constructor calls (Section 1) — so the setter rejects an empty string AND a trailing-slash URL with the identical rule, no copy-paste.

That's the entire change — the contract is now complete.

Two things to note about the function:

- **`calldata` parameter, not `memory`.** `setAggregator` is external — `calldata` is cheaper because it reads the string directly from the call data without copying to memory. Storage writes still copy from calldata to storage word-by-word.
- **`emit ... BEFORE storage write.`** The event captures BOTH the old and new values, so it has to read the old `aggregator` before the new one overwrites it. The order is functionally significant — flipping it would make the event log `oldAggregator == newAggregator` (the new value, in both fields).

## What you'll write

- `src/QuiltedCollection.sol` — add `setAggregator` below `totalMinted`. The contract is now complete.

## The key moment

**`setAggregator` is the ONLY mutable storage slot in this contract after deployment, and that's a deliberate design choice — one knob, one purpose.**

What this knob is FOR:

- **Aggregator host sunsets.** Walrus aggregators are commodity HTTPS endpoints. Anyone can run one — and any specific one can shut down. When the host you launched against announces a sunset, you `setAggregator(newHost)` once and every `tokenURI(id)` in the collection now resolves through the new host. Marketplaces re-fetch and the bytes look the same — Walrus blobs are content-addressed, so a different aggregator returns the same content for the same `<quiltId>/<tokenId>.json` path.
- **Testnet → mainnet promotion.** A collection that launched on testnet (`aggregator.walrus-testnet.walrus.space`) can move to mainnet by updating one field. The quilt content stays the same; the resolver host changes.

What this knob is NOT for:

- **Patching metadata for individual tokens.** That's not what an aggregator does. Aggregators serve the bytes the quilt holds; the quilt itself is immutable. To change a token's metadata you'd need a new quilt — and either a new deployment or a more elaborate redirection scheme.
- **Re-targeting an existing collection at a DIFFERENT quilt.** `quiltId` has no setter. Re-targeting would require a redeployment.

The minimalism is the point. `onlyOwner` gates it — anyone trying without owner rights gets `OwnableUnauthorizedAccount(account)` from the vendored `MiniOwnable`. The `_validateAggregator` call enforces the exact same two rules (non-empty, no trailing slash) the constructor does. The `AggregatorUpdated` event surfaces the change so indexers can re-fetch immediately rather than waiting for cache TTLs to expire.

Some collections add a second knob — `setRoyaltyRecipient`, `setBaseURI`, etc. Resist the urge unless you have a clear "this could plausibly need to move post-deploy" use case. The fewer mutable storage slots a contract has, the more honest its "deploy-once, run-forever" story becomes. For NFT collections specifically, the failure mode of "owner forgot they had a setter and an attacker exploited it" is the entire category that `setAggregator` exemplifies — by being the ONLY one, it's also the one you can fully audit.

## Verification

Run `forge test -vv` from your workspace. All **12 tests** should pass — this is the lesson's final equivalence gate:

```
test_constructor_revertsOnEmptyQuiltId
test_constructor_revertsOnEmptyAggregator
test_constructor_revertsOnAggregatorTrailingSlash
test_constructor_revertsOnZeroMaxSupply
test_mint_assignsSequentialIdsAndEmits
test_mint_capsAtMaxSupply
test_tokenURI_buildsExpectedAggregatorURL
test_tokenURI_revertsForUnmintedToken
test_setAggregator_ownerCanMigrateAggregator
test_setAggregator_revertsForNonOwner
test_setAggregator_revertsOnEmpty
test_setAggregator_revertsOnTrailingSlash
```

The `test_setAggregator_ownerCanMigrateAggregator` test is the punchline: it mints token #1, then changes the aggregator, then re-reads `tokenURI(1)` and confirms the same token's URL now serves through the new host. That's the property the whole `setAggregator` function exists for.
