// Walrus Sites publisher — TypeScript port of `publish.sh`.
//
// Three pure functions: validate inputs, build the CLI argv, parse the
// resulting site_object_id out of stdout. The caller drives the CLI itself
// (e.g. via Node's child_process APIs), so this module stays free of I/O —
// which keeps the vitest suite an honest equivalence gate (no network,
// no CLI on PATH).
//
// On-chain shape: one `site-builder publish` invocation creates ONE Sui
// object — a Walrus Site — that owns every blob in the directory. The
// returned object id is the handle a SuiNS name links to so the bytes
// resolve through wal.app.

const SITE_NAME_PATTERN = /^[A-Za-z0-9._-]{1,64}$/;
const NETWORKS = ["testnet", "mainnet"] as const;

export type Network = (typeof NETWORKS)[number];

export interface PublishOpts {
  // Path to the static-site directory to publish (must contain index.html).
  siteDir: string;
  // Human-readable site label. Stored on the Walrus Site object.
  siteName: string;
  // Storage budget in Walrus epochs. Defaults to 200.
  epochs?: number;
  // Sui network context. Defaults to "testnet".
  network?: Network;
}

export interface ValidatedPublishOpts {
  siteDir: string;
  siteName: string;
  epochs: number;
  network: Network;
}

// Validate every publish input. Throws a single descriptive Error per
// invalid field — never returns silently with mangled inputs.
export function validatePublishOpts(opts: PublishOpts): ValidatedPublishOpts {
  if (typeof opts.siteDir !== "string" || opts.siteDir.length === 0) {
    throw new Error("siteDir is required");
  }

  if (!SITE_NAME_PATTERN.test(opts.siteName)) {
    throw new Error(
      `siteName must match ${SITE_NAME_PATTERN} (got: '${opts.siteName}')`,
    );
  }

  const epochs = opts.epochs ?? 200;
  if (!Number.isInteger(epochs) || epochs <= 0) {
    throw new Error(`epochs must be a positive integer (got: ${epochs})`);
  }

  const network = opts.network ?? "testnet";
  if (!(NETWORKS as readonly string[]).includes(network)) {
    throw new Error(
      `network must be one of ${NETWORKS.join(", ")} (got: '${network}')`,
    );
  }

  return { siteDir: opts.siteDir, siteName: opts.siteName, epochs, network };
}

// Build the argv array for `site-builder`. `--context` is a global flag and
// must precede the `publish` subcommand.
export function buildPublishArgs(opts: ValidatedPublishOpts): string[] {
  return [
    "--context",
    opts.network,
    "publish",
    opts.siteDir,
    "--epochs",
    String(opts.epochs),
    "--site-name",
    opts.siteName,
  ];
}

const SITE_OBJECT_ID_PATTERN = /^\s*site_object_id:\s*(0x[a-fA-F0-9]+)\s*$/m;

// Extract the published Walrus Site's Sui object id from CLI stdout.
//
// site-builder prints a multi-line human-readable log; the id appears on a
// line shaped exactly like `site_object_id: 0x<hex>`. Matching the line
// form keeps the parser tolerant to upstream log-format changes around it.
export function parseSiteObjectId(stdout: string): `0x${string}` {
  const match = SITE_OBJECT_ID_PATTERN.exec(stdout);
  if (!match) {
    throw new Error(
      "could not find 'site_object_id: 0x...' in site-builder output",
    );
  }
  return match[1].toLowerCase() as `0x${string}`;
}
