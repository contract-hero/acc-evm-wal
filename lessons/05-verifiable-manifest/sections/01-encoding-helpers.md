# Section 1 — Encoding helpers

The whole client lives between two type boundaries: the EVM's tight, fixed-width on-chain types (`bytes32`, `bytes8`) and the loose off-chain forms (a URL slug, an ASCII string). Two pure helpers handle both crossings — and they live in their own module so the test suite can exercise them in isolation.

Create `src/encoding.ts`. It will import `hexToBytes` from `viem` and export two functions.

In this section you'll write:

1. `bytes32ToBase64Url(hex)` — takes a `` `0x${string}` `` template-literal type, returns a `string`. Converts a 32-byte hex string to a base64url-encoded slug suitable for the Walrus aggregator URL.
2. `asciiTrim(b)` — takes a `` `0x${string}` ``, returns a `string`. Converts a `bytes8` hex value to an ASCII shortcode, stopping at the first null byte (the on-chain field is right-padded with `0x00`).

Suggested bodies:

```ts
import { hexToBytes } from "viem";

export function bytes32ToBase64Url(hex: `0x${string}`): string {
  const bytes = hexToBytes(hex, { size: 32 });
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

export function asciiTrim(b: `0x${string}`): string {
  const bytes = hexToBytes(b, { size: 8 });
  const end = bytes.indexOf(0);
  const slice = end === -1 ? bytes : bytes.subarray(0, end);
  return new TextDecoder("ascii").decode(slice);
}
```

## What you'll write

- `src/encoding.ts` — two functions, both pure, no I/O.

## The key moment

**base64url is NOT base64. The three substitutions on lines 6-9 are the load-bearing transformation.**

The standard Walrus aggregator path is `/v1/blobs/<base64url-encoded-id>`. If you serve the standard `btoa(...)` output verbatim — i.e. base64 — then:

- A `+` in the slug becomes `%2B` after URL-encoding, which the aggregator either rejects or interprets as a different blob id.
- A `/` in the slug is interpreted as a path separator, splitting your blob id across URL segments and returning a 404 for "blob `xyz` not found at path `abc`".
- The `=` padding suffix becomes `%3D` after URL-encoding, again either rejected or misinterpreted.

The substitutions:

| base64 | base64url | why |
|--------|-----------|-----|
| `+`    | `-`       | URL-safe alphabet (RFC 4648 §5) |
| `/`    | `_`       | same |
| `=` (padding) | dropped | URL-safe length is the slug length itself, no padding indicators |

Get any of these wrong by one character and the aggregator silently returns 404 — the test "uses base64url substitutions (- and _)" pins all three substitutions at once by constructing a hex input whose canonical base64 contains both `+` and `/`.

The `asciiTrim` helper has a smaller but related point: the on-chain `bytes8` field is RIGHT-PADDED with null bytes when the shortcode is shorter than 8 chars ("text/md\0" is 7 chars + 1 null). The trim stops at the first null, otherwise the returned string would contain trailing `\0` characters that would compare unequal to a plain string literal.

## Verification

Run `pnpm vitest run tests/encoding.test.ts` from your workspace. All seven encoding tests should pass — four for `bytes32ToBase64Url`, three for `asciiTrim`.
