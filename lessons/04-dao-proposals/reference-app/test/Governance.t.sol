// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Governance, IERC20} from "../src/Governance.sol";

// Minimal forge cheatcode interface — keeps the workspace offline-runnable.
// HEVM cheatcode address is the Foundry convention:
// keccak256("hevm cheat code") truncated to 160 bits.
interface Vm {
    function prank(address sender) external;
    function expectRevert(bytes calldata revertData) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
    function warp(uint256 newTimestamp) external;
}

abstract contract MiniTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(uint256 a, uint256 b) internal pure {
        require(a == b, "assertEq(uint256): values differ");
    }
    function assertEqBytes32(bytes32 a, bytes32 b) internal pure {
        require(a == b, "assertEqBytes32: values differ");
    }
    function assertEqAddress(address a, address b) internal pure {
        require(a == b, "assertEqAddress: values differ");
    }
    function assertTrue(bool c) internal pure {
        require(c, "assertTrue: condition is false");
    }
    function assertFalse(bool c) internal pure {
        require(!c, "assertFalse: condition is true");
    }
}

/// Tiny ERC-20 substitute that implements just the surface area the
/// Governance contract reads (`balanceOf`) and the test mints with.
contract MockVoteToken is IERC20 {
    mapping(address => uint256) internal _balances;

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
}

contract GovernanceTest is MiniTest {
    Governance internal gov;
    MockVoteToken internal token;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA801);
    address internal proposer = address(0xBEEF);

    bytes32 internal blob = bytes32(uint256(0xB10B));

    event Proposed(uint256 indexed id, address indexed proposer, bytes32 blobId, uint64 deadline);
    event Voted(uint256 indexed id, address indexed voter, bool support, uint256 weight);

    function setUp() public {
        token = new MockVoteToken();
        gov = new Governance(IERC20(address(token)));
        token.mint(alice, 100 ether);
        token.mint(bob, 200 ether);
        token.mint(carol, 50 ether);
    }

    function test_propose_storesProposalAndEmits() public {
        uint64 deadline = uint64(block.timestamp + 1 days);

        vm.expectEmit(true, true, false, true);
        emit Proposed(1, proposer, blob, deadline);

        vm.prank(proposer);
        uint256 id = gov.propose(blob, deadline);
        assertEq(id, 1);

        (address p, bytes32 b, uint64 d, uint128 yes, uint128 no) = gov.proposals(id);
        assertEqAddress(p, proposer);
        assertEqBytes32(b, blob);
        assertEq(uint256(d), uint256(deadline));
        assertEq(uint256(yes), 0);
        assertEq(uint256(no), 0);
    }

    function test_propose_secondCall_assignsSequentialIdAndIndependentStorage() public {
        uint64 deadline = uint64(block.timestamp + 1 days);
        bytes32 anotherBlob = bytes32(uint256(0xFADE));

        vm.prank(proposer);
        uint256 id1 = gov.propose(blob, deadline);
        vm.prank(proposer);
        uint256 id2 = gov.propose(anotherBlob, deadline);

        assertEq(id1, 1);
        assertEq(id2, 2);

        (, bytes32 b1, , , ) = gov.proposals(id1);
        (, bytes32 b2, , , ) = gov.proposals(id2);
        assertEqBytes32(b1, blob);
        assertEqBytes32(b2, anotherBlob);

        // Voting on one proposal must not bleed into the other's tallies.
        vm.prank(alice);
        gov.vote(id1, true);
        (, , , uint128 yes1, ) = gov.proposals(id1);
        (, , , uint128 yes2, ) = gov.proposals(id2);
        assertEq(uint256(yes1), 100 ether);
        assertEq(uint256(yes2), 0);
    }

    function test_propose_revertsOnPastDeadline() public {
        vm.expectRevert(bytes("Governance: deadline in past"));
        gov.propose(blob, uint64(block.timestamp));
    }

    function test_propose_revertsOnZeroBlob() public {
        vm.expectRevert(bytes("Governance: zero blobId"));
        gov.propose(bytes32(0), uint64(block.timestamp + 1 days));
    }

    function test_vote_addsWeightedTally() public {
        uint256 id = gov.propose(blob, uint64(block.timestamp + 1 days));

        vm.expectEmit(true, true, false, true);
        emit Voted(id, alice, true, 100 ether);
        vm.prank(alice);
        gov.vote(id, true);

        vm.expectEmit(true, true, false, true);
        emit Voted(id, bob, false, 200 ether);
        vm.prank(bob);
        gov.vote(id, false);

        vm.prank(carol);
        gov.vote(id, true);

        (, , , uint128 yes, uint128 no) = gov.proposals(id);
        assertEq(uint256(yes), 150 ether);
        assertEq(uint256(no), 200 ether);
    }

    function test_vote_revertsOnDoubleVote() public {
        uint256 id = gov.propose(blob, uint64(block.timestamp + 1 days));
        vm.prank(alice);
        gov.vote(id, true);
        vm.prank(alice);
        vm.expectRevert(bytes("Governance: already voted"));
        gov.vote(id, false);
    }

    function test_vote_revertsAfterDeadline() public {
        uint64 deadline = uint64(block.timestamp + 1 hours);
        uint256 id = gov.propose(blob, deadline);
        vm.warp(deadline);
        vm.prank(alice);
        vm.expectRevert(bytes("Governance: voting closed"));
        gov.vote(id, true);
    }

    function test_vote_revertsOnZeroWeight() public {
        uint256 id = gov.propose(blob, uint64(block.timestamp + 1 days));
        address voterWithNoTokens = address(0xDEAD);
        vm.prank(voterWithNoTokens);
        vm.expectRevert(bytes("Governance: zero weight"));
        gov.vote(id, true);
    }

    function test_tally_openProposal_isNotClosedNotPassed() public {
        uint64 deadline = uint64(block.timestamp + 1 days);
        uint256 id = gov.propose(blob, deadline);
        vm.prank(alice);
        gov.vote(id, true);
        vm.prank(bob);
        gov.vote(id, false);

        (uint128 y, uint128 n, bool passed, bool closed) = gov.tally(id);
        assertEq(uint256(y), 100 ether);
        assertEq(uint256(n), 200 ether);
        assertFalse(closed);
        assertFalse(passed);
    }

    function test_tally_closedAndFailed_whenNoExceedsYes() public {
        uint64 deadline = uint64(block.timestamp + 1 days);
        uint256 id = gov.propose(blob, deadline);
        vm.prank(alice);
        gov.vote(id, true);
        vm.prank(bob);
        gov.vote(id, false);

        vm.warp(deadline + 1);
        (, , bool passed, bool closed) = gov.tally(id);
        assertTrue(closed);
        assertFalse(passed);
    }

    function test_tally_closedAndPassed_whenYesExceedsNo() public {
        uint64 deadline = uint64(block.timestamp + 1 days);
        uint256 id = gov.propose(blob, deadline);
        vm.prank(bob);
        gov.vote(id, true);

        vm.warp(deadline + 1);
        (, , bool passed, bool closed) = gov.tally(id);
        assertTrue(closed);
        assertTrue(passed);
    }

    function test_tally_revertsOnUnknownProposal() public {
        vm.expectRevert(bytes("Governance: unknown proposal"));
        gov.tally(999);
    }
}
