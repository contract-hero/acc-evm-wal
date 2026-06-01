# Walrus + Solidity Basics — Anchoring Blob IDs On-Chain

**What you'll build.** A tiny Solidity contract — `WalrusAnchor` — that lets any EVM address publish a single [Walrus](https://www.walrus.xyz/) blob ID as its "current content," and lets anyone look it up by address. Off-chain clients turn the returned 32 bytes into a URL against a Walrus aggregator and fetch the actual bytes from there.

**Why this pattern matters.** Walrus stores the *content*, the EVM contract stores the *pointer*. The on-chain footprint is one `SSTORE` per anchor regardless of how big the underlying blob is — gas stays flat whether the user is anchoring a 1 KB JSON profile or a 100 MB video. The EVM side gives you cheap discovery (events, mappings, ENS-style lookups); Walrus gives you cheap content-addressable storage. Together they're the on-chain/off-chain split most "decentralized content" dApps actually need.

**Prerequisites.**
- Comfortable reading and writing Solidity (`pragma`, `mapping`, `event`, `external`).
- [Foundry](https://getfoundry.sh) installed and on `PATH` (the conductor checks this for you via the `foundry-installed` probe).
- Basic awareness of what content-addressed storage is — Walrus blob IDs are deterministic 32-byte hashes of the content, very similar in spirit to an IPFS CID.

**Environment.** The lesson is fully offline-runnable. The reference app is a self-contained Foundry project that vendors a minimal cheatcode interface in the test file itself — no `forge install`, no network. The only commands the conductor runs in your workspace are Foundry's: `forge build --skip test` while you're building the contract up section by section, then `forge test` for the final equivalence gate.

**The deliverable.** When you reach the final section, `forge test` in your workspace passes the same four-test suite the reference implementation passes. The test suite is the equivalence gate — your code doesn't have to look identical to the reference, it just has to behave like it.

**Estimated time.** 15–25 minutes in `learning` mode (you write the load-bearing pieces yourself). 5–10 minutes in `explanatory` mode (read along).
