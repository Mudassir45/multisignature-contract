// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.7.4;

contract MultisigV2 {
    uint256 private sequenceId;
    mapping(address => bool) public signers;

    event Deposited(address from, uint256 value, bytes data);
    event Transacted(
        address msgSender, 
        address otherSigner, 
        bytes32 operation,
        address toAddress,
        uint256 value,
        bytes data
    );

    modifier onlySigner {
        require(signers[msg.sender], "You are not allowed.");
        _;
    }

    constructor(address[] memory allowedSigners) {
        require(allowedSigners.length == 3, "Invalid number of signers.");

        for (uint8 i = 0; i < allowedSigners.length; i++) {
            require(allowedSigners[i] != address(0), "Invalid signer.");
            signers[allowedSigners[i]] = true;
        }
    }

    receive() payable external {
        if(msg.value > 0) {
            emit Deposited(msg.sender, msg.value, msg.data);
        }
    }

    function sendMultiSig(
        address _toAddress,
        uint256 _value,
        bytes calldata _data,
        uint256 _expireTime,
        bytes calldata _signature
    )
        external
        onlySigner
    {
        bytes32 operationHash = keccak256(
            abi.encodePacked(
                _toAddress,
                _value,
                _data,
                _expireTime,
                sequenceId
            )
        );

        address otherSigner = verifyMultiSig(
            operationHash,
            _signature,
            _expireTime
        );

        (bool success, ) = _toAddress.call{ value: _value }(_data);
        require(success, "Call execution failed");

        emit Transacted(msg.sender, otherSigner, operationHash, _toAddress, _value, _data);
    }

    function verifyMultiSig(
        bytes32 operationHash,
        bytes calldata signature,
        uint256 expireTime
    )
        internal
        returns (address)
    {
        address otherSigner = recoverAddressFromSignature(operationHash, signature);

        require(expireTime >= block.timestamp, "Transaction has expired.");
        sequenceId += 1;

        require(signers[otherSigner], "Invalid signer.");
        require(otherSigner != msg.sender, "Invalid signer.");

        return otherSigner;
    }

    function recoverAddressFromSignature(
        bytes32 operationHash,
        bytes memory signature
    ) 
        private 
        pure 
        returns (address) 
    {
        require(signature.length == 65, "Invalid signature - wrong length");

        // We need to unpack the signature, which is given as an array of 65 bytes (like eth.sign)
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
        r := mload(add(signature, 32))
        s := mload(add(signature, 64))
        v := and(mload(add(signature, 65)), 255)
        }
        if (v < 27) {
        v += 27; // Ethereum versions are 27 or 28 as opposed to 0 or 1 which is submitted by some signing libs
        }

        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "ECDSA: invalid signature 's' value");

        return ecrecover(operationHash, v, r, s);
    }
}