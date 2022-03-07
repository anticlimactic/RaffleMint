pragma solidity ^0.8.11;

import "ds-test/test.sol";
import "./mock/LinkToken.sol";
import "./mock/VRFCoordinatorMock.sol";
import "../Raffle.sol";
import "../Mint.sol";

interface CheatCodes {
    function deal(address who, uint256 newBalance) external;

    function expectRevert(bytes calldata) external;

    function prank(address) external;

    function startPrank(address) external;

    function warp(uint256) external;
}

/// @notice tests for raffle mint
/// @dev this contract is the manager for all deployed contracts
///      and thus "owns" all deployed contracts
contract RaffleMintTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Raffle raffle;
    Mint mint;
    LinkToken linkToken;
    VRFCoordinatorMock vrfCoordinator;
    bytes32 keyhash = 0;
    uint256 fee = 2 * 10**18;
    address[] users;
    uint64 entryCost = 0.08 ether;
    uint16 totalWinners = 5;
    uint256 totalEntrants = 10;
    uint32 depositStart = uint32(block.timestamp) + 1 days;
    uint32 depositEnd = depositStart + 1 weeks;
    uint32 mintStart = depositEnd + 3 days;
    uint32 withdrawStart = depositEnd + 2 weeks;

    function setUp() public {
        linkToken = new LinkToken();
        vrfCoordinator = new VRFCoordinatorMock(address(linkToken));
        mint = new Mint("Test", "TEST");
        raffle = new Raffle(
            address(vrfCoordinator),
            address(linkToken),
            0,
            10**17
        );
        mint.setRaffleContract(address(raffle));
        raffle.setTokenContract(address(mint));

        raffle.configureRaffle(
            entryCost,
            totalWinners,
            depositStart,
            depositEnd,
            mintStart,
            withdrawStart
        );
        cheats.deal(address(0), 1 ether);
        linkToken.transfer(address(raffle), 2 * 10**18);
    }

    modifier loadAccounts() {
        for (uint160 i = 0; i < totalEntrants; i++) {
            cheats.deal(address(i), entryCost);
            users.push(address(i));
        }
        _;
    }

    modifier clearTime() {
        cheats.warp(0);
        _;
    }

    function testConfigureRaffle() public clearTime {
        address alice = address(0);
        Mint _mint = new Mint("Test", "TEST");
        Raffle _raffle = new Raffle(
            address(vrfCoordinator),
            address(linkToken),
            0,
            10**17
        );

        cheats.expectRevert("Ownable: caller is not the owner");
        cheats.prank(alice);
        _raffle.setTokenContract(address(_mint));

        _raffle.setTokenContract(address(_mint));

        uint64 _entryCost = 0.08 ether;
        uint16 _totalWinners = 5;
        uint32 _depositStart = uint32(block.timestamp) + 1 days;
        uint32 _depositEnd = _depositStart + 1 weeks;
        uint32 _mintStart = _depositEnd + 3 days;
        uint32 _withdrawStart = _depositEnd + 2 weeks;

        cheats.expectRevert("Ownable: caller is not the owner");
        cheats.prank(alice);
        _raffle.configureRaffle(
            _entryCost,
            _totalWinners,
            _depositStart,
            _depositEnd,
            _mintStart,
            _withdrawStart
        );

        cheats.expectRevert("deposit period cannot start after end");
        _raffle.configureRaffle(
            _entryCost,
            _totalWinners,
            _depositStart,
            _depositStart - 1 days,
            _mintStart,
            _withdrawStart
        );

        cheats.expectRevert("minting cannot begin before deposit ends");
        _raffle.configureRaffle(
            _entryCost,
            _totalWinners,
            _depositStart,
            _depositEnd,
            _depositEnd - 1 days,
            _withdrawStart
        );

        cheats.expectRevert("lockup period must exceed 1 week");
        _raffle.configureRaffle(
            _entryCost,
            _totalWinners,
            _depositStart,
            _depositEnd,
            _mintStart,
            _mintStart
        );

        _raffle.configureRaffle(
            _entryCost,
            _totalWinners,
            _depositStart,
            _depositEnd,
            _mintStart,
            _withdrawStart
        );
        (
            uint64 entryCost_,
            uint32 totalWinners_,
            ,
            uint32 depositStart_,
            uint32 depositEnd_,
            uint32 mintStart_,
            uint32 withdrawStart_
        ) = raffle.raffle();
        assertEq(entryCost_, _entryCost);
        assertEq(totalWinners_, _totalWinners);
        assertEq(depositStart_, _depositStart);
        assertEq(depositEnd_, _depositEnd);
        assertEq(mintStart_, _mintStart);
        assertEq(withdrawStart_, _withdrawStart);
    }

    function testEnterRaffle() public clearTime {
        address alice = address(0);
        cheats.startPrank(alice);

        cheats.warp(1 days);
        cheats.expectRevert("incorrect Ether amount");
        raffle.enterRaffle{value: 1 ether}();

        uint256 balance = alice.balance;
        raffle.enterRaffle{value: 0.08 ether}();
        (, uint248 amountDeposited) = raffle.entries(alice);
        assertEq(amountDeposited, 0.08 ether);
        assertEq(address(raffle).balance, 0.08 ether);

        cheats.expectRevert("already entered");
        raffle.enterRaffle{value: 0.08 ether}();
    }

    function testEnterRaffleTimestamps() public clearTime {
        address alice = address(0);
        cheats.startPrank(alice);

        cheats.expectRevert("before deposit start time");
        raffle.enterRaffle{value: 0.08 ether}();

        cheats.warp(depositEnd + 1 seconds);

        cheats.expectRevert("after deposit end time");
        raffle.enterRaffle{value: 0.08 ether}();
    }

    function testWithdrawEntryCostWithNoBalance() public clearTime {
        address alice = address(0);
        cheats.startPrank(alice);

        cheats.expectRevert("cannot withdraw yet");
        raffle.withdrawEntryCost();

        cheats.warp(withdrawStart + 1 seconds);
        cheats.expectRevert("no balance");
        raffle.withdrawEntryCost();
    }

    function testWithdrawEntryCostWithBalance() public clearTime {
        address alice = address(0);
        cheats.startPrank(alice);

        cheats.warp(depositStart);
        raffle.enterRaffle{value: 0.08 ether}();
        assertEq(alice.balance, 0.92 ether);

        cheats.warp(withdrawStart + 1 seconds);
        raffle.withdrawEntryCost();
        (, uint248 amountDeposited) = raffle.entries(alice);
        assertEq(alice.balance, 1 ether);
        assertEq(amountDeposited, 0);
    }

    function testWithdrawOwnerFunds() public clearTime {
        address alice = address(0);

        cheats.expectRevert("cannot withdraw yet");
        raffle.withdrawOwnerFunds();

        cheats.expectRevert("Ownable: caller is not the owner");
        cheats.prank(alice);
        raffle.withdrawOwnerFunds();

        cheats.warp(withdrawStart);
        cheats.expectRevert("no balance");
        raffle.withdrawOwnerFunds();
    }

    function testSelectWinners() public clearTime loadAccounts {
        address[] storage _users = users;
        cheats.warp(depositStart);
        for (uint256 i = 0; i < totalEntrants; i++) {
            cheats.prank(_users[i]);
            raffle.enterRaffle{value: 0.08 ether}();
        }

        cheats.expectRevert("before deposit end time");
        raffle.fetchNonce();

        cheats.expectRevert("before deposit end time");
        raffle.selectWinners(1);

        cheats.warp(depositEnd + 1 seconds);

        cheats.expectRevert("vrf not called yet");
        raffle.selectWinners(1);

        bytes32 requestId = raffle.fetchNonce();
        vrfCoordinator.callBackWithRandomness(requestId, 777, address(raffle));
        assertGt(raffle.nonceCache(), 0);
        uint256 nonce = raffle.nonceCache();

        cheats.expectRevert("out of mints");
        raffle.selectWinners(10);

        raffle.selectWinners(1);
        nonce = uint256(keccak256(abi.encodePacked(nonce)));
        uint256 index = nonce % 10;

        (bool hasWon, ) = raffle.entries(_users[index]);
        assertTrue(hasWon);
        _users[index] = _users[9];
        _users.pop();

        raffle.selectWinners(4);
        for (uint256 i = 0; i < 4; i++) {
            nonce = uint256(keccak256(abi.encodePacked(nonce)));
            index = nonce % (9 - i);
            (hasWon, ) = raffle.entries(_users[index]);
            assertTrue(hasWon);
            _users[index] = _users[9 - i - 1];
            _users.pop();
        }

        assertEq(address(raffle).balance, 0.8 ether);

        cheats.expectRevert("out of mints");
        raffle.selectWinners(1);
    }

    function testSelectWinnersRevertAfterMintStart() public clearTime {
        cheats.warp(mintStart + 1 seconds);

        cheats.expectRevert("after mint start time");
        raffle.selectWinners(1);
    }

    function testClaimToken() public clearTime loadAccounts {
        address[] storage _users = users;
        address alice = address(0);

        cheats.expectRevert("claiming is not active");
        raffle.claimToken();

        cheats.warp(depositStart);
        for (uint256 i = 0; i < totalEntrants; i++) {
            cheats.prank(_users[i]);
            raffle.enterRaffle{value: 0.08 ether}();
        }

        assertEq(address(raffle).balance, 0.8 ether);

        cheats.warp(depositEnd + 1 seconds);
        bytes32 requestId = raffle.fetchNonce();
        vrfCoordinator.callBackWithRandomness(requestId, 777, address(raffle));

        cheats.expectRevert("out of mints");
        raffle.selectWinners(10);

        raffle.selectWinners(1);

        cheats.warp(mintStart);
        cheats.expectRevert("caller did not win");
        cheats.prank(alice);
        raffle.claimToken();

        address winner = _users[1];
        cheats.prank(winner);
        raffle.claimToken();
        assertEq(mint.balanceOf(winner), 1);

        cheats.warp(withdrawStart + 1 seconds);
        cheats.prank(alice);
        raffle.withdrawEntryCost();
        assertEq(alice.balance, 0.08 ether);
        assertEq(address(raffle).balance, 0.72 ether);
        assertEq(raffle.totalDepositAmount(), 0.64 ether);

        uint256 balance = address(this).balance;
        raffle.withdrawOwnerFunds();
        assertEq(address(this).balance, balance + 0.08 ether);
        assertEq(address(raffle).balance, 0.64 ether);
        assertEq(raffle.totalDepositAmount(), 0.64 ether);

        (bool hasWon, uint248 amountDeposited) = raffle.entries(winner);
        assertTrue(hasWon);
        assertEq(amountDeposited, 0);
    }

    function testLockedContract() public clearTime {
        Mint _mint = new Mint("Test", "TEST");
        Raffle _raffle = new Raffle(
            address(vrfCoordinator),
            address(linkToken),
            0,
            10**17
        );

        cheats.expectRevert("token contract not set");
        _raffle.configureRaffle(
            entryCost,
            totalWinners,
            depositStart,
            depositEnd,
            mintStart,
            withdrawStart
        );

        _raffle.setTokenContract(address(_mint));

        _raffle.configureRaffle(
            entryCost,
            totalWinners,
            depositStart,
            depositEnd,
            mintStart,
            withdrawStart
        );

        cheats.expectRevert("contract is locked");
        _raffle.configureRaffle(
            entryCost,
            totalWinners,
            depositStart,
            depositEnd,
            mintStart,
            withdrawStart
        );

        cheats.expectRevert("contract is locked");
        _raffle.setTokenContract(address(_mint));
    }

    receive() external payable {}
}
