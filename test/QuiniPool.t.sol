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

    // Helpers
    function _joinAsUser(address user) internal {
        token.mint(user, entryFee);
        vm.prank(user);
        token.approve(address(quiniPool), entryFee);
        vm.prank(user);
        quiniPool.joinPool();
    }

    function testStartPool() public {
        // Join the pool with two users
        _joinAsUser(vm.addr(1));
        _joinAsUser(vm.addr(2));

        // Start the pool
        quiniPool.startPool();

        // Check if the pool status is Active
        assertEq(uint256(quiniPool.poolStatus()), uint256(QuiniPool.PoolStatus.Active), "Pool should be active");
    }

    function testStartPoolAlreadyClosed() public {
        // Join the pool with two users
        _joinAsUser(vm.addr(1));
        _joinAsUser(vm.addr(2));

        // Start the pool
        quiniPool.startPool();

        // Try to start the pool again
        vm.expectRevert("Pool is not open");
        quiniPool.startPool();
    }

    function testStartPoolWithNoParticipants() public {
        vm.expectRevert("Need at least 2 participants to start the pool");
        quiniPool.startPool();
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
        // Lead the pool to a closed state
        _joinAsUser(vm.addr(1));
        _joinAsUser(vm.addr(2));
        quiniPool.startPool();

        // A third user tries to join after the pool has started
        address user = vm.addr(3);
        token.mint(user, entryFee);
        vm.startPrank(user);
        token.approve(address(quiniPool), entryFee);
        vm.expectRevert("Pool is not open for joining");
        quiniPool.joinPool();
        vm.stopPrank();
    }

    function testSubmitPredictionRevertsWhenPoolNotActive() public {
        // Just one user joins the pool, so it remains in Open state
        _joinAsUser(vm.addr(1));

        // The user tries to submit a prediction while the pool is still open
        vm.prank(vm.addr(1));
        vm.expectRevert("Pool is not active");
        quiniPool.submitPrediction(0, 2, 1);
    }

    function testSubmitPredictionRevertsWhenUserNotJoined() public {
        // Two users join the pool and start it
        _joinAsUser(vm.addr(1));
        _joinAsUser(vm.addr(2));
        quiniPool.startPool();

        // A third user tries to submit a prediction without joining
        vm.prank(vm.addr(3));
        vm.expectRevert("You must join the pool first");
        quiniPool.submitPrediction(0, 2, 1);
    }

    function testSubmitPredictionRevertsWhenMatchIdInvalid() public {
        // Two users join the pool and start it
        _joinAsUser(vm.addr(1));
        _joinAsUser(vm.addr(2));
        quiniPool.startPool();

        // A user tries to submit a prediction for an invalid match ID
        vm.prank(vm.addr(1));
        vm.expectRevert("Invalid match ID");
        quiniPool.submitPrediction(999, 2, 1);
    }

    function testSubmitPredictionRevertsWhenAfterKickoff() public {
        // Two users join the pool and start it
        _joinAsUser(vm.addr(1));
        _joinAsUser(vm.addr(2));
        quiniPool.startPool();

        // Fast forward time to after the kickoff of the first match
        vm.warp(kickoffTimes[0] + 1);

        // A user tries to submit a prediction for the first match after kickoff
        vm.prank(vm.addr(1));
        vm.expectRevert("Cannot submit prediction after kickoff");
        quiniPool.submitPrediction(0, 2, 1);
    }

    function testSubmitPredictionSuccess() public {
        // Two users join the pool and start it
        _joinAsUser(vm.addr(1));
        _joinAsUser(vm.addr(2));
        quiniPool.startPool();

        // A user submits a valid prediction for the first match
        vm.prank(vm.addr(1));
        quiniPool.submitPrediction(0, 2, 1);

        // Check if the prediction is stored correctly
        (uint8 homeScore, uint8 awayScore, bool wasPredicted) = quiniPool.predictions(vm.addr(1), 0);
        assertEq(homeScore, 2, "Home score should be 2");
        assertEq(awayScore, 1, "Away score should be 1");
        assertTrue(wasPredicted, "Prediction should be marked as submitted");
    }
}
