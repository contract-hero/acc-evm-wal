# WalrusResolver — An IPNS Replacement on ENS

IPNS today is a DHT random walk: 30s tail latency on a good day, a silent
disappearance on a bad one, and a pinning vendor in the loop for anything
that matters. The Walrus-era replacement is one EVM contract: an ENS-gated
mapping from `node` to a `(blobId, suiObjectId, contentType)` pointer.
Resolution is one `eth_call` (sub-200ms), updates are one EVM transaction
with on-chain provenance, and a permissionless keeper can renew the
underlying Sui Blob's epoch window without ever touching this contract.

In this lesson you'll write `WalrusResolver.sol` — about 50 lines of
Solidity covering:

1. **Storage + the ENS-piggybacked auth gate** — a `Pointer` struct, a
   `node => Pointer` mapping, an `IENS` immutable, and the internal helper
   that consults the ENS registry for owner/operator authorization.
2. **The write path** — `setWalrusBlob(node, blobId, suiObjectId, contentType)`,
   gated by the auth helper, emitting an indexed `WalrusBlobChanged` event
   so history is reconstructable without an on-chain version array.
3. **The clear path** — `clearWalrusBlob(node)`, equivalent but explicit;
   the deliberate zero-emit is a different user intent than "set to zero".
4. **The read path + ERC-165** — the view returning the tuple, plus a
   conservative `supportsInterface` that claims ONLY `IERC165` (and
   conspicuously not the ENS resolver-record interfaces).

The reference-app's Foundry test suite (8 tests) is the equivalence gate:
authorization rules, ownership transfer revoking the previous owner's
authority, operator approval flowing through, and ERC-165 not claiming
interfaces this contract doesn't honor.

By the end you'll have an on-chain pointer primitive with all of ENS's
authorization story for free and none of IPNS's resolution pain.
