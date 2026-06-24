// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract QuiniPool {
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
    address public owner;
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
}
