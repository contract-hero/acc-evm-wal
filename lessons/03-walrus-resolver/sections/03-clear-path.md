# Section 3 — The clear path: `clearWalrusBlob`

Write a function that an authorized caller invokes to remove the pointer entirely.

In this section you'll write:

1. `function clearWalrusBlob(bytes32 node) external` — one argument.

Body:

```solidity
_requireAuthorized(node);
delete _pointers[node];
emit WalrusBlobChanged(node, bytes32(0), bytes32(0), bytes8(0), uint64(block.timestamp));
```

## What you'll write

- `src/WalrusResolver.sol` — add `clearWalrusBlob` below `setWalrusBlob`.

## The key moment

**Why not just call `setWalrusBlob(node, 0, 0, 0)` and be done with it?**

Two reasons, in order of importance:

**1. Intent in the event log.**

Indexers downstream rebuild history by replaying `WalrusBlobChanged` events. A pointer's life is a sequence of state changes:

```
WalrusBlobChanged(node, 0xb10b, 0x5111, "text/md", 1717200000)
WalrusBlobChanged(node, 0xfeed, 0x5111, "text/md", 1717286400)
WalrusBlobChanged(node, 0x0000, 0x0000, 0x0000,    1717372800)  ← cleared
```

Both `setWalrusBlob(node, 0, 0, 0)` and `clearWalrusBlob(node)` emit the same final event. They're *behaviorally* equivalent. But `clearWalrusBlob` is a verb that an end user types; `setWalrusBlob(node, 0, 0, 0)` is a workaround. Surfacing the distinct function in the contract makes the deliberate-clear-vs-accidental-zero question answerable from the function selector alone, which is what wallets and explorers use to render call labels.

**2. `delete _pointers[node]` is cheaper than three `SSTORE`s to zero.**

`delete` on a struct slot triggers a refund for each non-zero slot returning to zero. Since EIP-3529 (London, 2021) that refund is 4,800 gas per cleared slot — down from the pre-London 15,000 — and the total refund is capped at 20% of the transaction's gas used. A self-call to `setWalrusBlob` would add one external call's overhead, run the auth gate twice, and explicitly write the zero values. Using `delete` skips all of that and still collects the (post-3529) refund.

**Bonus subtlety**: the explicit `emit WalrusBlobChanged(node, 0, 0, 0, ...)` is REQUIRED. `delete` zeros storage but doesn't emit anything; indexers would silently miss the clear if you omitted the event.

## Verification

Run `forge build` — the source file should still compile. Two `clearWalrusBlob` tests are queued for the final equivalence gate at Section 4:

- `test_clearWalrusBlob_zerosPointerAndEmits`
- `test_clearWalrusBlob_revertsForUnauthorized`
