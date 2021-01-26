// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.7.4;

contract MultiSig {
    address[] public owners;
    uint public numConfirmationsRequired;
    Transaction[] public transactions;
    
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }
    
    mapping (address => bool) public isOwner;
    mapping (uint => mapping (address => bool)) public isConfirmed;
    
    modifier onlyOwner {
    require(isOwner[msg.sender], "You are not allowed.");
    _;
    }
  
    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "Tx does not exist.");
        _;
    }
  
    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "Tx already executed.");
        _;
    }
    
    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "Tx already confirmed.");
        _;
    }
    
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(address indexed owner, uint txIndex, address indexed to, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeTransaction(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);
    
    
    constructor (address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "owners required.");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "Invalid number of required confirmations");
        
        for (uint8 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            
            require(owner != address(0), "Invalid address");
            require(!isOwner[owner], "Owner not unique");
            
            isOwner[owner] = true;
            owners.push(owner);
        }
        
        numConfirmationsRequired = _numConfirmationsRequired;
  }
  
  receive() payable external {
      emit Deposit(msg.sender, msg.value, address(this).balance);
  }
  
  function submitTransaction(address _to, uint _value, bytes memory _data) external onlyOwner {
      uint txIndex = transactions.length;
      
      transactions.push(Transaction({
          to: _to,
          value: _value,
          data: _data,
          executed: false,
          numConfirmations: 0
      }));
      
      emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
  }

  function confirmTransaction(uint _txIndex)
        external
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }
  
  function executeTransaction(uint _txIndex)
        external
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

  function revokeConfirmation(uint _txIndex) 
        external
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
  {
        Transaction memory transaction = transactions[_txIndex];
        require(isConfirmed[_txIndex][msg.sender], "Tx not confirmed.");
        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeTransaction(msg.sender, _txIndex);
  }

  function getOwners() external view returns(address[] memory) {
      return owners;
  }

  function getTransactionCount() external view returns(uint) {
      return transactions.length;
  }

  function getTransaction(uint _txIndex)
        public
        view
        returns (address to, uint value, bytes memory data, bool executed, uint numConfirmations)
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    } 
    // ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"]
    // ["0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB", "1000000000000000000", "0x0000000000000000000000000000000000000000"]
}