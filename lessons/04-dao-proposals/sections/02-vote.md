# Section 2 — Token-weighted voting

A proposal exists on-chain. Now let token-holders cast yes/no votes weighted by their balance.

In this section you'll write:

1. `function vote(uint256 id, bool support) external` with this body:

```solidity
Proposal storage p = proposals[id];
require(p.deadline != 0, "Governance: unknown proposal");
require(block.timestamp < p.deadline, "Governance: voting closed");
require(!hasVoted[id][msg.sender], "Governance: already voted");

uint256 weight = voteToken.balanceOf(msg.sender);
require(weight > 0, "Governance: zero weight");
require(weight <= type(uint128).max, "Governance: weight overflow");

hasVoted[id][msg.sender] = true;
if (support) {
    p.yes += uint128(weight);
} else {
    p.no += uint128(weight);
}
emit Voted(id, msg.sender, support, weight);
```

Note the use of `Proposal storage p` (not `memory`) — you're WRITING to `p.yes` / `p.no` so the local variable has to be a storage reference, not a value copy.

## What you'll write

- `src/Governance.sol` — add `vote` below `propose`.

## The key moment

**`uint256 weight = voteToken.balanceOf(msg.sender)` is the showcase's load-bearing simplification AND its load-bearing security hazard.**

The simplification: you don't need a separate "delegate weight" step, you don't need to pass an `(address voter, bytes signature)` envelope, you don't need an off-chain vote aggregator. The cast is direct: token-holder + opinion = recorded weight.

The hazard: a live `balanceOf` read at the instant of the call means *whatever the caller's current balance is* counts as their weight. Against most modern ERC-20s integrated with Aave, Solidly, or any DEX with a `flash` hook, that's a vote-override primitive:

```
1. Borrow 10M voteTokens via flash loan.
2. Call vote(id, true).      ← weight: 10M
3. Repay the flash loan in the same transaction.
4. Net cost: a few wei of flash-loan fee.
```

The contract's tally is now permanently skewed by an attacker who held the tokens for one block. Section 4 walks through the exact production fix — a one-line substitution to read a PAST balance instead of the live one.

For this lesson, the simplification stays. The reference-app's mock token deliberately lacks a flash-loan hook so the vote tests pass cleanly. But know it: this contract is a showcase of the Walrus integration shape, not a production governance contract.

### Two smaller subtleties worth catching

- **`weight <= type(uint128).max`** — the Proposal struct stores tallies as `uint128`. Without the upper-bound check, a token with > 2^128 supply could overflow on cast. `require` it explicitly, don't lean on Solidity 0.8's checked arithmetic for boundary safety inside the cast.
- **`hasVoted[id][msg.sender] = true;` BEFORE the tally update** — checks-effects-interactions hygiene. The `balanceOf` call is an external call (could theoretically reenter via a malicious token). Setting `hasVoted` before the tally write means a reentrant `vote(id, ...)` call by the same address would hit the `Governance: already voted` revert.

## Verification

Run `forge build` — the source file should still compile. Several `vote` tests are queued for the final equivalence gate at Section 4:

- `test_vote_addsWeightedTally`
- `test_vote_revertsOnDoubleVote`
- `test_vote_revertsAfterDeadline`
- `test_vote_revertsOnZeroWeight`
