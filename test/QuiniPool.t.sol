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

    // --- startPool ---

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

    // --- joinPool ---

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

    // --- constructor ---

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

    // --- joinPool reverts ---

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

    // --- submitPrediction ---

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

    // --- setMatchResult ---

    function testSetMatchResult() public {
        // Two users join the pool and start it
        _joinAsUser(vm.addr(1));
        _joinAsUser(vm.addr(2));
        quiniPool.startPool();

        // Set the result for the first match
        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(0, 2, 1);

        // Check if the result is stored correctly
        (,,, uint8 homeScore, uint8 awayScore, bool resultSet) = quiniPool.matches(0);
        assertEq(homeScore, 2, "Home score should be 2");
        assertEq(awayScore, 1, "Away score should be 1");
        assertTrue(resultSet, "Result should be marked as set");
    }

    function _setupActivePoolWith(address a, address b) internal {
        _joinAsUser(a);
        _joinAsUser(b);
        quiniPool.startPool();
    }

    function testSetMatchResultRevertsWhenPoolNotActive() public {
        // Pool stays Open
        vm.prank(quiniPool.owner());
        vm.expectRevert("Pool is not active");
        quiniPool.setMatchResult(0, 2, 1);
    }

    function testSetMatchResultRevertsWhenMatchIdInvalid() public {
        _setupActivePoolWith(vm.addr(1), vm.addr(2));

        vm.prank(quiniPool.owner());
        vm.expectRevert("Invalid match ID");
        quiniPool.setMatchResult(999, 2, 1);
    }

    function testSetMatchResultRevertsWhenAlreadySet() public {
        _setupActivePoolWith(vm.addr(1), vm.addr(2));

        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(0, 2, 1);

        vm.prank(quiniPool.owner());
        vm.expectRevert("Result already set for this match");
        quiniPool.setMatchResult(0, 3, 2);
    }

    // --- calculatePoints (claim-on-read) ---

    function testCalculatePointsReturnsZeroWhenNoResultYet() public {
        address u1 = vm.addr(1);
        _setupActivePoolWith(u1, vm.addr(2));

        // u1 predicts but the owner hasn't set any match result yet
        vm.prank(u1);
        quiniPool.submitPrediction(0, 2, 1);

        assertEq(quiniPool.calculatePoints(u1), 0, "No result set yet should yield 0");
    }

    function testCalculatePointsReturnsZeroForNonPredictor() public {
        address u1 = vm.addr(1);
        address u2 = vm.addr(2);
        _setupActivePoolWith(u1, u2);

        vm.prank(u1);
        quiniPool.submitPrediction(0, 2, 1);

        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(0, 2, 1);

        assertEq(quiniPool.calculatePoints(u2), 0, "Non-predictor should get 0");
    }

    function testCalculatePointsAwardsTenOnExactScore() public {
        address u1 = vm.addr(1);
        _setupActivePoolWith(u1, vm.addr(2));

        vm.prank(u1);
        quiniPool.submitPrediction(0, 2, 1);

        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(0, 2, 1);

        assertEq(quiniPool.calculatePoints(u1), 10, "Exact score should award 10");
    }

    function testCalculatePointsAwardsFourOnHomeWinOutcome() public {
        address u1 = vm.addr(1);
        _setupActivePoolWith(u1, vm.addr(2));

        // u1 predicts 3-1 (home win), actual 2-0 (home win)
        vm.prank(u1);
        quiniPool.submitPrediction(0, 3, 1);

        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(0, 2, 0);

        assertEq(quiniPool.calculatePoints(u1), 4, "Same outcome (home win) should award 4");
    }

    function testCalculatePointsAwardsFourOnDrawOutcome() public {
        address u1 = vm.addr(1);
        _setupActivePoolWith(u1, vm.addr(2));

        // u1 predicts 2-2 (draw), actual 1-1 (draw)
        vm.prank(u1);
        quiniPool.submitPrediction(0, 2, 2);

        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(0, 1, 1);

        assertEq(quiniPool.calculatePoints(u1), 4, "Same outcome (draw) should award 4");
    }

    function testCalculatePointsAwardsFourOnAwayWinOutcome() public {
        address u1 = vm.addr(1);
        _setupActivePoolWith(u1, vm.addr(2));

        // u1 predicts 0-3 (away win), actual 1-2 (away win)
        vm.prank(u1);
        quiniPool.submitPrediction(0, 0, 3);

        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(0, 1, 2);

        assertEq(quiniPool.calculatePoints(u1), 4, "Same outcome (away win) should award 4");
    }

    function testCalculatePointsAwardsZeroOnWrongOutcome() public {
        address u1 = vm.addr(1);
        _setupActivePoolWith(u1, vm.addr(2));

        // u1 predicts home win 3-1, actual away win 0-2
        vm.prank(u1);
        quiniPool.submitPrediction(0, 3, 1);

        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(0, 0, 2);

        assertEq(quiniPool.calculatePoints(u1), 0, "Wrong outcome should award 0");
    }

    function testCalculatePointsSumsAcrossMatches() public {
        address u1 = vm.addr(1);
        _setupActivePoolWith(u1, vm.addr(2));

        // Match 0: exact (10), Match 1: same outcome only (4)
        vm.prank(u1);
        quiniPool.submitPrediction(0, 2, 1);
        vm.prank(u1);
        quiniPool.submitPrediction(1, 3, 1);

        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(0, 2, 1);
        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(1, 2, 0);

        assertEq(quiniPool.calculatePoints(u1), 14, "10 (exact) + 4 (outcome) across matches");
    }

    // --- finishPool ---

    function testFinishPoolRevertsWhenPoolNotActive() public {
        // Pool stays Open
        vm.prank(quiniPool.owner());
        vm.expectRevert("Pool is not active");
        quiniPool.finishPool();
    }

    function testFinishPoolRevertsWhenNotAllResultsSet() public {
        _setupActivePoolWith(vm.addr(1), vm.addr(2));

        // Set result for match 0 only; match 1 still pending
        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(0, 2, 1);

        vm.prank(quiniPool.owner());
        vm.expectRevert("All match results must be set before finishing the pool");
        quiniPool.finishPool();
    }

    function testFinishPoolSuccess() public {
        _setupActivePoolWith(vm.addr(1), vm.addr(2));

        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(0, 2, 1);
        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(1, 0, 0);

        vm.prank(quiniPool.owner());
        quiniPool.finishPool();

        assertEq(uint256(quiniPool.poolStatus()), uint256(QuiniPool.PoolStatus.Finished), "Pool should be Finished");
    }

    // --- claimPrize ---

    function _predict(address u, uint256 matchId, uint8 h, uint8 a) internal {
        vm.prank(u);
        quiniPool.submitPrediction(matchId, h, a);
    }

    function _setResult(uint256 matchId, uint8 h, uint8 a) internal {
        vm.prank(quiniPool.owner());
        quiniPool.setMatchResult(matchId, h, a);
    }

    // Leaderboard: u1=20 (exact+exact), u2=14 (outcome+exact), u3=8 (outcome+outcome), u4=0
    function _setupFinishedPoolWithFourPlayers()
        internal
        returns (address u1, address u2, address u3, address u4)
    {
        u1 = vm.addr(1);
        u2 = vm.addr(2);
        u3 = vm.addr(3);
        u4 = vm.addr(4);
        _joinAsUser(u1);
        _joinAsUser(u2);
        _joinAsUser(u3);
        _joinAsUser(u4);
        quiniPool.startPool();
        _predict(u1, 0, 2, 1);
        _predict(u1, 1, 1, 1);
        _predict(u2, 0, 3, 1);
        _predict(u2, 1, 1, 1);
        _predict(u3, 0, 3, 1);
        _predict(u3, 1, 2, 2);
        _predict(u4, 0, 0, 2);
        _predict(u4, 1, 0, 2);
        _setResult(0, 2, 1);
        _setResult(1, 1, 1);
        vm.prank(quiniPool.owner());
        quiniPool.finishPool();
    }

    function testClaimPrizeRevertsWhenPoolNotFinished() public {
        address u1 = vm.addr(1);
        _joinAsUser(u1);

        vm.prank(u1);
        vm.expectRevert("Pool is not finished yet");
        quiniPool.claimPrize();
    }

    function testClaimPrizeRevertsWhenNotParticipant() public {
        _setupFinishedPoolWithFourPlayers();

        vm.prank(vm.addr(99));
        vm.expectRevert("You did not participate");
        quiniPool.claimPrize();
    }

    function testClaimPrizeRevertsWhenAlreadyClaimed() public {
        (address u1,,,) = _setupFinishedPoolWithFourPlayers();

        vm.prank(u1);
        quiniPool.claimPrize();

        vm.prank(u1);
        vm.expectRevert("Prize already claimed");
        quiniPool.claimPrize();
    }

    function testClaimPrizeRevertsWhenNotInTop3() public {
        (,,, address u4) = _setupFinishedPoolWithFourPlayers();

        vm.prank(u4);
        vm.expectRevert("You are not in the top 3");
        quiniPool.claimPrize();
    }

    function testClaimPrizeFirstPlaceGets50() public {
        (address u1,,,) = _setupFinishedPoolWithFourPlayers();
        uint256 expected = (quiniPool.totalPool() * 50) / 100;

        vm.prank(u1);
        quiniPool.claimPrize();

        assertEq(token.balanceOf(u1), expected, "1st place should get 50%");
    }

    function testClaimPrizeSecondPlaceGets30() public {
        (, address u2,,) = _setupFinishedPoolWithFourPlayers();
        uint256 expected = (quiniPool.totalPool() * 30) / 100;

        vm.prank(u2);
        quiniPool.claimPrize();

        assertEq(token.balanceOf(u2), expected, "2nd place should get 30%");
    }

    function testClaimPrizeThirdPlaceGets20() public {
        (,, address u3,) = _setupFinishedPoolWithFourPlayers();
        uint256 expected = (quiniPool.totalPool() * 20) / 100;

        vm.prank(u3);
        quiniPool.claimPrize();

        assertEq(token.balanceOf(u3), expected, "3rd place should get 20%");
    }

    function testClaimPrizeTiesAboveCountAsOneScore() public {
        // u1=u2=20 (tied 1st), u3=14 (should be 2nd, not 3rd)
        address u1 = vm.addr(1);
        address u2 = vm.addr(2);
        address u3 = vm.addr(3);
        _joinAsUser(u1);
        _joinAsUser(u2);
        _joinAsUser(u3);
        quiniPool.startPool();
        _predict(u1, 0, 2, 1);
        _predict(u1, 1, 1, 1);
        _predict(u2, 0, 2, 1);
        _predict(u2, 1, 1, 1);
        _predict(u3, 0, 3, 1);
        _predict(u3, 1, 1, 1);
        _setResult(0, 2, 1);
        _setResult(1, 1, 1);
        vm.prank(quiniPool.owner());
        quiniPool.finishPool();

        uint256 expectedSecond = (quiniPool.totalPool() * 30) / 100;
        vm.prank(u3);
        quiniPool.claimPrize();
        assertEq(token.balanceOf(u3), expectedSecond, "u3 should be 2nd (ties above count as one)");
    }

    function testClaimPrizeTiedFirstSplitsEvenly() public {
        // u1 and u2 both score 20; u3 and u4 score 0
        address u1 = vm.addr(1);
        address u2 = vm.addr(2);
        _joinAsUser(u1);
        _joinAsUser(u2);
        _joinAsUser(vm.addr(3));
        _joinAsUser(vm.addr(4));
        quiniPool.startPool();
        _predict(u1, 0, 2, 1);
        _predict(u1, 1, 1, 1);
        _predict(u2, 0, 2, 1);
        _predict(u2, 1, 1, 1);
        _setResult(0, 2, 1);
        _setResult(1, 1, 1);
        vm.prank(quiniPool.owner());
        quiniPool.finishPool();

        uint256 halfOfFirst = (quiniPool.totalPool() * 50) / 100 / 2;

        vm.prank(u1);
        quiniPool.claimPrize();
        vm.prank(u2);
        quiniPool.claimPrize();

        assertEq(token.balanceOf(u1), halfOfFirst, "u1 tied 1st should get half of 50%");
        assertEq(token.balanceOf(u2), halfOfFirst, "u2 tied 1st should get half of 50%");
    }
}
