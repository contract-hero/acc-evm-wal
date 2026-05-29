# QuiltedCollection — reference

A 10 000-token ERC-721 backed by TWO Walrus Quilts: one for metadata, one
for images. `tokenURI(id)` returns a deterministic aggregator URL — no
per-token pin, no per-token state.

Build + test:

```bash
forge build
forge test -vv
```

The workspace vendors minimal substitutes for OpenZeppelin's ERC721 +
Ownable + Strings (under `src/lib/`) so it runs fully offline. The
contract under test is `src/QuiltedCollection.sol` only — the libs are
pre-provided scaffolding.
