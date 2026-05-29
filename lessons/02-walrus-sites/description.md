# Walrus Sites — Publishing Frontends as Sui Objects

Static-site hosting for EVM dApps today is a tower of fragile glue: pin to a
paid IPFS provider, expose via a public gateway that may sunset (Cloudflare
did in 2024), then maybe DNSLink your `.eth` to it. Walrus Sites collapses
that stack into one Sui object and one SuiNS transaction.

In this lesson you'll port the shell script `publish.sh` from showcase 02
into a typed TypeScript module that another program can drive — and that a
test suite can actually verify offline. You'll build four small pieces:

1. **`validatePublishOpts`** — turn loose `PublishOpts` into a checked, fully-
   defaulted `ValidatedPublishOpts` so the rest of the pipeline never has to
   guard against bad inputs.
2. **`buildPublishArgs`** — emit the exact argv that `site-builder` expects,
   with `--context <network>` correctly placed as a global flag.
3. **`parseSiteObjectId`** — pluck the Sui object id out of `site-builder`'s
   multi-line stdout, tolerant to upstream log-format drift.
4. **`buildSetWalrusSiteCall`** — construct the SuiNS Move call payload that
   links the new site object to a registered name, returning `{ target, args }`
   that any caller can feed into a `Transaction.moveCall(...)` or
   `sui client call`.

You won't actually shell out to `site-builder` (or sign a Sui transaction):
the lesson's vitest suite runs every function as a pure unit, against a
seeded stdout fixture and known-good Sui object ids. Real publishing happens
afterward, with `site-builder` and a Sui wallet on your own machine.

By the end you'll be able to explain — and test — every step of the
EVM-dApp-frontend → Walrus Site → SuiNS → wal.app pipeline.
