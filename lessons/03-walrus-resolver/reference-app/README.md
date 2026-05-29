# WalrusResolver — reference

ENS-gated on-chain pointer that lets a name's owner park a Walrus blob id +
the underlying Sui Blob object id under their `node`. A keeper bot can use
the Sui object id to extend the blob's epoch window without ever touching
this EVM contract — the pointer is one SSTORE per update.

Build + test:

```bash
forge build
forge test -vv
```

The test suite inlines a minimal Foundry cheatcode interface so this
workspace runs offline (no `forge install foundry-rs/forge-std`).
