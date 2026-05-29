# Verifiable Manifest Client — ENS → Walrus, in One TypeScript Call

You have a `WalrusResolver` contract on EVM (from lesson 03) holding the
pointer for every named manifest. You have a Walrus aggregator serving the
bytes. This lesson builds the off-chain client that turns "I want the
manifest at `tokens.uniswap.eth`" into a typed JSON object — in one async
function call.

It's the missing piece between the on-chain primitive and the dApp that
uses it.

In this lesson you'll write a small TypeScript module covering:

1. **Encoding helpers** — `bytes32 → base64url` (the aggregator URL slug)
   and `bytes8 → ASCII shortcode` (the content-type field). Two pure
   functions, seven tests.
2. **The on-chain read** — a viem `PublicClient` + the `walrusBlob`
   ABI fragment + `namehash` of the ENS name + `readContract`. Default
   `viemReadPointer` lives behind a `ReadPointer` interface so tests can
   inject a fake.
3. **Aggregator GET + content-type gating** — assemble the URL, fetch,
   error on non-2xx, reject anything whose content-type isn't `app/json`.
4. **The generic `resolveManifest<T>` + the typed convenience wrapper** —
   `resolveTokenList = resolveManifest<UniswapTokenList>` shows how to
   specialize the API without writing a new function.

The vitest suite (15 tests across `encoding.test.ts` and `manifest.test.ts`)
is the equivalence gate. It runs fully offline by injecting a fake
`readPointer` and `httpGet` into `resolveManifest` — the viem default is
exercised in production but not in the suite, which keeps the lesson's
red-green loop fast.

By the end you'll have a client function whose call site reads
`await resolveTokenList("tokens.uniswap.eth", opts)` — and a working
understanding of every transformation between the ENS namehash, the
on-chain pointer, the aggregator URL, and the parsed manifest body.
