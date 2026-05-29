# Section 4 — The flash-loan warning + the production fix

The contract is functionally complete. Before running the equivalence gate, add the NatSpec warning that names the contract's deliberate limitation, and understand the one-substitution fix that turns the showcase shape into a production-safe shape.

In this section you'll write:

1. The contract-level `///` NatSpec block ABOVE `contract Governance {` — copy the block below verbatim. It's part of the source and the test suite doesn't check it, but shipping the contract without it would misrepresent the showcase's intent.

```solidity
/// DAO governance with proposal bodies on Walrus.
///
/// The proposal body (markdown / JSON / whatever the DAO renders) lives on
/// Walrus as a single blob. The proposer pays the WAL storage cost via the
/// public Walrus publisher — the DAO contract is not on the WAL hook. The
/// 32-byte Walrus blob id is stored on-chain alongside the deadline and the
/// vote tallies.
///
/// WARNING — NOT PRODUCTION-SAFE AS WRITTEN.
/// Voting weight is read as the live `voteToken.balanceOf(msg.sender)` at
/// the instant of the `vote()` call. If `voteToken` supports flash loans
/// or flash mints, an attacker can borrow tokens, vote, and repay in a
/// single transaction — overriding any honest tally. This contract is a
/// showcase of the *Walrus integration shape* (proposer-pays blob storage,
/// on-chain pointer, deterministic resolution) and deliberately keeps the
/// voting surface minimal.
///
/// For production, pair this with an OpenZeppelin `ERC20Votes` token,
/// store the proposal's start block in `Proposal`, and read voting weight
/// via `IVotes(voteToken).getPastVotes(msg.sender, proposalStartBlock)`.
```

## What you'll write

- `src/Governance.sol` — the NatSpec block. That's the last edit. The contract is now complete.

## The key moment

**The showcase → production path is one substitution: `voteToken.balanceOf(msg.sender)` → `IVotes(voteToken).getPastVotes(msg.sender, p.startBlock)`.**

Why a past-balance snapshot is flash-loan-immune:

- `getPastVotes(account, blockNumber)` returns the account's delegated voting power **at the given block**. The block number is in the past (it's the proposal's `startBlock`, set at `propose` time).
- A flash loan is, by definition, a transaction that borrows + returns in the same block. There is no transaction the attacker can issue *now* that retroactively gives them tokens at block N (where N is already mined).
- So a past-snapshot read is unforgeable by any present-time action: by the time the attacker's flash-loan tx executes, the snapshot block is already history.

The production-shape diff in concrete terms:

```solidity
// Showcase (this contract)
struct Proposal {
    address proposer;
    bytes32 blobId;
    uint64 deadline;
    uint128 yes;
    uint128 no;
}

// In vote():
uint256 weight = voteToken.balanceOf(msg.sender);


// Production
struct Proposal {
    address proposer;
    bytes32 blobId;
    uint64 deadline;
    uint128 yes;
    uint128 no;
    uint48 startBlock;          // ← new
}

// In propose():
proposals[id].startBlock = uint48(block.number);

// In vote():
uint256 weight = IVotes(address(voteToken)).getPastVotes(msg.sender, p.startBlock);
```

One field added to `Proposal`, one field set in `propose`, one call substituted in `vote`. The Walrus integration shape — proposer-pays publisher PUT, on-chain pointer, aggregator GET — is unchanged.

The lesson is the SEPARATION of concerns: a single contract can demonstrate the Walrus integration cleanly OR demonstrate production-safe voting cleanly, but combining both would have buried the Walrus payload pattern in OpenZeppelin scaffolding. The warning makes the boundary explicit so the next implementer doesn't accidentally inherit the wrong shape.

**The flash-loan snapshot is necessary, not sufficient.** Past-balance voting closes the flash-loan hole, but a production DAO still needs several things this showcase deliberately omits — don't ship the simplified shape thinking the snapshot alone makes it safe:

- **Quorum** — a minimum total weight that must participate, so a proposal can't pass on one voter while everyone else is asleep. This showcase's `tally` calls a proposal `passed` on any `yes > no`.
- **Proposal threshold** — a minimum balance to *create* a proposal, to stop spam. Here anyone can `propose`.
- **Voting delay + timelock** — a delay between proposal creation and voting (so the snapshot block is settled and voters can react) and a delay between a passed vote and execution (so users can exit before a malicious change lands). These are a SEPARATE concern from the flash-loan fix — a timelock does not prevent flash-loan voting, and a snapshot does not give users an exit window. OpenZeppelin's `Governor` + `TimelockController` provide both.

OpenZeppelin's `Governor` module composes all of these; reach for it rather than hand-rolling once you're past the showcase.

## Verification

Run `forge test` from your workspace. All **12 tests** should pass — this is the lesson's final equivalence gate:

```
test_propose_storesProposalAndEmits
test_propose_secondCall_assignsSequentialIdAndIndependentStorage
test_propose_revertsOnPastDeadline
test_propose_revertsOnZeroBlob
test_vote_addsWeightedTally
test_vote_revertsOnDoubleVote
test_vote_revertsAfterDeadline
test_vote_revertsOnZeroWeight
test_tally_openProposal_isNotClosedNotPassed
test_tally_closedAndFailed_whenNoExceedsYes
test_tally_closedAndPassed_whenYesExceedsNo
test_tally_revertsOnUnknownProposal
```
