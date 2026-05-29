// Pure encoding helpers that bridge the on-chain types (`bytes32`, `bytes8`)
// to their off-chain representations (base64url URL slug, ASCII MIME shortcode).
//
// Lives in its own module because both helpers are testable in isolation and
// independent of any RPC or HTTP machinery — keeping them pure is what lets the
// vitest suite run fully offline.

import { hexToBytes } from "viem";

// Convert a 32-byte hex string to a base64url-encoded Walrus blob id.
// base64url substitutes `-` for `+`, `_` for `/`, and drops the `=` padding.
export function bytes32ToBase64Url(hex: `0x${string}`): string {
  const bytes = hexToBytes(hex, { size: 32 });
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

// Convert a bytes8 hex string to an ASCII shortcode (e.g. "app/json").
// The on-chain field is right-padded with null bytes; everything from the
// first null onward is dropped.
export function asciiTrim(b: `0x${string}`): string {
  const bytes = hexToBytes(b, { size: 8 });
  const end = bytes.indexOf(0);
  const slice = end === -1 ? bytes : bytes.subarray(0, end);
  return new TextDecoder("ascii").decode(slice);
}
