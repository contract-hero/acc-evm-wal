// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Minimal Ownable substitute. Matches OpenZeppelin's 5.x error shape so
// the collection's tests can `vm.expectRevert()` generically.
//
// DELIBERATELY OMITTED vs OpenZeppelin Ownable: no `transferOwnership` and no
// `renounceOwnership`. The owner set at construction is permanent — adequate
// for this showcase, but production collections that need to rotate the owner
// should use OpenZeppelin's `Ownable` (or `Ownable2Step`).

error OwnableUnauthorizedAccount(address account);
error OwnableInvalidOwner(address owner);

abstract contract MiniOwnable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert OwnableInvalidOwner(initialOwner);
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OwnableUnauthorizedAccount(msg.sender);
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }
}
