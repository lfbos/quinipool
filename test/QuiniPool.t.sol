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
}
