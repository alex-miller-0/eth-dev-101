/*
Atomic swap contract
This is a trustless swap that can occur either on the same chain or on different
blockchains. Two users meet and exchange ERC20 tokens. Both of their signatures
are required to unlock either token. Thus, one user must give up a signature first.
Once the first set of tokens is unlocked, the contract emits both sets of signatures
which are used to unlock the other tokens.

IMPORTANT NOTE: This scheme requires two separate contract instances. If you are
conducting an atomic swap with a counterparty and you start, then you are doing
a forward swap and they need to do a backward swap on their contract. Users should
make sure they have verified the counterparty's codebase and that the counterparty
has started a swap in the opposite direction they have (e.g. if you do a backward
swap, your counterparty must do a forward swap).

An expiration timestamp is included when a swap starts. This is to guard against
counterparties that go silent. Again, users should be mindful of this and should
ensure their counterparty has a sufficient timeout.
*/

pragma solidity ^0.4.18;

import "tokens/Token.sol";  // truffle package (install with `truffle install tokens`)

contract AtomicSwap {

  struct Swap {
    address agentA;
    address agentB;
    uint amountA;
    uint amountB;
    address tokenA;
    address tokenB;
    bool isForward;
    uint timeout;
  }
  mapping (bytes32 => Swap) Swaps;

  event SwapStarted(bytes32 indexed id, address[2] agents, uint[2] amounts, address[2] tokens, bool forward);
  event SwapClaimed(bytes32 indexed id, uint v1, bytes32 r1, bytes32 s1, uint v2, bytes32 r2, bytes32 s2);
  event SwapRescinded(bytes32 indexed id, uint timestamp);
  //===============================
  // STATE UPDATING FUNCTIONS
  //===============================

  // Start a swap. Variables:
  // address counterparty - the address you are interacting with (typically on another chain)
  // bytes32 id           - the agreed-upon transaction id
  // uint[2] amounts      - [ amount of your token to sell, amount of their token to buy ]
  // uint[2] tokens       - [ your token to sell, their token to buy ]
  // bool    isForward    - true if you are starting this swap. Your counterparty
  //                        will need to start a contract with the opposite value
  // uint    timeout      - timestamp at which this swap will expire. The creator can withdraw
  //                        their tokens at that point.
  function startSwap(address counterparty, bytes32 id, uint[2] amounts,
  address[2] tokens, bool isForward, uint timeout) public {

    // Make sure this id has not been used and that the timeout is in the future
    assert(Swaps[id].agentA == address(0));
    assert(timeout > now);
    Swap memory swap;

    // "Forward" indicates that all items ending in A (e.g. agentA) belong to you.
    if (isForward) {
      swap.agentA = msg.sender;
      swap.agentB = counterparty;
      swap.amountA = amounts[0];  // The amount of THIS token
      swap.amountB = amounts[1];  // The amount of the other token (on the other chain)
      swap.tokenA = tokens[0]; // THIS token
      swap.tokenB = tokens[1]; // The other token on the other chain
      Token forwardToken = Token(tokens[0]);
      forwardToken.transfer(address(this), amounts[0]);
    } else {
      swap.agentA = counterparty;
      swap.agentB = msg.sender;
      swap.amountB = amounts[0];  // The amount of THIS token
      swap.amountA = amounts[1];  // The amount of the other token (on the other chain)
      swap.tokenB = tokens[0]; // THIS token
      swap.tokenA = tokens[1]; // The other token on the other chain
      Token backwardToken = Token(tokens[1]);
      backwardToken.transfer(address(this), amounts[1]);
    }

    swap.timeout = timeout;
    swap.isForward = isForward;

    // Create the swap
    Swaps[id] = swap;
    SwapStarted(id, [ swap.agentA, swap.agentB ], [ swap.amountA, swap.amountB ],
    [ swap.tokenA, swap.tokenB ], isForward);
  }


  // The counterparty will use their signature and your signature (both signing the
  // same data) to unlock their tokens. This will emit both signatures so you can
  // use it in their swap contract.
  function forwardSwap(bytes32 id, bytes32 h, uint8[2] v, bytes32[2] r, bytes32[2] s) public {
    checkHash(id, h, true);
    checkSigs(id, h, v, r, s);
    Token token = Token(Swaps[id].tokenA);
    token.transfer(Swaps[id].agentB, Swaps[id].amountA);
    SwapClaimed(id, v[0], r[0], s[0], v[1], r[1], s[1]);
    delete Swaps[id];
  }


  function backwardSwap(bytes32 id, bytes32 h, uint8[2] v, bytes32[2] r, bytes32[2] s) public {
    checkHash(id, h, false);
    checkSigs(id, h, v, r, s);
    Token token = Token(Swaps[id].tokenB);
    token.transfer(Swaps[id].agentA, Swaps[id].amountA);
    SwapClaimed(id, v[0], r[0], s[0], v[1], r[1], s[1]);
    delete Swaps[id];
  }

  function rescind(bytes32 id) public {
    assert(Swaps[id].timeout < now);
    if (Swaps[id].isForward) {
      assert(msg.sender == Swaps[id].agentA);
      Token forwardToken = Token(Swaps[id].tokenA);
      forwardToken.transfer(msg.sender, Swaps[id].amountA);
    } else {
      assert(msg.sender == Swaps[id].agentB);
      Token backwardToken = Token(Swaps[id].tokenB);
      backwardToken.transfer(msg.sender, Swaps[id].amountB);
    }
    SwapRescinded(id, now);
    delete Swaps[id];

  }


  //===============================
  // CONSTANT FUNCTIONS
  //===============================

  // Check the hash against the Swap struct data. The order of the data will
  // depend on whether this is a forward or backward swap.
  function checkHash(bytes32 id, bytes32 h, bool isForward) internal constant {
    if (isForward) {
      assert(sha256(id, Swaps[id].tokenA, Swaps[id].tokenB, Swaps[id].amountA, Swaps[id].amountB) == h);
    } else {
      assert(sha256(id, Swaps[id].tokenB, Swaps[id].tokenA, Swaps[id].amountB, Swaps[id].amountA) == h);
    }
    return;
  }

  // Check signatures. You need to submit signatures on the same data from both
  // parties. The order doesn't matter.
  function checkSigs(bytes32 id, bytes32 h, uint8[2] v, bytes32[2] r, bytes32[2] s) internal constant {
    address signerA = ecrecover(h, v[0], r[0], s[0]);
    assert(signerA == Swaps[id].agentA || signerA == Swaps[id].agentB);
    address signerB = ecrecover(h, v[0], r[0], s[0]);
    assert(signerB == Swaps[id].agentA || signerB == Swaps[id].agentB);
    assert(signerB != signerA);
    return;
  }

}
