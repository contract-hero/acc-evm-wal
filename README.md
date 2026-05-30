# acc-evm-wal

> Six Walrus × EVM lessons that run inside Claude Code. ACC seeds a Foundry or pnpm workspace, walks you section-by-section through the Solidity and TypeScript, and gates every step on the test suite — 75 passing tests across the course.

**👉 [Read the 2-minute overview](https://contract-hero.github.io/acc-evm-wal/)**

## Install

```text
/plugin marketplace add contract-hero/plugin-marketplace
/plugin install agentic-community-college@contract-hero
/plugin install acc-evm-wal@contract-hero
/acc-evm-wal:start
```

Foundry lessons (01, 03, 04, 06) need `forge` on PATH; TypeScript lessons (02, 05) need `pnpm`. ACC's preflight probes catch either and tell you what to install if missing.

## Lessons

- **`01-walrus-solidity-basics`** — Anchor a Walrus blob ID per EVM address in a 50-line Solidity contract. Three sections, `bytes32` storage, Foundry tests.
- **`02-walrus-sites`** — Port `publish.sh` to TypeScript: validate publish inputs, build the `site-builder` argv, parse the `site_object_id`, then construct the SuiNS link Move call. Replaces the IPNS + Cloudflare gateway stack with one Sui object and one SuiNS transaction.
- **`03-walrus-resolver`** — An ENS-gated on-chain pointer (Solidity). Authorization piggybacks on the ENS registry's owner/operator model; reads cost one `eth_call`. Replaces a DHT round-trip with a single SLOAD.
- **`04-dao-proposals`** — A DAO `Governance` contract whose proposal bodies live on Walrus and whose tallies live on-chain. Includes the flash-loan-vulnerability warning that separates the showcase shape from production-safe.
- **`05-verifiable-manifest`** — The off-chain side of the WalrusResolver pattern (TypeScript). An ENS name in, a typed JSON manifest out: one `eth_call`, one HTTP GET, no IPNS round-trip.
- **`06-quilted-collection`** — A 10 000-token ERC-721 whose metadata + images live in two Walrus Quilts instead of 10 000 IPFS pins. Deterministic `tokenURI`, owner-only aggregator-migration knob.

## Links

- **Landing page** — <https://contract-hero.github.io/acc-evm-wal/>
- **Framework** — [`agentic-community-college`](https://github.com/contract-hero/agentic-community-college)
- **Marketplace** — [`contract-hero/plugin-marketplace`](https://github.com/contract-hero/plugin-marketplace)
- **Reference showcases** — [`MystenLabs/evm-sui`](https://github.com/MystenLabs/evm-sui) — the production-shape source the lessons teach toward
- **Walrus docs** — <https://docs.wal.app>

## For contributors

If you're editing the course itself, see [`CLAUDE.md`](./CLAUDE.md) for the lesson schema, what NOT to add (no MCP/agent code — that's the framework's job), and the per-section authoring flow.

```bash
# Foundry lessons (01, 03, 04, 06)
cd lessons/<slug>/reference-app && forge test

# TypeScript lessons (02, 05)
cd lessons/<slug>/reference-app && pnpm install && pnpm vitest run
```

Don't write lesson files by hand — invoke ACC's `agentic-community-college:lesson-creator` skill instead. It scaffolds the whole `lessons/<slug>/` tree (manifest, sections, tests, artifact, reference-app) against a reference codebase.
