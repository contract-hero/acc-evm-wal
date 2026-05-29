# Section 4 — The generic `resolveManifest` + the typed wrapper

Everything in place. Now wire it together.

In this section you'll add to `src/manifest.ts`:

1. The `resolveManifest<T>` function:

```ts
export async function resolveManifest<T = unknown>(
  ensName: string,
  opts: ResolveOpts,
): Promise<ResolvedManifest<T>> {
  const readPointer = opts.readPointer ?? viemReadPointer;
  const httpGet = opts.httpGet ?? fetchHttpGet;

  const node = namehash(ensName);
  const [blobId, , contentTypeRaw] = await readPointer({
    rpcUrl: opts.rpcUrl,
    resolverAddress: opts.resolverAddress,
    node,
  });

  if (blobId === ZERO_BLOB) {
    throw new Error(`manifest: pointer unset for ${ensName}`);
  }

  const contentType = asciiTrim(contentTypeRaw);
  if (!contentType.startsWith("app/json")) {
    throw new Error(
      `manifest: unexpected contentType "${contentType}" for ${ensName}`,
    );
  }

  const url = `${opts.aggregator}/v1/blobs/${bytes32ToBase64Url(blobId)}`;
  const res = await httpGet(url);
  if (!res.ok) {
    throw new Error(`manifest: aggregator HTTP ${res.status} for ${url}`);
  }

  const text = await res.text();
  return {
    manifest: JSON.parse(text) as T,
    blobId,
    contentType,
  };
}
```

2. The `UniswapTokenList` interface and the typed wrapper:

```ts
export interface UniswapTokenList {
  name: string;
  timestamp: string;
  tokens: Array<{
    chainId: number;
    address: `0x${string}`;
    symbol: string;
    decimals: number;
    name: string;
    logoURI?: string;
  }>;
}

export const resolveTokenList = (ensName: string, opts: ResolveOpts) =>
  resolveManifest<UniswapTokenList>(ensName, opts);
```

## What you'll write

- `src/manifest.ts` — `resolveManifest`, `UniswapTokenList`, `resolveTokenList`. The module is complete.

## The key moment

**`resolveTokenList = (name, opts) => resolveManifest<UniswapTokenList>(name, opts)` is the cheapest possible typed API surface, and it scales to any number of known manifest shapes.**

The pattern, expanded:

```ts
// Generic — the workhorse.
async function resolveManifest<T = unknown>(...): Promise<ResolvedManifest<T>>;

// Typed convenience wrappers — one per known shape, each one line.
const resolveTokenList = (n, o) => resolveManifest<UniswapTokenList>(n, o);
const resolveDappConfig = (n, o) => resolveManifest<DappConfig>(n, o);
const resolveDaoProfile = (n, o) => resolveManifest<DaoProfile>(n, o);
```

What you get from this shape:

- **Zero runtime overhead.** Each wrapper is a single delegating arrow function — minifies to four tokens after type erasure.
- **Type narrowing at the call site.** `await resolveTokenList("tokens.uniswap.eth", opts)` returns `ResolvedManifest<UniswapTokenList>`. `result.manifest.tokens[0].symbol` is a string at compile time; no inline `<T>` parameter, no manual cast, no `as` assertions in caller code.
- **One source of truth for the runtime behavior.** When you need to change how the pointer is resolved or how the fetch is shaped, you change ONE function. Every typed wrapper inherits the change automatically.
- **Easy extensibility.** Adding support for a new manifest shape is one line — declare the type, add the wrapper. The library author doesn't need to anticipate every shape; downstream consumers can write their own wrappers in their own codebase.

The `<T = unknown>` default on the generic is what lets you call `resolveManifest` directly without a type parameter for ad-hoc cases. `unknown` is the right default because the runtime has no shape information — it's parsed JSON, period; the consumer's `as` cast (or zod schema, or whatever runtime validation they prefer) is what narrows to a specific type.

## Verification

Run `pnpm vitest run` from your workspace. All **15 tests** across both suites should pass — this is the lesson's final equivalence gate:

- `encoding.test.ts` (7 tests): bytes32 → base64url + asciiTrim invariants.
- `manifest.test.ts` (8 tests): the full resolveManifest pipeline against injected fakes, including the unset-pointer error, the unexpected-contentType error, the non-2xx aggregator error, the JSON-parse error, and the typed-wrapper convenience.

The injected `readPointer` and `httpGet` fakes in the test suite are what keep the run offline-runnable — no live RPC, no aggregator round-trip.
