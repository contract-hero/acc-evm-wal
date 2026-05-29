# Section 4 — The read path + ERC-165 declaration

Two functions left: the view that returns the pointer tuple, and the ERC-165 detection declaration.

In this section you'll write:

1. Change the contract declaration to `contract WalrusResolver is IERC165 { ... }` — implementing the interface you declared in Section 1.
2. `function walrusBlob(bytes32 node) external view returns (bytes32 blobId, bytes32 suiObjectId, bytes8 contentType)` — reads `_pointers[node]` into memory, returns the three fields.
3. `function supportsInterface(bytes4 interfaceId) external pure returns (bool)` — returns `interfaceId == type(IERC165).interfaceId` and NOTHING else.

## What you'll write

- `src/WalrusResolver.sol` — add `walrusBlob` and `supportsInterface`. The contract is now complete.

The read body is the trivial path:

```solidity
Pointer memory p = _pointers[node];
return (p.blobId, p.suiObjectId, p.contentType);
```

`memory` not `storage` — the function returns a flat tuple, not a struct, so loading once into memory + returning the fields is the canonical Solidity pattern.

## The key moment

**`supportsInterface` claims ONLY `type(IERC165).interfaceId`. Specifically NOT the ENS resolver interface ids.**

A naive implementation would have happily added:

```solidity
return interfaceId == type(IERC165).interfaceId
    || interfaceId == 0x3b3b57de    // addr(bytes32)
    || interfaceId == 0xbc1c58d1    // contenthash(bytes32)
    || interfaceId == this.walrusBlob.selector;  // ← also wrong
```

All three of the additions are bugs:

- **`0x3b3b57de` (`addr`) and `0xbc1c58d1` (`contenthash`)** advertise functions this contract doesn't implement. A wallet or indexer that auto-detects "is this an ENS resolver?" via `supportsInterface(0x3b3b57de)` would get `true`, assume `addr(bytes32)` exists, and revert when staticcalling it. Claiming an interface you don't implement is *worse* than not claiming anything.
- **`this.walrusBlob.selector`** is a category confusion. An ERC-165 *interface id* is the XOR of every function selector in the interface. A bare function selector ≠ an interface id; conflating them broke ERC-165 detection for half of NFT marketplaces at one point.

The deliberate minimalism means consumers MUST detect this resolver's surface by direct staticcall to `walrusBlob(bytes32)` — not by ERC-165 round-trip. That's the correct shape: the only thing this contract exposes is `walrusBlob`, so the only way to detect support for it is to call it.

## Verification

Run `forge test` from your workspace. All **8 tests** should pass — this is the lesson's final equivalence gate:

```
test_setWalrusBlob_storesPointerAndEmits
test_setWalrusBlob_revertsForUnauthorized
test_setWalrusBlob_allowsApprovedOperator
test_setWalrusBlob_overwritePicksUpNewENSOwner
test_clearWalrusBlob_zerosPointerAndEmits
test_clearWalrusBlob_revertsForUnauthorized
test_walrusBlob_unsetNodeReturnsZeros
test_supportsInterface_erc165Only
```

The last one specifically pins `addr` (`0x3b3b57de`) and `contenthash` (`0xbc1c58d1`) as MUST-RETURN-FALSE — if your `supportsInterface` returned `true` for any of them, that test catches it.
