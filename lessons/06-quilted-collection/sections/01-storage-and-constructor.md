# Section 1 — Storage + constructor

You're starting from a Foundry project with three vendored libs under `src/lib/`: `MiniERC721`, `MiniOwnable`, `MiniStrings`. Don't edit them — they're stand-ins for OpenZeppelin's full versions and the workspace stays offline-runnable by avoiding the `forge install` dependency.

`src/QuiltedCollection.sol` has the SPDX header, the pragma, and the three `import` lines already in place. Open it.

In this section you'll write:

1. `contract QuiltedCollection is MiniERC721, MiniOwnable { ... }`.
2. The `using MiniStrings for uint256;` directive — what lets you call `tokenId.toString()` later.
3. Three storage variables (in this order):
   ```solidity
   string public quiltId;
   string public aggregator;
   uint256 public immutable maxSupply;
   ```
4. The private counter: `uint256 private _nextTokenId = 1;`.
5. Two events:
   ```solidity
   event Minted(uint256 indexed tokenId, address indexed to);
   event AggregatorUpdated(string oldAggregator, string newAggregator);
   ```
6. The constructor:
   ```solidity
   constructor(
       string memory name_,
       string memory symbol_,
       string memory quiltId_,
       string memory aggregator_,
       uint256 maxSupply_,
       address initialOwner
   ) MiniERC721(name_, symbol_) MiniOwnable(initialOwner) {
       require(bytes(quiltId_).length > 0, "QuiltedCollection: empty quiltId");
       require(bytes(aggregator_).length > 0, "QuiltedCollection: empty aggregator");
       require(maxSupply_ > 0, "QuiltedCollection: zero maxSupply");
       quiltId = quiltId_;
       aggregator = aggregator_;
       maxSupply = maxSupply_;
   }
   ```

The contract is not yet complete (no `mint`, no `tokenURI`, no `setAggregator`) but the `MiniERC721`'s `tokenURI` is `virtual` — yours will override it in Section 3. Until then, `src/QuiltedCollection.sol` won't compile cleanly because of the unfulfilled abstract function.

## What you'll write

- `src/QuiltedCollection.sol` — the storage, the events, the constructor. The remaining external functions land in Sections 2, 3, 4.

## The key moment

**`quiltId` and `aggregator` are `string public` — not `immutable`.**

Solidity does not allow `immutable` on dynamic-size types (anything that isn't a fixed-width value type — including `string`, `bytes`, `mapping`, structs, arrays). The reason is implementation-level: `immutable` values are baked into the contract's runtime bytecode at deploy time, which only works when the size is known at compile time. A `string` has no compile-time-known length.

So you can't WRITE `string public immutable quiltId;`. The next-best discipline is a plain storage variable that the constructor writes once and nothing thereafter mutates. The CONVENTION is what makes `quiltId` effectively immutable:

- No setter is exposed — meaning no Solidity-level mutation path beyond the constructor.
- A future contributor accidentally exposing one would need to add a function — that's the point at which code review catches it.

`aggregator` is the same shape AT STORAGE TIME but deliberately MUTABLE in behavior — `setAggregator` exists (Section 4) as a controlled sunset knob. That's an architectural decision, not a language guarantee. The contract you're building says, with both the structure of the source and the absence of one setter vs. presence of the other:

- `quiltId` is content-addressed — changing it means losing the bytes.
- `aggregator` is a resolver host — interchangeable HTTPS endpoints, hot-swappable when one sunsets.

The lesson here is that Solidity's type system catches some immutability mistakes (you can't reassign an `immutable` field) but not the dynamic-size ones — for those, your design intent has to show up in the SHAPE of the contract.

## Verification

Run `forge build` — `src/QuiltedCollection.sol` will fail to compile cleanly because `tokenURI` is `virtual` on `MiniERC721` and you haven't overridden it yet. That's expected at this point. Section 3 lands the override.

To verify Section 1 in isolation, you can temporarily add a stub override (`function tokenURI(uint256) public view override returns (string memory) { return ""; }`) and run `forge build` — it should compile clean. Delete the stub before moving to Section 2 so you don't drift from the section-by-section flow.
