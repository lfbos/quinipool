// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {QuiniPool} from "../src/QuiniPool.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract QuiniPoolTest is Test {
    QuiniPool public quiniPool;

    // Data for testing
    string[] public homeTeams = ["Team A", "Team B"];
    string[] public awayTeams = ["Team C", "Team D"];
    uint256[] public kickoffTimes = [block.timestamp + 1 days, block.timestamp + 2 days];
    uint256 public entryFee = 1 ether;
    MockUSDC public token;

    function setUp() public {
        token = new MockUSDC();
        quiniPool = new QuiniPool(IERC20(address(token)), entryFee, homeTeams, awayTeams, kickoffTimes);
    }

    function testJoinPool() public {
        // Simulate a user joining the pool
        address user = vm.addr(1);
        vm.startPrank(user);
        token.mint(user, entryFee);
        token.approve(address(quiniPool), entryFee);
        quiniPool.joinPool();
        vm.stopPrank();

        // Check if the user has participated
        assertTrue(quiniPool.hasParticipated(user), "User should have participated");

        // Check if the total pool amount is updated and the contract holds the USDC
        assertEq(quiniPool.totalPool(), entryFee, "Pool should equal entry fee");

        // Check if the contract holds the USDC
        assertEq(token.balanceOf(address(quiniPool)), entryFee, "Contract should hold the USDC");
    }

    function testJoinPoolWithUserAlreadyParticipated() public {
        // Simulate a user joining the pool
        address user = vm.addr(3);
        vm.startPrank(user);
        token.mint(user, entryFee);
        token.approve(address(quiniPool), entryFee);
        quiniPool.joinPool();
        vm.stopPrank();

        // Try to join again
        vm.startPrank(user);
        vm.expectRevert("Already joined the pool");
        quiniPool.joinPool();
        vm.stopPrank();
    }

    function testConstructorRevertsWhenEntryFeeIsZero() public {
        vm.expectRevert("Entry fee must be greater than zero");
        new QuiniPool(IERC20(address(token)), 0, homeTeams, awayTeams, kickoffTimes);
    }

    function testConstructorRevertsWhenNoMatches() public {
        string[] memory emptyHome;
        string[] memory emptyAway;
        uint256[] memory emptyKickoffs;
        vm.expectRevert("At least one match must be provided");
        new QuiniPool(IERC20(address(token)), entryFee, emptyHome, emptyAway, emptyKickoffs);
    }

    function testConstructorRevertsWhenAwayTeamsLengthMismatch() public {
        string[] memory mismatchedAway = new string[](1);
        mismatchedAway[0] = "Team C";
        vm.expectRevert("Input arrays must have the same length");
        new QuiniPool(IERC20(address(token)), entryFee, homeTeams, mismatchedAway, kickoffTimes);
    }

    function testConstructorRevertsWhenKickoffTimesLengthMismatch() public {
        uint256[] memory mismatchedKickoffs = new uint256[](1);
        mismatchedKickoffs[0] = block.timestamp + 1 days;
        vm.expectRevert("Input arrays must have the same length");
        new QuiniPool(IERC20(address(token)), entryFee, homeTeams, awayTeams, mismatchedKickoffs);
    }

    function testJoinPoolRevertsWhenPoolNotOpen() public {
        // Force pool out of Open status by writing storage directly.
        // Slot layout: 0 _owner (Ownable), 1 token, 2 entryFee, 3 totalPool, 4 totalMatches, 5 poolStatus.
        vm.store(address(quiniPool), bytes32(uint256(5)), bytes32(uint256(uint8(QuiniPool.PoolStatus.Active))));

        address user = vm.addr(7);
        vm.startPrank(user);
        token.mint(user, entryFee);
        token.approve(address(quiniPool), entryFee);
        vm.expectRevert("Pool is not open for joining");
        quiniPool.joinPool();
        vm.stopPrank();
    }
}
