// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10; // solhint-disable-line

import "openzeppelin/contracts/token/ERC20/ERC20.sol";
import "chainlink/contracts/src/v0.8/interfaces/ERC677ReceiverInterface.sol";

contract LinkToken is ERC20 {
    uint256 public constant _totalSupply = 10**27;
    mapping(address => mapping(address => uint256)) allowed;

    constructor() ERC20("Chainlink Token", "LINK") {
        _mint(msg.sender, _totalSupply);
    }

    /**
     * @dev transfer token to a specified address with additional data if the recipient is a contract.
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     * @param _data The extra data to be passed to the receiving contract.
     */
    function transferAndCall(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) public returns (bool success) {
        super.transfer(_to, _value);
        emit Transfer(msg.sender, _to, _value);
        if (isContract(_to)) {
            contractFallback(_to, _value, _data);
        }
        return true;
    }

    function contractFallback(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) private {
        ERC677ReceiverInterface receiver = ERC677ReceiverInterface(_to);
        receiver.onTokenTransfer(msg.sender, _value, _data);
    }

    function isContract(address _addr) private view returns (bool hasCode) {
        uint256 length;
        assembly {
            length := extcodesize(_addr)
        }
        return length > 0;
    }
}
