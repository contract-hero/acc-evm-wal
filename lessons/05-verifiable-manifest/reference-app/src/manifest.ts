// Verifiable manifest client.
//
// Resolves an ENS name to a Walrus blob via the WalrusResolver contract from
// lesson 03, then fetches the manifest body from a Walrus aggregator by its
// content-addressed blob id.
//
// Trust model: this client trusts the aggregator to serve the bytes that
// correspond to the requested blob id; it does NOT recompute the blob id
// client-side via the Reed-Solomon scheme. The leverage over IPFS comes from
// the POINTER: one `eth_call` to the resolver beats IPNS, regardless of
// aggregator trust. For trustless retrieval, layer a `@mysten/walrus`-based
// verifier on top.

import { createPublicClient, http, namehash, type Address } from "viem";
import { mainnet } from "viem/chains";

import { asciiTrim, bytes32ToBase64Url } from "./encoding.ts";

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

export type ResolverTuple = readonly [`0x${string}`, `0x${string}`, `0x${string}`];

export type ReadPointer = (args: {
  rpcUrl: string;
  resolverAddress: Address;
  node: `0x${string}`;
}) => Promise<ResolverTuple>;

export type HttpGet = (
  url: string,
) => Promise<{ ok: boolean; status: number; text: () => Promise<string> }>;

export interface ResolvedManifest<T> {
  manifest: T;            // parsed JSON manifest body
  blobId: `0x${string}`;  // the Walrus blob id the pointer resolved to
  contentType: string;    // ASCII trim of the on-chain content type hint
}

export interface ResolveOpts {
  rpcUrl: string;
  resolverAddress: Address;
  aggregator: string;
  // Optional dependency-injection seams. Defaults below use viem +
  // globalThis.fetch; tests pass fakes to keep the suite fully offline.
  readPointer?: ReadPointer;
  httpGet?: HttpGet;
}

const ZERO_BLOB = `0x${"00".repeat(32)}` as `0x${string}`;

// Default pointer reader — issues one `eth_call` via viem.
//
// `chain: mainnet` here only supplies chain metadata (id, formatters); the
// actual RPC endpoint comes from `rpcUrl`, so an `eth_call` to a read-only
// `view` function works against any EVM network regardless of this value. If
// you target a non-mainnet chain and want correct chain metadata, pass your
// own `readPointer` via `ResolveOpts` (the injection seam below) with the
// right `chain`.
export const viemReadPointer: ReadPointer = async ({
  rpcUrl,
  resolverAddress,
  node,
}) => {
  const evm = createPublicClient({ chain: mainnet, transport: http(rpcUrl) });
  return (await evm.readContract({
    address: resolverAddress,
    abi: WALRUS_RESOLVER_ABI,
    functionName: "walrusBlob",
    args: [node],
  })) as ResolverTuple;
};

// Default HTTP reader — global fetch with a single GET.
export const fetchHttpGet: HttpGet = async (url) => {
  const res = await fetch(url);
  return { ok: res.ok, status: res.status, text: () => res.text() };
};

// Resolve `ensName` to its parsed manifest body.
//
// Throws if the pointer is unset, the on-chain contentType is not JSON, the
// aggregator returns a non-2xx status, or the JSON fails to parse.
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

// ─── Token-list-flavoured example ──────────────────────────────────────────

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

// Convenience wrapper: same function, narrowed return type at the call site.
export const resolveTokenList = (ensName: string, opts: ResolveOpts) =>
  resolveManifest<UniswapTokenList>(ensName, opts);
