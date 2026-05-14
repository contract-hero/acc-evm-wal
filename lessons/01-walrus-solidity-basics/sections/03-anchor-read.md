# Section 3 — The read path and the equivalence gate

The last piece is the read function:

```solidity
function blobOf(address owner) external view returns (bytes32) {
    return _anchors[owner];
}
```

That's it. No decoding, no aggregation, no events.

## What you'll write

- `src/WalrusAnchor.sol` — append the `blobOf` view function.

## The key moment

**The off-chain client does all the heavy lifting from here.** A frontend's typical flow once `blobOf` exists:

```ts
const blobId = await contract.blobOf(userAddress);   // bytes32 hex
if (blobId === ethers.ZeroHash) return null;          // never anchored

// Convert the 32-byte hex to Walrus's base64url form, then GET the aggregator.
const blobIdB64Url = bytes32ToBase64Url(blobId);      // your helper
const res = await fetch(
  `https://aggregator.walrus-testnet.walrus.space/v1/blobs/${blobIdB64Url}`
);
const content = await res.arrayBuffer();               // the actual bytes
```

The contract returns a *pointer*; the **aggregator** returns the *content*. That split is the entire point of using Walrus + EVM together — the EVM is bad at storing big blobs (it's a global replicated database, every byte costs everyone), and Walrus is bad at access control / ENS-style discovery (it's a flat content-addressed store). Each layer does what it's good at.

A read returns `bytes32(0)` for any address that has never anchored. Tests below assert that.

## Verification

Run `forge test`. You should see four passing tests:

- `test_anchor_storesBlobIdForCaller` — `anchor` writes to the caller's slot.
- `test_anchor_emitsEvent` — `Anchored` event fires with the right indexed args.
- `test_anchor_overwritesPrevious` — second call overwrites the first.
- `test_blobOf_returnsZeroForUnknown` — un-anchored addresses return `bytes32(0)`.

If all four pass, the lesson is complete — your `WalrusAnchor` is behaviorally equivalent to the reference.
