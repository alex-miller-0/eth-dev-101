// NOTE: THIS IS NOT YET FUNCTIONAL!!!

// This is a proof-of-concept of a token relay between chains.
// A user deposits tokens to this contract and chooses the destination chain.
// The relayer is incentivized with a small fee to replay the message on the
// desired chain.
// A separate chain must have a token that maps 1:1 to the current chain.
// In the case of a new chain, the relayer contract would initially own all
// the tokens (but they would be locked up).
pragma solidity ^0.4.18;

import "tokens/Token.sol";  // truffle package (install with `truffle install tokens`)

contract TrustedRelay {
  uint public fee;
  uint public chainId = 1;
  address owner;
  mapping (address => mapping(address => uint)) balances;
  // Maps originating chain id and token address to new address. This requires
  // tokens be recreated on this chain before any such mappings can occur.
  mapping (uint => mapping(address => address)) tokens;

  event Deposit(address indexed sender, address indexed token, uint indexed toChain, uint amount, uint timestamp);
  event UndoDeposit(address indexed sender, address indexed token, uint indexed toChain, uint amount, uint timestamp);
  event RelayedDeposit(address indexed sender, address indexed oldToken, address newToken, uint indexed fromChain, uint amount, uint timestamp);


  function TrustedRelay() {
    owner = msg.sender;
  }

  function changeFee(uint newFee) public {
    assert(msg.sender == owner);
    fee = newFee;
  }

  // Make a deposit to another chain. This locks up the tokens on this chain.
  // They will appear in the other chain for withdrawal.
  // Note that the user must pay exactly the fee
  function deposit(bytes32 m, uint8 v, bytes32 r, bytes32 s, address token, uint amount, uint[2] chainIds) public {
    assert(msg.value == fee);
    assert(m == keccak256(chainIds[0], chainIds[1], token, amount, msg.sender));
    assert(chainIds[0] == chainId);
    address sender = ecrecover(m, v, r, s);
    assert(msg.sender == sender);
    Token t = Token(token);
    t.transfer(address(this), amount);
    address(this).send(msg.value);
    Deposit(msg.sender, token, chainIds[1], amount, now);
  }

  // Relayer only
  // Unfreeze tokens on this chain.
  // addrs = [ token, originalSender ]
  function relayedDeposit(bytes32 m, uint8 v, bytes32 r, bytes32 s, address[2] addrs, uint amount, uint[2] chainIds) public {
    assert(m == keccak256(chainIds[0], chainIds[1], addrs[0], amount, addrs[1]));
    assert(chainIds[0] == chainId);
    address sender = ecrecover(m, v, r, s);
    assert(addrs[1] == sender);
    address mappedToken = tokens[chainIds[0]][addrs[1]];
    assert(mappedToken != address(0));
    Token t = Token(mappedToken);
    assert(t.balanceOf(address(this)) >= amount);
    t.transfer(sender, amount);
    RelayedDeposit(sender, addrs[0], mappedToken, chainIds[0], amount, now);
  }

  // If there is not a matching token on the other chain or some other error
  // occurred, the relayer can bring it back to this chain.
  // addrs = [ token, originalSender ]
  function undoDeposit(bytes32 m, uint8 v, bytes32 r, bytes32 s, address[2] addrs, uint amount, uint[2] chainIds) public {
    assert(m == keccak256(chainIds[0], chainIds[1], addrs[0], amount, addrs[1]));
    assert(chainIds[0] == chainId);
    address sender = ecrecover(m, v, r, s);
    assert(addrs[1] == sender);
    Token t = Token(addrs[0]);
    t.transfer(sender, amount);
    UndoDeposit(sender, addrs[0], chainIds[1], amount, now);
  }

}
