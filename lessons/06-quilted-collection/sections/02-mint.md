# Section 2 — Self-mint with sequential ids + maxSupply cap

A collector calls `mint()` from their own wallet — the contract pays no special role beyond bookkeeping. No allowlist, no payable, no reveal. Open mint, capped at `maxSupply`.

In this section you'll write:

1. The mint function:

```solidity
function mint() external returns (uint256 tokenId) {
    require(_nextTokenId <= maxSupply, "QuiltedCollection: sold out");
    tokenId = _nextTokenId++;
    _safeMint(msg.sender, tokenId);
    emit Minted(tokenId, msg.sender);
}
```

2. A convenience view that off-chain UIs use to render "X of Y minted":

```solidity
function totalMinted() external view returns (uint256) {
    return _nextTokenId - 1;
}
```

## What you'll write

- `src/QuiltedCollection.sol` — add `mint` and `totalMinted` below the constructor.

## The key moment

**`tokenId = _nextTokenId++;` (post-increment) AND `_nextTokenId <= maxSupply` (with `<=`, not `<`) together produce the exact `[1, maxSupply]` window.**

Two one-character decisions, working together. Let's trace what each one does individually.

**`tokenId = _nextTokenId++;`** — Solidity's post-increment evaluates the expression to the CURRENT value, then bumps storage. So:

- Before first mint: `_nextTokenId == 1` (initialized in Section 1).
- During first mint: `tokenId = 1`, then `_nextTokenId` becomes `2`.
- Before second mint: `_nextTokenId == 2`.
- During second mint: `tokenId = 2`, then `_nextTokenId` becomes `3`.

If you wrote `tokenId = ++_nextTokenId;` (pre-increment) instead:

- Before first mint: `_nextTokenId == 1`.
- During first mint: `_nextTokenId` becomes `2`, `tokenId = 2`.
- First minted token would be `#2`. Token `#1` would never exist.

The `_nextTokenId = 1` initial value combined with post-increment is what makes the first token be `#1`. Both decisions are load-bearing.

**`_nextTokenId <= maxSupply`** — at the start of mint #N, what does `_nextTokenId` hold?

- Mint #1: `_nextTokenId = 1`, gate checks `1 <= maxSupply` ✓
- Mint #2: `_nextTokenId = 2`, gate checks `2 <= maxSupply` ✓
- ...
- Mint #maxSupply: `_nextTokenId = maxSupply`, gate checks `maxSupply <= maxSupply` ✓
- Mint #(maxSupply+1): `_nextTokenId = maxSupply + 1`, gate checks `maxSupply + 1 <= maxSupply` ✗ → revert "sold out"

Using `<` instead would short-circuit on the last legitimate mint. Mint #maxSupply with `<`: `_nextTokenId = maxSupply`, gate `maxSupply < maxSupply` ✗ → reverts. The collection would max out at `maxSupply - 1` tokens.

The off-by-one risk is exactly the kind of thing the test suite pins:

- `test_mint_assignsSequentialIdsAndEmits` verifies the first two mints have ids `1` and `2` (catches pre-increment).
- `test_mint_capsAtMaxSupply` mints exactly `maxSupply` (= 3 in the test setup) successfully and the 4th reverts (catches `<` vs `<=`).

There's a small bonus property here: **the gate is at the function's top, before `_safeMint`'s effects.** If the test caller ran out of gas inside `_safeMint`'s reentrant `onERC721Received` hook, the gate would still have fired first and the state would be consistent. Checks-Effects-Interactions in spirit.

## Verification

Run `forge build` — same situation as Section 1 (compilation still incomplete without `tokenURI`). Section 3 lands the override; the test suite runs at the final gate.
