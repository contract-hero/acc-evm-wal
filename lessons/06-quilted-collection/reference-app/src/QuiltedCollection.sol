// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MiniERC721} from "./lib/MiniERC721.sol";
import {MiniOwnable} from "./lib/MiniOwnable.sol";
import {MiniStrings} from "./lib/MiniStrings.sol";

/// 10 000-token NFT collection whose metadata lives in a Walrus Quilt.
/// `tokenURI(id)` deterministically returns the public Walrus aggregator
/// URL for that token's metadata JSON — no per-token pin, no per-token
/// state.
///
/// Migration story vs. classic IPFS-pinned drops: pack the drop's images
/// into one Walrus Quilt (`walrus store-quilt --paths ./images`, each
/// file's name becomes its quilt identifier), generate per-token metadata
/// JSONs whose `image` field is the aggregator URL into that images quilt
/// (`<aggregator>/v1/blobs/by-quilt-id/<images_quilt_id>/<tokenId>.png`),
/// then pack the metadata directory into a SECOND Quilt and deploy this
/// contract with the metadata quilt's id + the canonical aggregator base
/// + total supply.
///
/// The two-quilt split avoids the circular dependency that would arise if
/// metadata and images shared one quilt (metadata content would depend on
/// the quilt's id, which is content-addressed from the metadata).
///
/// The identifier inside the metadata quilt is expected to be
/// `<tokenId>.json`. The collection's `quiltId` is immutable; only the
/// resolver `aggregator` host can change, owner-only via `setAggregator`,
/// for sunset migration.
contract QuiltedCollection is MiniERC721, MiniOwnable {
    using MiniStrings for uint256;

    /// Base64url-encoded quiltId as a string (Walrus blob ids are not raw
    /// 32 bytes when serialised in the aggregator URL — they're the
    /// canonical base64url form, which Move and Sui produce natively).
    /// Storing the already-encoded form sidesteps doing base64url inside
    /// Solidity.
    ///
    /// Solidity does not allow `immutable` on dynamic-size types, so these
    /// are plain storage variables that the constructor writes once and
    /// nothing thereafter mutates (`quiltId`) or only `setAggregator`
    /// mutates (`aggregator`).
    string public quiltId;
    string public aggregator;
    uint256 public immutable maxSupply;

    uint256 private _nextTokenId = 1;

    event Minted(uint256 indexed tokenId, address indexed to);
    event AggregatorUpdated(string oldAggregator, string newAggregator);

    constructor(
        string memory name_,
        string memory symbol_,
        string memory quiltId_,
        string memory aggregator_,
        uint256 maxSupply_,
        address initialOwner
    ) MiniERC721(name_, symbol_) MiniOwnable(initialOwner) {
        require(bytes(quiltId_).length > 0, "QuiltedCollection: empty quiltId");
        _validateAggregator(bytes(aggregator_));
        require(maxSupply_ > 0, "QuiltedCollection: zero maxSupply");
        quiltId = quiltId_;
        aggregator = aggregator_;
        maxSupply = maxSupply_;
    }

    /// @notice Self-mint to the caller. Caps at `maxSupply`.
    function mint() external returns (uint256 tokenId) {
        require(_nextTokenId <= maxSupply, "QuiltedCollection: sold out");
        tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        emit Minted(tokenId, msg.sender);
    }

    function totalMinted() external view returns (uint256) {
        return _nextTokenId - 1;
    }

    /// @notice Migration knob for the canonical aggregator host. The owner
    /// can point the collection at a different Walrus aggregator (e.g. if
    /// the original host sunsets or testnet→mainnet migration). The quilt
    /// itself is content-addressed; only the resolver URL prefix changes.
    function setAggregator(string calldata newAggregator) external onlyOwner {
        _validateAggregator(bytes(newAggregator));
        emit AggregatorUpdated(aggregator, newAggregator);
        aggregator = newAggregator;
    }

    /// @dev Aggregator URL must be non-empty AND must NOT end in `/` — `tokenURI`
    /// concats `aggregator + "/v1/blobs/..."` and a trailing slash would produce
    /// `//` in every token URL, which strict CDNs reject and most marketplaces
    /// render as broken metadata.
    function _validateAggregator(bytes memory aggBytes) private pure {
        require(aggBytes.length > 0, "QuiltedCollection: empty aggregator");
        require(aggBytes[aggBytes.length - 1] != 0x2f, "QuiltedCollection: aggregator must not end with /");
    }

    /// @notice Resolve token id to its Walrus-quilt-backed metadata URL.
    /// Shape: `<aggregator>/v1/blobs/by-quilt-id/<quiltId>/<tokenId>.json`
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string.concat(
            aggregator,
            "/v1/blobs/by-quilt-id/",
            quiltId,
            "/",
            tokenId.toString(),
            ".json"
        );
    }
}
