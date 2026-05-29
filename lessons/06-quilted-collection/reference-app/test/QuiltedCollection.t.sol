// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {QuiltedCollection} from "../src/QuiltedCollection.sol";

interface Vm {
    function prank(address sender) external;
    function startPrank(address sender) external;
    function stopPrank() external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert() external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
}

abstract contract MiniTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(uint256 a, uint256 b) internal pure {
        require(a == b, "assertEq(uint256): values differ");
    }
    function assertEqAddress(address a, address b) internal pure {
        require(a == b, "assertEqAddress: values differ");
    }
    function assertEqString(string memory a, string memory b) internal pure {
        require(
            keccak256(bytes(a)) == keccak256(bytes(b)),
            "assertEqString: values differ"
        );
    }
}

contract QuiltedCollectionTest is MiniTest {
    QuiltedCollection internal c;

    string internal constant QUILT_ID = "6XUOE-Q5-nAXHRifN6n9nomVDtHZQbGuAkW3PjlBuKo";
    string internal constant AGG = "https://aggregator.walrus-testnet.walrus.space";

    address internal alice = address(0xA11CE);
    address internal owner_ = address(0xBEEF);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Minted(uint256 indexed tokenId, address indexed to);
    event AggregatorUpdated(string oldAggregator, string newAggregator);

    function setUp() public {
        c = new QuiltedCollection("Drop", "DROP", QUILT_ID, AGG, 3, owner_);
    }

    function test_constructor_revertsOnEmptyQuiltId() public {
        vm.expectRevert(bytes("QuiltedCollection: empty quiltId"));
        new QuiltedCollection("D", "D", "", AGG, 1, owner_);
    }

    function test_constructor_revertsOnEmptyAggregator() public {
        vm.expectRevert(bytes("QuiltedCollection: empty aggregator"));
        new QuiltedCollection("D", "D", QUILT_ID, "", 1, owner_);
    }

    function test_constructor_revertsOnZeroMaxSupply() public {
        vm.expectRevert(bytes("QuiltedCollection: zero maxSupply"));
        new QuiltedCollection("D", "D", QUILT_ID, AGG, 0, owner_);
    }

    function test_constructor_revertsOnAggregatorTrailingSlash() public {
        vm.expectRevert(bytes("QuiltedCollection: aggregator must not end with /"));
        new QuiltedCollection(
            "D",
            "D",
            QUILT_ID,
            "https://aggregator.walrus-testnet.walrus.space/",
            1,
            owner_
        );
    }

    function test_mint_assignsSequentialIdsAndEmits() public {
        // MiniERC721._mint emits Transfer(address(0), to, tokenId) before
        // QuiltedCollection.mint emits Minted(tokenId, to). Pin both.
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 1);
        vm.expectEmit(true, true, false, false);
        emit Minted(1, alice);
        vm.prank(alice);
        uint256 id1 = c.mint();

        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), alice, 2);
        vm.expectEmit(true, true, false, false);
        emit Minted(2, alice);
        vm.prank(alice);
        uint256 id2 = c.mint();

        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEqAddress(c.ownerOf(1), alice);
        assertEqAddress(c.ownerOf(2), alice);
        assertEq(c.totalMinted(), 2);
    }

    function test_mint_capsAtMaxSupply() public {
        vm.startPrank(alice);
        c.mint();
        c.mint();
        c.mint();
        vm.expectRevert(bytes("QuiltedCollection: sold out"));
        c.mint();
        vm.stopPrank();
    }

    function test_tokenURI_buildsExpectedAggregatorURL() public {
        vm.prank(alice);
        uint256 id = c.mint();
        string memory uri = c.tokenURI(id);
        assertEqString(
            uri,
            string.concat(AGG, "/v1/blobs/by-quilt-id/", QUILT_ID, "/1.json")
        );
    }

    function test_tokenURI_revertsForUnmintedToken() public {
        vm.expectRevert();
        c.tokenURI(42);
    }

    function test_setAggregator_ownerCanMigrateAggregator() public {
        vm.prank(alice);
        uint256 id = c.mint();

        string memory newAgg = "https://aggregator.walrus.example";
        vm.expectEmit(false, false, false, true);
        emit AggregatorUpdated(AGG, newAgg);
        vm.prank(owner_);
        c.setAggregator(newAgg);

        assertEqString(c.aggregator(), newAgg);
        assertEqString(
            c.tokenURI(id),
            string.concat(newAgg, "/v1/blobs/by-quilt-id/", QUILT_ID, "/1.json")
        );
    }

    function test_setAggregator_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        c.setAggregator("https://aggregator.walrus.example");
    }

    function test_setAggregator_revertsOnEmpty() public {
        vm.prank(owner_);
        vm.expectRevert(bytes("QuiltedCollection: empty aggregator"));
        c.setAggregator("");
    }

    function test_setAggregator_revertsOnTrailingSlash() public {
        vm.prank(owner_);
        vm.expectRevert(bytes("QuiltedCollection: aggregator must not end with /"));
        c.setAggregator("https://aggregator.walrus.example/");
    }
}
