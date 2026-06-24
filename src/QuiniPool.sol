// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract QuiniPool is Ownable {
    using SafeERC20 for IERC20;

    // Enums
    enum PoolStatus {
        Open,
        Active,
        Finished
    }

    enum Outcome {
        HomeWin,
        Draw,
        AwayWin
    }

    // Structs
    struct Match {
        string homeTeam;
        string awayTeam;
        uint256 kickoffTime;
        uint8 homeScore;
        uint8 awayScore;
        bool resultSet;
    }

    struct Prediction {
        uint8 homeScore;
        uint8 awayScore;
        bool wasPredicted;
    }

    // Scoring rules
    uint256 private constant POINTS_EXACT_SCORE = 10;
    uint256 private constant POINTS_OUTCOME_ONLY = 4;

    // State variables
    IERC20 public token;
    uint256 public entryFee;
    uint256 public totalPool;
    uint256 public totalMatches;
    PoolStatus public poolStatus;
    address[] public participants;

    // Mappings
    mapping(uint256 => Match) public matches;
    mapping(address => bool) public hasParticipated;
    mapping(address => mapping(uint256 => Prediction)) public predictions;

    constructor(
        IERC20 _token,
        uint256 _entryFee,
        string[] memory _homeTeams,
        string[] memory _awayTeams,
        uint256[] memory _kickoffTimes
    ) Ownable(msg.sender) {
        // Validations
        require(_entryFee > 0, "Entry fee must be greater than zero");
        require(_homeTeams.length > 0, "At least one match must be provided");
        require(
            _homeTeams.length == _awayTeams.length && _homeTeams.length == _kickoffTimes.length,
            "Input arrays must have the same length"
        );

        token = _token;
        entryFee = _entryFee;
        totalMatches = _homeTeams.length;

        // Initialize matches
        for (uint256 i = 0; i < totalMatches; i++) {
            matches[i] = Match({
                homeTeam: _homeTeams[i],
                awayTeam: _awayTeams[i],
                kickoffTime: _kickoffTimes[i],
                homeScore: 0,
                awayScore: 0,
                resultSet: false
            });
        }

        poolStatus = PoolStatus.Open;
    }

    // Events
    event PoolStarted(uint256 totalParticipants, uint256 totalPool);
    event PoolFinished(uint256 totalPool);
    event PlayerJoined(address indexed player, uint256 entryFee);
    event PredictionSubmitted(address indexed player, uint256 matchId, uint8 homeScore, uint8 awayScore);
    event MatchResultSet(uint256 matchId, uint8 homeScore, uint8 awayScore);

    // Functions

    function startPool() external onlyOwner {
        require(poolStatus == PoolStatus.Open, "Pool is not open");
        require(participants.length >= 2, "Need at least 2 participants to start the pool");

        poolStatus = PoolStatus.Active;

        emit PoolStarted(participants.length, totalPool);
    }

    function joinPool() external {
        require(poolStatus == PoolStatus.Open, "Pool is not open for joining");
        require(!hasParticipated[msg.sender], "Already joined the pool");

        // Mark the participant as joined
        hasParticipated[msg.sender] = true;

        // Add the participant to the list
        participants.push(msg.sender);

        // Add the entry fee to the total pool
        totalPool += entryFee;

        // Transfer the entry fee from the participant to the contract
        token.safeTransferFrom(msg.sender, address(this), entryFee);

        // Emit an event PlayerJoined
        emit PlayerJoined(msg.sender, entryFee);
    }

    function submitPrediction(uint256 _matchId, uint8 _homeScore, uint8 _awayScore) external {
        require(poolStatus == PoolStatus.Active, "Pool is not active");
        require(hasParticipated[msg.sender], "You must join the pool first");
        require(_matchId < totalMatches, "Invalid match ID");
        require(block.timestamp < matches[_matchId].kickoffTime, "Cannot submit prediction after kickoff");

        // Store the prediction
        predictions[msg.sender][_matchId] =
            Prediction({homeScore: _homeScore, awayScore: _awayScore, wasPredicted: true});

        emit PredictionSubmitted(msg.sender, _matchId, _homeScore, _awayScore);
    }

    function setMatchResult(uint256 _matchId, uint8 _homeScore, uint8 _awayScore) external onlyOwner {
        require(poolStatus == PoolStatus.Active, "Pool is not active");
        require(_matchId < totalMatches, "Invalid match ID");
        require(!matches[_matchId].resultSet, "Result already set for this match");

        matches[_matchId].homeScore = _homeScore;
        matches[_matchId].awayScore = _awayScore;
        matches[_matchId].resultSet = true;

        emit MatchResultSet(_matchId, _homeScore, _awayScore);
    }

    function finishPool() external onlyOwner {
        require(poolStatus == PoolStatus.Active, "Pool is not active");

        // Ensure all match results are set
        for (uint256 i = 0; i < totalMatches; i++) {
            require(matches[i].resultSet, "All match results must be set before finishing the pool");
        }

        poolStatus = PoolStatus.Finished;

        emit PoolFinished(totalPool);
    }

    function calculatePoints(address _user) public view returns (uint256 total) {
        for (uint256 i = 0; i < totalMatches; i++) {
            Match storage m = matches[i];
            if (!m.resultSet) continue;

            Prediction storage pred = predictions[_user][i];
            if (!pred.wasPredicted) continue;

            total += _pointsFor(pred.homeScore, pred.awayScore, m.homeScore, m.awayScore);
        }
    }

    // 10 = exact score, 4 = same 1X2 outcome, 0 = otherwise
    function _pointsFor(uint8 _predHome, uint8 _predAway, uint8 _matchHome, uint8 _matchAway)
        internal
        pure
        returns (uint256)
    {
        if (_predHome == _matchHome && _predAway == _matchAway) return POINTS_EXACT_SCORE;
        if (_outcome(_predHome, _predAway) == _outcome(_matchHome, _matchAway)) return POINTS_OUTCOME_ONLY;
        return 0;
    }

    function _outcome(uint8 _home, uint8 _away) internal pure returns (Outcome) {
        if (_home > _away) return Outcome.HomeWin;
        if (_home < _away) return Outcome.AwayWin;
        return Outcome.Draw;
    }
}
