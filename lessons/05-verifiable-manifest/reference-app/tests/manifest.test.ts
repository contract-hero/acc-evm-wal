import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { describe, expect, it } from "vitest";

import {
  resolveManifest,
  resolveTokenList,
  type ReadPointer,
  type HttpGet,
  type UniswapTokenList,
} from "../src/manifest.ts";

const here = dirname(fileURLToPath(import.meta.url));
const tokenListJson = readFileSync(
  join(here, "..", "fixtures", "token-list.json"),
  "utf8",
);

const TEST_BLOB_ID =
  "0x0001020304050607080910111213141516171819202122232425262728293031" as `0x${string}`;
const TEST_SUI = "0xa1b2" as `0x${string}`;
// "app/json" + null padding to bytes8.
const CT_JSON = "0x6170702f6a736f6e" as `0x${string}`;
const CT_UNSET = `0x${"00".repeat(8)}` as `0x${string}`;
const ZERO_BLOB = `0x${"00".repeat(32)}` as `0x${string}`;
const RESOLVER = "0x000000000000000000000000000000000000bead";

const baseOpts = {
  rpcUrl: "http://stub",
  resolverAddress: RESOLVER as `0x${string}`,
  aggregator: "https://aggregator.example",
};

function fakeReadPointer(
  blobId: `0x${string}`,
  contentType: `0x${string}`,
): ReadPointer {
  return async () => [blobId, TEST_SUI, contentType] as const;
}

function fakeHttpGet(body: string, status = 200): HttpGet {
  return async () => ({
    ok: status >= 200 && status < 300,
    status,
    text: async () => body,
  });
}

describe("resolveManifest", () => {
  it("returns the parsed manifest + blobId + trimmed contentType", async () => {
    const result = await resolveManifest<UniswapTokenList>("tokens.demo.eth", {
      ...baseOpts,
      readPointer: fakeReadPointer(TEST_BLOB_ID, CT_JSON),
      httpGet: fakeHttpGet(tokenListJson),
    });
    expect(result.blobId).toBe(TEST_BLOB_ID);
    expect(result.contentType).toBe("app/json");
    expect(result.manifest.name).toBe("Walrus Demo Token List");
    expect(result.manifest.tokens).toHaveLength(3);
  });

  it("builds the aggregator URL with base64url-encoded blob id", async () => {
    let capturedUrl = "";
    const captureGet: HttpGet = async (url) => {
      capturedUrl = url;
      return { ok: true, status: 200, text: async () => tokenListJson };
    };
    await resolveManifest("tokens.demo.eth", {
      ...baseOpts,
      readPointer: fakeReadPointer(TEST_BLOB_ID, CT_JSON),
      httpGet: captureGet,
    });
    expect(capturedUrl).toBe(
      "https://aggregator.example/v1/blobs/AAECAwQFBgcICRAREhMUFRYXGBkgISIjJCUmJygpMDE",
    );
  });

  it("throws when the pointer is unset (zero blobId)", async () => {
    await expect(
      resolveManifest("tokens.demo.eth", {
        ...baseOpts,
        readPointer: fakeReadPointer(ZERO_BLOB, CT_JSON),
        httpGet: fakeHttpGet(tokenListJson),
      }),
    ).rejects.toThrow(/pointer unset/);
  });

  it("throws when contentType isn't JSON", async () => {
    // "text/md" shortcode
    const ctText = "0x746578742f6d6400" as `0x${string}`;
    await expect(
      resolveManifest("tokens.demo.eth", {
        ...baseOpts,
        readPointer: fakeReadPointer(TEST_BLOB_ID, ctText),
        httpGet: fakeHttpGet(tokenListJson),
      }),
    ).rejects.toThrow(/unexpected contentType/);
  });

  it("throws when contentType is empty", async () => {
    await expect(
      resolveManifest("tokens.demo.eth", {
        ...baseOpts,
        readPointer: fakeReadPointer(TEST_BLOB_ID, CT_UNSET),
        httpGet: fakeHttpGet(tokenListJson),
      }),
    ).rejects.toThrow(/unexpected contentType/);
  });

  it("throws when the aggregator returns non-2xx", async () => {
    await expect(
      resolveManifest("tokens.demo.eth", {
        ...baseOpts,
        readPointer: fakeReadPointer(TEST_BLOB_ID, CT_JSON),
        httpGet: fakeHttpGet("not found", 404),
      }),
    ).rejects.toThrow(/aggregator HTTP 404/);
  });

  it("propagates JSON parse errors", async () => {
    await expect(
      resolveManifest("tokens.demo.eth", {
        ...baseOpts,
        readPointer: fakeReadPointer(TEST_BLOB_ID, CT_JSON),
        httpGet: fakeHttpGet("not json {{{"),
      }),
    ).rejects.toThrow(SyntaxError);
  });
});

describe("resolveTokenList", () => {
  it("narrows the return type to UniswapTokenList", async () => {
    const result = await resolveTokenList("tokens.demo.eth", {
      ...baseOpts,
      readPointer: fakeReadPointer(TEST_BLOB_ID, CT_JSON),
      httpGet: fakeHttpGet(tokenListJson),
    });
    // TypeScript-level: result.manifest.tokens[0].symbol must be string.
    expect(result.manifest.tokens[0].symbol).toBe("USDC");
  });
});
