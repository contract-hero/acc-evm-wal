// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Minimal uint256 → decimal-string conversion. Same surface as
// OpenZeppelin's Strings.toString — just enough for tokenURI to embed the
// token id as a decimal substring.

library MiniStrings {
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
