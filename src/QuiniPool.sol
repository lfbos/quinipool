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
        uint8 predictedHomeScore;
        uint8 predictedAwayScore;
        bool wasPredicted;
    }

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
    mapping(address => uint256) public points;
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
    event PlayerJoined(address indexed player, uint256 entryFee);

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
}
