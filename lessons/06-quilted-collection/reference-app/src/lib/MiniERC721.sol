// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Minimal ERC-721 substitute. Covers the surface area QuiltedCollection
// uses: name/symbol, ownerOf, balanceOf, _mint, _requireOwned, and a
// virtual tokenURI override target. No approve/transferFrom flow — the
// collection's tests don't exercise transfers, so the minimum that
// compiles + serves the test suite stays in.
//
// DELIBERATELY OMITTED vs OpenZeppelin ERC721 (do NOT copy this to prod):
//   - No `_safeMint` / `_checkOnERC721Received` — minting to a contract that
//     doesn't implement `onERC721Received` would silently lock the token.
//     This file exposes `_mint` only, and the name says so honestly.
//   - No approve / getApproved / setApprovalForAll / transferFrom / safeTransferFrom.
//   - No ERC-165 `supportsInterface`.
// Use OpenZeppelin's `ERC721` for anything real.

error MiniERC721NonexistentToken(uint256 tokenId);
error MiniERC721AlreadyMinted(uint256 tokenId);
error MiniERC721InvalidReceiver(address receiver);

abstract contract MiniERC721 {
    string public name;
    string public symbol;

    mapping(uint256 tokenId => address) internal _owners;
    mapping(address owner => uint256) internal _balances;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address o = _owners[tokenId];
        if (o == address(0)) revert MiniERC721NonexistentToken(tokenId);
        return o;
    }

    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    function tokenURI(uint256 tokenId) public view virtual returns (string memory);

    function _requireOwned(uint256 tokenId) internal view returns (address) {
        return ownerOf(tokenId);
    }

    /// @dev Unsafe mint: does NOT check `onERC721Received` on contract
    /// receivers (see the file header). Named `_mint`, not `_safeMint`, so the
    /// missing receiver hook is visible at the call site.
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert MiniERC721InvalidReceiver(to);
        if (_owners[tokenId] != address(0)) revert MiniERC721AlreadyMinted(tokenId);
        _owners[tokenId] = to;
        // Overflow-safe without a checked block: one mint bumps the balance by
        // 1, and tokenIds are bounded by maxSupply, so a balance can never
        // approach 2^256.
        unchecked { _balances[to] += 1; }
        emit Transfer(address(0), to, tokenId);
    }
}
