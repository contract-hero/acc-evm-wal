# Section 1 — Validating publish inputs

You're starting from a bare TypeScript module. Open `src/publish.ts`. It already exports a few types you'll fill in.

In this section you'll write:

1. A `SITE_NAME_PATTERN` regex that constrains the human-readable site label to filename-safe characters.
2. A `NETWORKS` tuple — exactly `["testnet", "mainnet"]` — exported as the `Network` union type.
3. A `validatePublishOpts(opts)` function that takes loose `PublishOpts` and returns a fully-defaulted `ValidatedPublishOpts`. It applies defaults (`epochs: 53`, `network: "testnet"`) and throws a descriptive `Error` on every invalid field — including `epochs` that aren't positive integers AND `epochs` greater than the Walrus maximum of **53** (defined as a `MAX_EPOCHS = 53` constant). Walrus rejects a store longer than 53 epochs (~2 years) at the network, so catching it here turns a confusing CLI failure into a clear local error.

## What you'll write

- `src/publish.ts` — the three exports above. No CLI invocation yet, no parsing yet.

Note: `tests/publish.test.ts` imports `buildPublishArgs` and `parseSiteObjectId` at the top of the file. Until you write them in Sections 2 and 3, also add throwing stubs so the test file loads cleanly: `export function buildPublishArgs(_: ValidatedPublishOpts): string[] { throw new Error("TODO section 2"); }` and the same shape for `parseSiteObjectId`.

## The key moment

**The site-name regex is a conservative-shell-safety hat, not a `site-builder` constraint.** `site-builder` itself accepts almost anything as a site name. But the name flows through:

- The bash wrapper that produced this script — quoting is its problem if names contain spaces.
- CI logs — control chars or hostile unicode would mangle the output.
- The Sui object that gets created — its `name` field becomes part of every explorer's display.
- A SuiNS link, eventually — names that look hostile encourage phishing copy-paste mistakes.

Restricting to `[A-Za-z0-9._-]{1,64}` is what makes each stage of that pipeline safe to log, copy, and read aloud. The regex isn't deep cryptography — it's a hygiene check that has to land here because no later stage will redo it.

## Verification

Run `pnpm vitest run tests/publish.test.ts -t validatePublishOpts` from your workspace. All ten `validatePublishOpts` tests should pass. The `buildPublishArgs` and `parseSiteObjectId` tests will still fail — that's expected; you haven't written those functions yet.
