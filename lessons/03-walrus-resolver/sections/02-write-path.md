# Section 2 — The write path: `setWalrusBlob`

Storage + the auth helper in hand. Now expose the function that an ENS name's owner (or their approved operator) calls to park a Walrus pointer.

In this section you'll write:

1. `function setWalrusBlob(bytes32 node, bytes32 blobId, bytes32 suiObjectId, bytes8 contentType) external` — four args, in that order.

The body is three statements:

```solidity
_requireAuthorized(node);
_pointers[node] = Pointer(blobId, suiObjectId, contentType);
emit WalrusBlobChanged(node, blobId, suiObjectId, contentType, uint64(block.timestamp));
```

That's it. No claim step. No "must set non-zero blob ID" check — passing `bytes32(0)` is a legitimate way to clear via this path, though Section 3's `clearWalrusBlob` makes intent more explicit.

## What you'll write

- `src/WalrusResolver.sol` — add `setWalrusBlob` below `_requireAuthorized`.

## The key moment

**Authorization is the FIRST line of the function. Always.**

Every external mutator on this contract — `setWalrusBlob` here, `clearWalrusBlob` next section — must call `_requireAuthorized(node)` before reading or writing storage. The internal helper exists for one reason: making missing auth visible at code-review time.

Compare two phrasings of the same check:

```solidity
// Phrasing A — inlined
function setWalrusBlob(...) external {
    address nodeOwner = ens.owner(node);
    require(nodeOwner == msg.sender || ens.isApprovedForAll(nodeOwner, msg.sender), "...");
    _pointers[node] = Pointer(blobId, suiObjectId, contentType);
    emit WalrusBlobChanged(...);
}

// Phrasing B — through the helper
function setWalrusBlob(...) external {
    _requireAuthorized(node);
    _pointers[node] = Pointer(blobId, suiObjectId, contentType);
    emit WalrusBlobChanged(...);
}
```

A code reviewer scanning Phrasing B for missing auth scans for `_requireAuthorized` at the top of each external function — three lines per function, one obvious pattern. In Phrasing A the auth check is six syntactic lines mixed with the call's other logic; "is there auth here?" becomes a careful read instead of a glance.

Solidity doesn't have a `[onlyAuthorized]` decorator. The internal helper is the next best thing — a low-overhead convention that makes the "did I auth this?" question answerable in milliseconds. Centralization also means if the auth rule ever changes (say, adding a delegate registry), it changes in one place.

## Verification

Run `forge build` — the source file should still compile. `forge test` won't pass yet because the test file references `walrusBlob` and `supportsInterface` (added in Section 4), so test compilation fails until then. Four `setWalrusBlob` tests are queued up for you to watch land green at the final equivalence gate:

- `test_setWalrusBlob_storesPointerAndEmits`
- `test_setWalrusBlob_revertsForUnauthorized`
- `test_setWalrusBlob_allowsApprovedOperator`
- `test_setWalrusBlob_overwritePicksUpNewENSOwner`

The last one is the punchline: after a simulated ENS ownership transfer, the previous owner is *immediately* locked out — no claim step required.
