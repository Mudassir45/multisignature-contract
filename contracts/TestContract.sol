// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.7.4;

contract TestContract {
    uint public i;

    function callMe(uint j) external {
        i += j;
    }

    function getData(uint _data) external pure returns (bytes memory) {
        return abi.encodeWithSignature("callMe(uint256)", _data);
    }
}