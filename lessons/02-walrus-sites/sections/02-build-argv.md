# Section 2 — Building the site-builder argv

Validated inputs in hand. Now turn them into the exact argv the `site-builder` CLI expects.

In this section you'll write:

1. `buildPublishArgs(opts: ValidatedPublishOpts): string[]` — returns the argv array, in order, ready to feed to `execFile` / `spawn` / `sui client call`-style child-process APIs.

## What you'll write

- `src/publish.ts` — add `buildPublishArgs` below `validatePublishOpts`.

The argv shape is:

```
--context <network>  publish <siteDir>  --epochs <n>  --site-name <name>
```

Eight elements total. The order matters.

## The key moment

**`--context` is a GLOBAL flag on `site-builder`, not a subcommand flag.** Global flags MUST precede the subcommand (`publish`) in the argv. If you put `--context testnet` after `publish`, the CLI parser treats it as a subcommand flag, the subcommand doesn't recognize it, and the run errors out before publishing.

There's a second invariant in the return type: **`string[]`, not a single shell-quoted string.** The caller is expected to feed this directly to `execFile(cmd, args)` or `spawn(cmd, args)` — APIs that pass arguments to the kernel as a flat array, never through a shell. That sidesteps shell injection on the site name automatically: even if your regex from Section 1 missed something, the OS never re-interprets the array elements.

## Verification

Run `pnpm vitest run tests/publish.test.ts -t buildPublishArgs`. Two tests should pass — the canonical argv layout and the mainnet variant. The first test in particular pins the exact array shape; if your output is reordered, that's the failure to look at.
