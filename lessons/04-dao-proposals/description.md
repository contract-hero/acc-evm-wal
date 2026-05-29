# DAO Proposals — Walrus-Backed Bodies, On-Chain Tallies

A 100-line Solidity contract that holds the skeleton of a vote (proposer,
deadline, tallies) while the human-readable proposal body lives on Walrus.
Snapshot uses 4Everland-hosted IPFS today; this pattern moves the body off
the pinning vendor and onto Walrus, with the proposer paying WAL upfront
to a Walrus publisher. The contract never touches WAL. (On testnet the
public publisher accepts uploads without auth; on mainnet there are no
unauthenticated public publishers, so a production DAO would point
proposers at a self-hosted or authenticated publisher.)

In this lesson you'll write `Governance.sol` covering:

1. **Storage + the propose path** — the `Proposal` struct (5 packed-ish
   fields), the proposals + hasVoted mappings, sequential id assignment
   via `++lastProposalId`, and input validation that rejects zero blobIds
   and past deadlines.
2. **Token-weighted voting** — `vote(id, support)`, gated on deadline +
   double-vote protection, weighted by the caller's live `balanceOf`.
3. **The tally view** — `tally(id) returns (yes, no, passed, closed)`
   collapses the storage state into a single read-only call indexers can
   poll cheaply.
4. **The flash-loan warning + production fix** — the showcase's voting
   surface is deliberately minimal and deliberately vulnerable. Section 4
   ships the NatSpec warning at the top of the contract AND walks through
   the one-line substitution (`ERC20Votes.getPastVotes` instead of live
   `balanceOf`) that makes the pattern production-safe.

The reference-app's Foundry test suite (12 tests) is the equivalence gate
— propose validation, sequential id + state isolation between proposals,
vote weighted-tally arithmetic, double-vote rejection, post-deadline
rejection, and the tally state transitions (open / closed-passed /
closed-failed / unknown-id-reverts).

By the end you'll have an on-chain governance primitive that pushes the
mutable body to Walrus, keeps the contract's WAL exposure at zero, and
clearly separates "showcase shape" from "production shape" — so the next
hop is exactly one diff away.
