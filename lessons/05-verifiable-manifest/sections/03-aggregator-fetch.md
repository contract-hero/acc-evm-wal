# Section 3 — Aggregator GET + content-type gating

The on-chain read gives you a `bytes32` blob id and a `bytes8` content type. Time to fetch the actual manifest body — guarded so a wrong-type pointer doesn't make it past the network call.

In this section you'll add to `src/manifest.ts`:

1. An `HttpGet` interface for dependency-injected HTTP, plus a default implementation backed by `globalThis.fetch`:

```ts
export type HttpGet = (
  url: string,
) => Promise<{ ok: boolean; status: number; text: () => Promise<string> }>;

export const fetchHttpGet: HttpGet = async (url) => {
  const res = await fetch(url);
  return { ok: res.ok, status: res.status, text: () => res.text() };
};
```

2. The `ResolveOpts` interface — the public input shape:

```ts
export interface ResolveOpts {
  rpcUrl: string;
  resolverAddress: Address;
  aggregator: string;
  readPointer?: ReadPointer;
  httpGet?: HttpGet;
}
```

The two optional fields are the test-injection seams. Production callers use the defaults from Section 2 + this section.

3. A `ZERO_BLOB` constant for the unset-pointer check:

```ts
const ZERO_BLOB = `0x${"00".repeat(32)}` as `0x${string}`;
```

4. A `ResolvedManifest<T>` interface — the return shape (think of `T` as the caller's manifest type):

```ts
export interface ResolvedManifest<T> {
  manifest: T;
  blobId: `0x${string}`;
  contentType: string;
}
```

## What you'll write

- `src/manifest.ts` — the three new types, the default `httpGet`, the `ZERO_BLOB` constant. The actual `resolveManifest` function lands in Section 4 and uses everything you've assembled.

## The key moment

**The content-type check `contentType.startsWith("app/json")` BEFORE the network fetch is the safety gate that keeps a misconfigured pointer from being parsed as JSON downstream.**

Here's the failure mode without the check:

1. An ENS owner sets the resolver pointer to a PNG blob — `blobId = 0x...`, `contentType = "image/p"` (the bytes8 shortcode for `image/png`).
2. Client fetches the bytes — the aggregator returns binary PNG data.
3. Client passes the bytes to `JSON.parse(...)` — throws `SyntaxError: Unexpected token`.

The error is recoverable, but the error MESSAGE is opaque — "Unexpected token `\x89`" tells the caller nothing about why. Worse, with a permissive content-type and a binary payload that happens to start with a valid JSON character (a leading `[` or `{`), `JSON.parse` would return partial garbage instead of failing, and downstream code consuming `result.manifest` gets *almost-valid-shaped junk*.

The pre-fetch check turns the failure mode into a precise error message — `manifest: unexpected contentType "image/p" for tokens.demo.eth` — that:

- Names the field that's wrong (`contentType`).
- Includes its observed value (`"image/p"`).
- Names the ENS pointer (`tokens.demo.eth`).

A caller seeing this error knows exactly which on-chain pointer to inspect. Compare to "Unexpected token `\x89`", which surfaces the SAME root cause but requires bisecting backward from the parse error to the network response to the pointer config.

The grammar — `app/json` as the bytes8 shortcode for `application/json` — is intentional. `application/json` doesn't fit in 8 ASCII bytes, so the resolver contract chose a shortcode form. The client mirrors the choice by matching ONLY the shortcode. Future content types will follow the same `app/...` / `text/...` / `image/...` shortcode grammar.

`startsWith` rather than `===` because the shortcode might be followed by null padding (the on-chain field is right-padded with `0x00`). `asciiTrim` already strips trailing nulls, so `===` would also work in practice — but `startsWith` is forgiving of future shortcode subtypes like `app/json+ld`.

## Verification

Run `pnpm vitest run tests/encoding.test.ts` — encoding tests still pass. The manifest tests still can't run; the test file imports `resolveManifest`, which arrives in Section 4.
