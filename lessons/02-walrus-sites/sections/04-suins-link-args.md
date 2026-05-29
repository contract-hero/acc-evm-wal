# Section 4 — Building the SuiNS link Move call

You have a site object id. To make it resolvable as `<your-name>.wal.app`, you need one more Sui transaction: a Move call that points your SuiNS `NameRegistration` at it.

Create `src/suins-link.ts`. Import the `Network` type from `./publish.ts`.

In this section you'll write:

1. `SUINS_PACKAGE_IDS: Record<Network, \`0x${string}\`>` — the SuiNS package id per network. Use these exact values (they're pinned by the tests so future SuiNS upgrades don't break the lesson):
   - testnet: `0xfdba31b34a43e058f17c5cf4b12d9b9e0a08c0623d8569092c022e0c77df46d3`
   - mainnet: `0xb7004c7914308557f7afbaf0dca8dd258e18e306cb7a45b28019f3d0a693f162`
2. `OBJECT_ID_PATTERN` regex — accepts any `0x` + 1-to-64 hex chars (Sui ids are 32 bytes max, often printed without leading zeros).
3. `buildSetWalrusSiteCall(opts)` — returns `{ target, args }`, where:
   - `target` is `"${pkg}::controller::set_target_walrus_site"`.
   - `args` is the tuple `[nameRegistrationObjectId, siteObjectId]` (in that order).

## What you'll write

- `src/suins-link.ts` — the constants + the one function.

## The key moment

**Return the Move call as data — `{ target, args }` — not as a built `Transaction`.**

Why this matters:

- **No `@mysten/sui` dependency in the lesson.** The transactions builder is the right tool when you're about to sign and submit, but the *shape* of the call (target string + ordered args) is what every caller eventually needs to assemble. Returning the shape as a plain object means the unit test asserts on `call.target` and `call.args` directly — no need to spin up a `Transaction` instance just to inspect it.
- **Two valid call paths, one shape.** Programmatic callers will do `Transaction.moveCall({ target, arguments: args.map(tx.object) })`. Operators will paste the same target + args into `sui client call --package <pkg> --module controller --function set_target_walrus_site --args <name-reg> <site>`. The data form serves both without choosing for them.
- **The arg ORDER is a Move-side ABI invariant.** `set_target_walrus_site` expects the registration first, the site second. Encoding that as a tuple type `readonly [string, string]` rather than an object means TypeScript will catch the swap at compile time if a future refactor changes the field names.

## Verification

Run `pnpm vitest run` from your workspace. All 20 tests across both suites should pass. This is also the lesson's final equivalence gate.
