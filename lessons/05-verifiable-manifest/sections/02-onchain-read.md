# Section 2 — The on-chain read

You can now turn a `bytes32` blob id into the aggregator URL slug. Next, get the `bytes32` blob id from the on-chain resolver in the first place.

Create `src/manifest.ts`. It will set up the viem `PublicClient`, declare the `walrusBlob` ABI fragment, and expose a `ReadPointer` interface (with a viem-backed default implementation) so tests can inject a stub.

In this section you'll write:

1. The imports — `createPublicClient`, `http`, `namehash`, `type Address` from `viem`; `mainnet` from `viem/chains`; `asciiTrim`, `bytes32ToBase64Url` from `./encoding.ts`.
2. `WALRUS_RESOLVER_ABI` — a const-asserted array literal. Copy verbatim:

   ```ts
   export const WALRUS_RESOLVER_ABI = [
     {
       type: "function",
       name: "walrusBlob",
       stateMutability: "view",
       inputs: [{ name: "node", type: "bytes32" }],
       outputs: [
         { name: "blobId", type: "bytes32" },
         { name: "suiObjectId", type: "bytes32" },
         { name: "contentType", type: "bytes8" },
       ],
     },
   ] as const;
   ```

   The `as const` at the end is critical — see the key moment below.
3. The supporting types:
   ```ts
   export type ResolverTuple = readonly [`0x${string}`, `0x${string}`, `0x${string}`];
   export type ReadPointer = (args: {
     rpcUrl: string;
     resolverAddress: Address;
     node: `0x${string}`;
   }) => Promise<ResolverTuple>;
   ```
4. The default reader:
   ```ts
   export const viemReadPointer: ReadPointer = async ({ rpcUrl, resolverAddress, node }) => {
     const evm = createPublicClient({ chain: mainnet, transport: http(rpcUrl) });
     return (await evm.readContract({
       address: resolverAddress,
       abi: WALRUS_RESOLVER_ABI,
       functionName: "walrusBlob",
       args: [node],
     })) as ResolverTuple;
   };
   ```

No `resolveManifest` function yet — that lands in Sections 3 and 4.

## What you'll write

- `src/manifest.ts` — imports, ABI, types, the `viemReadPointer` default. The file should compile but not export `resolveManifest` yet.

## The key moment

**`WALRUS_RESOLVER_ABI = [...] as const` — the `as const` assertion is what makes viem's `readContract` return the right tuple type instead of `unknown`.**

The difference, in concrete terms:

```ts
// Without `as const`
const ABI_WIDE = [
  {
    type: "function",
    name: "walrusBlob",
    // ...
  },
];

// `readContract<typeof ABI_WIDE>` widens to `readContract<any[]>` —
// return type collapses to `unknown`, no compile-time tuple shape.


// With `as const`
const ABI_NARROW = [
  {
    type: "function",
    name: "walrusBlob",
    // ...
  },
] as const;

// `readContract<typeof ABI_NARROW>` reads the literal-typed fields and
// infers the EXACT tuple: `readonly [\`0x${string}\`, \`0x${string}\`, \`0x${string}\`]`.
```

Without `as const`, the destructuring `[blobId, , contentTypeRaw]` further down compiles, but `blobId` is `unknown`, `contentTypeRaw` is `unknown`, and downstream operations (the `=== ZERO_BLOB` check, the `asciiTrim` call) require explicit casts — and silent type errors become possible (a wrong-type return shape compiles).

The `as const` is the cheapest possible defensive measure: it costs one TypeScript keyword and gives back full inference for every viem read on this ABI. viem's typed ABI inference is one of its standout features, and it's gated entirely on this assertion.

## Verification

Run `pnpm vitest run tests/encoding.test.ts` — encoding tests still pass. The manifest tests can't run yet because `resolveManifest` doesn't exist; the test file won't even import cleanly until Section 4. That's expected; per-section vitest runs become meaningful at the final gate.

Optional: run `pnpm tsc --noEmit` (no script for it, but the project compiles cleanly so far).
