/**
 * Build the SuiNS "set Walrus Site" Move call payload — without sending it.
 *
 * A SuiNS NameRegistration object holds one walrus-site pointer at a time;
 * linking is one Sui transaction calling the SuiNS package's
 * `controller::set_target_walrus_site` (testnet/mainnet share the entry shape,
 * the package id differs). Producing the call payload as data — target +
 * args, no PTB builder — makes the lesson testable without bringing in
 * `@mysten/sui` as a dependency.
 *
 * Callers either feed this into `Transaction.moveCall(...)` from
 * `@mysten/sui/transactions` or hand it to `sui client call`.
 */

import type { Network } from "./publish.ts";

const SUINS_PACKAGE_IDS: Record<Network, `0x${string}`> = {
  testnet:
    "0xfdba31b34a43e058f17c5cf4b12d9b9e0a08c0623d8569092c022e0c77df46d3",
  mainnet:
    "0xb7004c7914308557f7afbaf0dca8dd258e18e306cb7a45b28019f3d0a693f162",
};

const OBJECT_ID_PATTERN = /^0x[a-fA-F0-9]{1,64}$/;

export interface SuinsLinkOpts {
  network: Network;
  /** Sui object id of the NameRegistration the caller owns. */
  nameRegistrationObjectId: string;
  /** Sui object id of the Walrus Site (from `parseSiteObjectId`). */
  siteObjectId: string;
  /**
   * Override the SuiNS package id. SuiNS upgrades the package over time;
   * leave undefined to use the bundled per-network default.
   */
  suinsPackageId?: `0x${string}`;
}

export interface MoveCallPayload {
  /** Move target string in `<package>::<module>::<function>` form. */
  target: string;
  /** Object-id args, in the order the entry function expects. */
  args: readonly [string, string];
}

/**
 * Construct a `set_target_walrus_site`-shaped Move call payload.
 *
 * Validates both object ids look like Sui ids, but does NOT round-trip the
 * transaction — that's the caller's job. Returning the payload as data lets
 * tests assert on shape without instantiating a Transaction builder.
 */
export function buildSetWalrusSiteCall(opts: SuinsLinkOpts): MoveCallPayload {
  if (!OBJECT_ID_PATTERN.test(opts.nameRegistrationObjectId)) {
    throw new Error(
      `nameRegistrationObjectId is not a Sui object id: '${opts.nameRegistrationObjectId}'`,
    );
  }
  if (!OBJECT_ID_PATTERN.test(opts.siteObjectId)) {
    throw new Error(`siteObjectId is not a Sui object id: '${opts.siteObjectId}'`);
  }

  const pkg = opts.suinsPackageId ?? SUINS_PACKAGE_IDS[opts.network];

  return {
    target: `${pkg}::controller::set_target_walrus_site`,
    args: [opts.nameRegistrationObjectId, opts.siteObjectId],
  };
}
