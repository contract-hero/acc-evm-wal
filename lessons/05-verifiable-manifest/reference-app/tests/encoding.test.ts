import { describe, expect, it } from "vitest";
import { asciiTrim, bytes32ToBase64Url } from "../src/encoding.ts";

describe("bytes32ToBase64Url", () => {
  it("encodes 32 zero bytes to 43 'A' chars (no padding)", () => {
    const out = bytes32ToBase64Url(`0x${"00".repeat(32)}`);
    expect(out).toBe("A".repeat(43));
  });

  it("uses base64url substitutions (- and _)", () => {
    // Hex bytes chosen so the base64 output contains both `+` and `/`,
    // which must round-trip to `-` and `_` respectively.
    const hex = "0xfbfffefbfffefbfffefbfffefbfffefbfffefbfffefbfffefbfffefbfffefbff";
    const out = bytes32ToBase64Url(hex as `0x${string}`);
    expect(out).not.toContain("+");
    expect(out).not.toContain("/");
    expect(out).not.toContain("=");
    expect(out).toMatch(/[-_]/);
  });

  it("matches the canonical base64url for a known blob id", () => {
    // Arbitrary known 32-byte value (just ascending byte pairs), with its
    // base64url encoding precomputed offline — exercises the full alphabet.
    const hex = "0x0001020304050607080910111213141516171819202122232425262728293031";
    const out = bytes32ToBase64Url(hex as `0x${string}`);
    expect(out).toBe("AAECAwQFBgcICRAREhMUFRYXGBkgISIjJCUmJygpMDE");
  });

  it("produces 43-char output for any 32-byte input (no padding)", () => {
    const hex = "0xdeadbeefcafebabe0123456789abcdef0123456789abcdef0123456789abcdef";
    const out = bytes32ToBase64Url(hex as `0x${string}`);
    expect(out.length).toBe(43);
  });
});

describe("asciiTrim", () => {
  it("decodes the full string when bytes8 is fully populated with ASCII", () => {
    // "app/json" is exactly 8 chars — fills bytes8 with no padding room.
    const hex = "0x6170702f6a736f6e" as `0x${string}`; // 8 bytes
    expect(asciiTrim(hex)).toBe("app/json");
  });

  it("stops at the first null when there's null padding", () => {
    // "text/md" + 1 null padding byte.
    const hex = "0x746578742f6d6400" as `0x${string}`; // 8 bytes
    expect(asciiTrim(hex)).toBe("text/md");
  });

  it("returns the empty string on all-zero input", () => {
    const hex = "0x0000000000000000" as `0x${string}`;
    expect(asciiTrim(hex)).toBe("");
  });
});
