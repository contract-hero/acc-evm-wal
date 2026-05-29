# Governance — reference

A DAO contract that stores the proposal body's Walrus blob id on-chain
alongside the deadline and the vote tallies. The proposer pays the WAL
storage cost to the public Walrus publisher upfront — the contract never
holds WAL.

Build + test:

```bash
forge build
forge test -vv
```

The contract inlines a minimal `IERC20` interface (just `balanceOf`) so the
workspace stays free of OpenZeppelin. The test suite inlines a Foundry
cheatcode interface for the same reason.

⚠️ **Not production-safe.** Voting weight is read live as
`voteToken.balanceOf(msg.sender)` at vote time — flash-loanable. The
showcase is the Walrus-integration shape; the production fix is to switch
the read to `ERC20Votes.getPastVotes(msg.sender, proposalStartBlock)`.
