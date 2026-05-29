# Section 3 — Parsing site_object_id from stdout

After `site-builder publish` succeeds, it prints a multi-line log to stdout. The line you care about looks exactly like:

```
site_object_id: 0xa1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90
```

Read `fixtures/publish-output.txt` to see what the surrounding noise looks like.

In this section you'll write:

1. A `SITE_OBJECT_ID_PATTERN` regex with the `m` (multiline) flag, anchored on `^\s*site_object_id:\s*(0x[a-fA-F0-9]+)\s*$`.
2. `parseSiteObjectId(stdout: string): \`0x${string}\`` — runs the regex, throws a descriptive error if no match, lowercases the captured hex.

## What you'll write

- `src/publish.ts` — `SITE_OBJECT_ID_PATTERN` and `parseSiteObjectId`.

## The key moment

**Anchor on the line shape, not on greedy text matching.** With the `m` flag, `^` and `$` match line boundaries inside `stdout`. That lets the parser ignore everything around the `site_object_id:` line — the surrounding log can reflow, add timestamps, add color codes, or rearrange entirely, and the parser still finds the id as long as one line still matches the exact shape.

Two specific things this protects against:

- **Upstream log drift.** `site-builder` is an actively-evolving CLI. A future version might wrap the publish summary in a box, prefix every line with a timestamp, or print the id twice (a draft + a confirmation). All three of those keep the line shape intact.
- **JSON-envelope mode.** Some CLI versions emit the same id inside a JSON blob. Line-anchored regex still finds it as long as the JSON is pretty-printed across multiple lines — the line `  "site_object_id": "0x..."` doesn't match (note the JSON quotes around the value), so we'd cleanly fall through to "not found" rather than capturing the wrong substring.

Finally, **lowercase the captured hex**. Sui object ids are case-insensitive on the wire but explorers and SDKs vary in their display preferences. Picking one casing on the way out means downstream code can compare ids with plain `===` instead of `.toLowerCase()` everywhere.

## Verification

Run `pnpm vitest run tests/publish.test.ts -t parseSiteObjectId`. Four tests should pass: realistic-log extraction, lowercase normalisation, "no id line" error, and "partial line" error.
