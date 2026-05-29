# Section 1 — Storage + the ENS-piggybacked auth gate

You're starting from a bare Foundry project. `src/WalrusResolver.sol` has the SPDX header, the pragma (`^0.8.24`), and an `IENS` interface already declared. Open it.

In this section you'll declare:

1. The `IERC165` interface (just the `supportsInterface(bytes4)` external view). The test file imports it from this source file, so declaring it here is what keeps the test compilation green later.
2. `contract WalrusResolver { ... }` — the inheritance declaration `is IERC165` is deferred to Section 4 so the source file compiles cleanly while you're building it.
3. A `Pointer` struct: `bytes32 blobId; bytes32 suiObjectId; bytes8 contentType;` (in that order — three slots per pointer).
4. The `IENS public immutable ens;` field + a constructor that takes one.
5. The private mapping: `mapping(bytes32 node => Pointer) private _pointers;`.
6. The event: `event WalrusBlobChanged(bytes32 indexed node, bytes32 blobId, bytes32 suiObjectId, bytes8 contentType, uint64 at);` (only `node` is indexed — three indexed-topic slots is the EVM cap and the indexer only needs the `node` filter cheaply).
7. A constructor that rejects a zero ENS registry: `require(address(ens_) != address(0), "WalrusResolver: zero ENS registry");` before assigning `ens = ens_;`.
8. The internal authorization helper:
   ```solidity
   function _requireAuthorized(bytes32 node) internal view {
       address nodeOwner = ens.owner(node);
       require(nodeOwner != address(0), "WalrusResolver: node has no owner");
       require(
           nodeOwner == msg.sender || ens.isApprovedForAll(nodeOwner, msg.sender),
           "WalrusResolver: not authorized"
       );
   }
   ```

No mutators yet — those land in Sections 2 and 3.

## What you'll write

- `src/WalrusResolver.sol` — the struct, the storage, the event, the constructor, and `_requireAuthorized`. No external functions yet.

## The key moment

**The `_requireAuthorized` helper consults the EXTERNAL ENS registry — it does NOT keep its own access list.**

A naive design would have stored an `owners` mapping inside this contract and shipped a `transferOwnership` function. That would have meant:

- Two separate sources of truth — what ENS thinks `vitalik.eth` owns, and what `WalrusResolver` thinks. They'd inevitably diverge.
- A pointer becomes orphaned when its ENS name is sold; the new owner has no way to claim it without a redeploy or a privileged operation.
- Operator approvals (`setApprovalForAll`) would have to be re-declared on this contract specifically.

By delegating to `ens.owner(node)` and `ens.isApprovedForAll(...)` at the moment of the call, the contract inherits the WHOLE ENSIP-1 authorization model: ownership transfers carry the pointer authority with them, and any operator a name's owner approved on the ENS registry automatically has authority here. Zero claim step. Zero state to keep in sync.

The price is one external view per mutation — one `STATICCALL` to the ENS registry on top of the `SLOAD`/`SSTORE` work. Cheap.

**One defensive check the delegation forces on you:** reject `nodeOwner == address(0)` BEFORE the approval check. An unregistered or expired ENS node resolves to `owner == address(0)`. Without the guard, a registry where `isApprovedForAll(address(0), caller)` returns `true` (or a mock/forked registry that does) would let an attacker write a pointer for a node nobody owns. The `require(nodeOwner != address(0), ...)` line closes that hole — and the same reasoning is why the constructor rejects a zero ENS registry address.

## Verification

Run `forge build` from your workspace — `src/WalrusResolver.sol` should compile cleanly. `forge test` will fail to compile the test file at this point because it references `setWalrusBlob`, `walrusBlob`, etc. that you haven't written yet — that's expected. The final `forge test` equivalence gate runs once the whole contract is in place at Section 4.
