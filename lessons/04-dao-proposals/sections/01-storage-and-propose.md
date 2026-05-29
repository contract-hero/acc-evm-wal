# Section 1 — Proposal storage + the propose path

You're starting from a bare Foundry project. `src/Governance.sol` has the SPDX header, the pragma (`^0.8.24`), and a minimal `IERC20` interface (just `balanceOf`) already declared. Open it.

In this section you'll write:

1. `contract Governance { ... }`.
2. A `Proposal` struct with five fields, in order:
   - `address proposer;`
   - `bytes32 blobId;`
   - `uint64 deadline;`
   - `uint128 yes;`
   - `uint128 no;`
3. `IERC20 public immutable voteToken;` + `uint256 public lastProposalId;`.
4. Two `public` mappings (the lesson uses `public` so the auto-generated getters serve the test suite):
   - `mapping(uint256 id => Proposal) public proposals;`
   - `mapping(uint256 id => mapping(address voter => bool)) public hasVoted;`
5. Two events:
   - `event Proposed(uint256 indexed id, address indexed proposer, bytes32 blobId, uint64 deadline);`
   - `event Voted(uint256 indexed id, address indexed voter, bool support, uint256 weight);`
6. The constructor taking an `IERC20 voteToken_` and storing it.
7. `propose(bytes32 blobId, uint64 deadline) external returns (uint256 id)`:
   - Require `deadline > block.timestamp`, message `"Governance: deadline in past"`.
   - Require `blobId != bytes32(0)`, message `"Governance: zero blobId"`.
   - Assign `id = ++lastProposalId;`.
   - Write the new `Proposal { proposer: msg.sender, blobId, deadline, yes: 0, no: 0 }`.
   - Emit `Proposed(id, msg.sender, blobId, deadline)`.

## What you'll write

- `src/Governance.sol` — the storage layout, the constructor, and `propose`. No `vote` or `tally` yet.

## The key moment

**`uint256 id = ++lastProposalId;` does the assignment AND the storage write in one line, with pre-increment specifically.**

Why pre- (not post-) increment matters here:

- `lastProposalId` starts at `0` (default for an unset `uint256`).
- Pre-increment: `++lastProposalId` increments FIRST, then reads. The first call returns `1`.
- Post-increment would return `0` for the first call and bump the storage to `1` for the next.

The first id being `1` is load-bearing because elsewhere in this contract the existence check is `p.deadline != 0`. If the FIRST proposal could legitimately have id `0`, you couldn't distinguish proposal #0 from a never-touched slot — the test suite's `test_tally_revertsOnUnknownProposal` proves this matters by hitting `gov.tally(999)` and expecting `"Governance: unknown proposal"`.

Pre-incrementing the counter is also one storage write instead of two (vs. the explicit `lastProposalId = lastProposalId + 1; id = lastProposalId`), and reads cleanly: "the next id is one more than the last id, and that's what this proposal gets."

## Verification

Run `forge build` — `src/Governance.sol` should compile cleanly. `forge test` will fail to compile the test file at this point because it references `vote` and `tally` (added in Sections 2 and 3). The final `forge test` equivalence gate runs once the whole contract is in place at Section 4.
