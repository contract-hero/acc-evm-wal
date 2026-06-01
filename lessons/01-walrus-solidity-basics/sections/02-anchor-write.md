# Section 2 — The write path

Now we add the only mutating function the contract needs:

```solidity
function anchor(bytes32 blobId) external {
    _anchors[msg.sender] = blobId;
    emit Anchored(msg.sender, blobId);
}
```

Two lines. That's the whole on-chain write path.

## What you'll write

- `src/WalrusAnchor.sol` — append the `anchor` function inside the contract.

## The key moment

**Use `msg.sender` as the mapping key — not a function parameter.** A naive first version might take an `address owner` parameter:

```solidity
// DON'T do this.
function anchor(address owner, bytes32 blobId) external {
    _anchors[owner] = blobId;
    emit Anchored(owner, blobId);
}
```

That signature lets anyone overwrite anyone else's anchor — Bob can call `anchor(alice, junkBlob)` and Alice's profile lookup will now return Bob's junk. To make it safe you'd have to add `require(msg.sender == owner, "not owner")`, which is just `msg.sender` written the long way around.

By keying the mapping on `msg.sender` directly, the EVM does the authentication for free: by the time the function runs, the EVM has already verified the transaction's signature against `msg.sender`. **No explicit `require`, no way to spoof.**

The "overwrite previous" behavior is intentional — each address has one "current" anchor, like a Twitter bio. If you wanted history, you'd push to an array (and pay for the extra storage per write); if you wanted append-only, you'd use a content-addressed mapping keyed on the blob ID itself. This lesson teaches the simplest case.

## Verification

`forge build --skip test` should still compile clean. The full `forge test` suite runs in the next section — once `blobOf` exists, the vendored tests can finally compile and we exercise both the write and the read paths.
