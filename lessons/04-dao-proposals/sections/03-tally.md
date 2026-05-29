# Section 3 — The tally view

A single read-only call that collapses a proposal's state into the four things a UI or indexer actually wants: current yes count, current no count, whether voting has closed, and whether (if closed) the proposal passed.

In this section you'll write:

1. `function tally(uint256 id) external view returns (uint128 yes, uint128 no, bool passed, bool closed)`:

```solidity
Proposal storage p = proposals[id];
require(p.deadline != 0, "Governance: unknown proposal");
yes = p.yes;
no = p.no;
closed = block.timestamp >= p.deadline;
passed = closed && yes > no;
```

## What you'll write

- `src/Governance.sol` — add `tally` below `vote`.

## The key moment

**`passed = closed && yes > no` is the order that matters.**

Functionally, `passed = closed && yes > no` is identical to `passed = yes > no && closed`. Both evaluate to the same boolean. But they read differently to someone scanning the contract for the first time, and Solidity is read more often than it's written.

`closed && yes > no` reads as: **"the question 'did it pass?' is only meaningful once voting has closed; if it has, the side with more votes won."** That's the literal user intent. Voting still being open means the answer is "we don't know yet" — and the cheapest expression of "we don't know yet" in a `bool` return is `false`.

`yes > no && closed` reads as: **"is this proposal winning, and incidentally also closed?"** Which is correct, but tilts the mental model toward "checking the running score" instead of "settling a verdict". Indexers polling this function care about the latter.

There's also a short-circuit benefit (free, but real): with `closed && yes > no`, voting-still-open calls skip the comparison entirely. With `yes > no && closed`, every call does the comparison whether or not it matters. Insignificant in gas terms, but Solidity has a tradition of writing the short-circuit so the cheap check goes first; following it makes the code feel canonical.

### Why `tally` exists at all (vs. just reading the public `proposals` mapping)

Solidity auto-generates a getter for the `proposals` mapping. Any caller can do `gov.proposals(id)` and get the five-field tuple back. So `tally` is convenience: it does the `closed` and `passed` derivation in one call, saving the caller two extra calculations. For indexer / UI code that polls every few seconds, that's the call worth optimizing for.

## Verification

Run `forge build` — the source file should still compile. The remaining tally tests run at the final equivalence gate:

- `test_tally_openProposal_isNotClosedNotPassed`
- `test_tally_closedAndFailed_whenNoExceedsYes`
- `test_tally_closedAndPassed_whenYesExceedsNo`
- `test_tally_revertsOnUnknownProposal`
