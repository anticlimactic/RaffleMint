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
}

contract MintTest is DSTest {
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

        uint16 totalWinners = 10;
        uint32 depositStart = uint32(block.timestamp) + 1 days;
        uint32 depositEnd = depositStart + 1 weeks;
        uint32 mintStart = depositEnd + 3 days;
        uint32 mintEnd = mintStart + 1 weeks;
        uint32 withdrawStart = depositEnd + 2 weeks;
        raffle.configureRaffle(
            0.08 ether,
            totalWinners,
            depositStart,
            depositEnd,
            mintStart,
            withdrawStart
        );
    }

    function testSetRaffleContract() public {
        cheats.prank(address(0));
        cheats.expectRevert("Ownable: caller is not the owner");
        mint.setRaffleContract(address(raffle));

        mint.setRaffleContract(address(raffle));
        assertEq(mint.raffleContract(), address(raffle));
    }
}
