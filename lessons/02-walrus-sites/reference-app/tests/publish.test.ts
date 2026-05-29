import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { describe, expect, it } from "vitest";

import {
  buildPublishArgs,
  parseSiteObjectId,
  validatePublishOpts,
} from "../src/publish.ts";

const here = dirname(fileURLToPath(import.meta.url));
const fixture = readFileSync(join(here, "..", "fixtures", "publish-output.txt"), "utf8");

describe("validatePublishOpts", () => {
  it("accepts a minimal valid opts set with defaults", () => {
    const v = validatePublishOpts({ siteDir: "./out", siteName: "my-site" });
    expect(v).toEqual({
      siteDir: "./out",
      siteName: "my-site",
      epochs: 200,
      network: "testnet",
    });
  });

  it("preserves explicit overrides", () => {
    const v = validatePublishOpts({
      siteDir: "./out",
      siteName: "my.site_01",
      epochs: 50,
      network: "mainnet",
    });
    expect(v.epochs).toBe(50);
    expect(v.network).toBe("mainnet");
  });

  it("rejects empty siteDir", () => {
    expect(() =>
      validatePublishOpts({ siteDir: "", siteName: "ok" }),
    ).toThrow(/siteDir is required/);
  });

  it("rejects siteName with a space", () => {
    expect(() =>
      validatePublishOpts({ siteDir: "./out", siteName: "my site" }),
    ).toThrow(/siteName must match/);
  });

  it("rejects siteName over 64 chars", () => {
    expect(() =>
      validatePublishOpts({ siteDir: "./out", siteName: "a".repeat(65) }),
    ).toThrow(/siteName must match/);
  });

  it("rejects non-integer epochs", () => {
    expect(() =>
      validatePublishOpts({ siteDir: "./out", siteName: "ok", epochs: 1.5 }),
    ).toThrow(/epochs must be a positive integer/);
  });

  it("rejects zero epochs", () => {
    expect(() =>
      validatePublishOpts({ siteDir: "./out", siteName: "ok", epochs: 0 }),
    ).toThrow(/epochs must be a positive integer/);
  });

  it("rejects an unknown network", () => {
    expect(() =>
      validatePublishOpts({
        siteDir: "./out",
        siteName: "ok",
        // @ts-expect-error — intentional invalid input
        network: "devnet",
      }),
    ).toThrow(/network must be one of/);
  });
});

describe("buildPublishArgs", () => {
  it("emits --context before the publish subcommand", () => {
    const args = buildPublishArgs({
      siteDir: "./out",
      siteName: "demo",
      epochs: 200,
      network: "testnet",
    });
    expect(args).toEqual([
      "--context",
      "testnet",
      "publish",
      "./out",
      "--epochs",
      "200",
      "--site-name",
      "demo",
    ]);
  });

  it("threads mainnet + custom epochs into the argv", () => {
    const args = buildPublishArgs({
      siteDir: "./dist",
      siteName: "prod",
      epochs: 1000,
      network: "mainnet",
    });
    expect(args.slice(0, 2)).toEqual(["--context", "mainnet"]);
    expect(args.slice(-4)).toEqual(["--epochs", "1000", "--site-name", "prod"]);
  });
});

describe("parseSiteObjectId", () => {
  it("extracts the 0x id from a realistic site-builder log", () => {
    const id = parseSiteObjectId(fixture);
    expect(id).toBe(
      "0xa1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90",
    );
  });

  it("normalises the id to lowercase", () => {
    const id = parseSiteObjectId("site_object_id: 0xABCDEF12\n");
    expect(id).toBe("0xabcdef12");
  });

  it("throws when no id line is present", () => {
    expect(() => parseSiteObjectId("nothing here\n")).toThrow(
      /could not find 'site_object_id/,
    );
  });

  it("throws when only a partial line is present", () => {
    expect(() => parseSiteObjectId("site_object_id:\n")).toThrow(
      /could not find 'site_object_id/,
    );
  });
});
