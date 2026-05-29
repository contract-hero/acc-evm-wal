import { describe, expect, it } from "vitest";

import { buildSetWalrusSiteCall } from "../src/suins-link.ts";

const VALID_NAME_REG =
  "0x1111111111111111111111111111111111111111111111111111111111111111";
const VALID_SITE = "0xa1b2c3d4";

describe("buildSetWalrusSiteCall", () => {
  it("targets the testnet SuiNS controller by default", () => {
    const call = buildSetWalrusSiteCall({
      network: "testnet",
      nameRegistrationObjectId: VALID_NAME_REG,
      siteObjectId: VALID_SITE,
    });

    expect(call.target.endsWith("::controller::set_target_walrus_site")).toBe(true);
    expect(call.args).toEqual([VALID_NAME_REG, VALID_SITE]);
  });

  it("uses the mainnet SuiNS package for network=mainnet", () => {
    const call = buildSetWalrusSiteCall({
      network: "mainnet",
      nameRegistrationObjectId: VALID_NAME_REG,
      siteObjectId: VALID_SITE,
    });
    expect(call.target.startsWith("0xb7004c7914308557f7afbaf0dca8dd258e18e306cb7a45b28019f3d0a693f162::"))
      .toBe(true);
  });

  it("honours an explicit suinsPackageId override", () => {
    const override = "0x9999999999999999999999999999999999999999999999999999999999999999";
    const call = buildSetWalrusSiteCall({
      network: "testnet",
      nameRegistrationObjectId: VALID_NAME_REG,
      siteObjectId: VALID_SITE,
      suinsPackageId: override,
    });
    expect(call.target.startsWith(`${override}::`)).toBe(true);
  });

  it("rejects an invalid nameRegistrationObjectId", () => {
    expect(() =>
      buildSetWalrusSiteCall({
        network: "testnet",
        nameRegistrationObjectId: "not-a-sui-id",
        siteObjectId: VALID_SITE,
      }),
    ).toThrow(/nameRegistrationObjectId/);
  });

  it("rejects an invalid siteObjectId", () => {
    expect(() =>
      buildSetWalrusSiteCall({
        network: "testnet",
        nameRegistrationObjectId: VALID_NAME_REG,
        siteObjectId: "0xZZ",
      }),
    ).toThrow(/siteObjectId/);
  });

  it("preserves the order of args as [name, site]", () => {
    const call = buildSetWalrusSiteCall({
      network: "testnet",
      nameRegistrationObjectId: VALID_NAME_REG,
      siteObjectId: VALID_SITE,
    });
    expect(call.args[0]).toBe(VALID_NAME_REG);
    expect(call.args[1]).toBe(VALID_SITE);
  });
});
