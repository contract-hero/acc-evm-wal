# reference-app — `WalrusAnchor`

The reference implementation of the lesson's deliverable. The ACC conductor seeds a copy of this directory into `~/.acc/workspaces/01-walrus-solidity-basics/` and runs `forge test` there as the equivalence gate.

```
reference-app/
├── foundry.toml          minimal Foundry config; solc 0.8.20
├── src/WalrusAnchor.sol  the contract being built (3 lines of state + 2 functions)
└── test/WalrusAnchor.t.sol  4 tests, forge-std-free (inline cheatcode interface)
```

Run locally:

```bash
forge build
forge test
```

The test file vendors a tiny `MiniTest` base + `Vm` cheatcode interface inline, so there is no `forge install` step and no network access required.
