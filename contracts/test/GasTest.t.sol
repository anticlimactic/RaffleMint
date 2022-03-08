pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "./mock/LinkToken.sol";
import "./mock/VRFCoordinatorMock.sol";
import "../Raffle.sol";
import "../Mint.sol";

interface CheatCodes {
    function deal(address who, uint256 newBalance) external;

    function expectEmit(
        bool,
        bool,
        bool,
        bool
    ) external;

    function expectRevert(bytes calldata) external;

    function prank(address) external;

    function startPrank(address) external;

    function warp(uint256) external;
}

contract GasTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Raffle raffle;
    Mint mint;
    LinkToken linkToken;
    VRFCoordinatorMock vrfCoordinator;
    bytes32 keyhash = 0;
    uint256 fee = 2 * 10**18;
    address[] users;

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
        raffle.setTokenContract(address(mint));

        uint32 depositStart = uint32(block.timestamp) + 1 days;
        uint32 depositEnd = depositStart + 1 weeks;
        uint32 mintStart = depositEnd + 3 days;
        uint32 mintEnd = mintStart + 1 weeks;
        uint32 withdrawStart = depositEnd + 2 weeks;
        uint16 totalWinners = 200;
        raffle.configureRaffle(
            0.08 ether,
            totalWinners,
            depositStart,
            depositEnd,
            mintStart,
            withdrawStart
        );
        cheats.deal(address(0), 1000 ether);
        users.push(address(0));
        linkToken.transfer(address(raffle), 2 * 10**18);
        for (uint160 i = 1; i < 1000; i++) {
            cheats.deal(address(i), 0.08 ether);
            users.push(address(i));
        }
    }

    function testGas() public {
        cheats.warp(1 days);
        for (uint160 i = 1; i < users.length; i++) {
            cheats.prank(address(i));
            raffle.enterRaffle{value: 0.08 ether}();
        }

        cheats.warp(block.timestamp + 1 weeks);

        bytes32 requestId = raffle.fetchNonce();
        vrfCoordinator.callBackWithRandomness(requestId, 777, address(raffle));

        (, uint32 totalWinners, , , , , ) = raffle.raffle();
        uint256 repetitions = totalWinners / 100;
        for (uint256 i = 0; i < repetitions; i++) {
            raffle.selectWinners(100);
        }
    }
}
