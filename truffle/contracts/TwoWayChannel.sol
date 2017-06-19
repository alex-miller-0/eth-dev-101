pragma solidity ^0.4.8;
import "./ERC20.sol";

contract TwoWayChannel {

  //============================================================================
  // GLOBAL VARIABLES
  //============================================================================

  struct Channel {
    address agentA;
    address agentB;
    address token;
    uint depositA;       // Deposit of agent A
    uint depositB;       // Deposit of agent B
    bool openA;          // True if A->B is open
    bool openB;          // True if B->A is open
  }

  mapping (bytes32 => Channel) channels;
  mapping (address => mapping(address => bytes32)) active_ids;


  //============================================================================
  // STATE TRANSITION FUNCTIONS
  //============================================================================

	/**
	 * Open a channel with a recipient. A non-zero message value must be included.
   *
	 * address token    Address of token contract
	 * address to       Address of recipient
   * uint amount      Number of token quanta to send
	 */
	function OpenChannel(address token, address to, uint amount) {
    // Sanity checks
    if (amount == 0) { throw; }
    if (to == msg.sender) { throw; }
    if (active_ids[msg.sender][to] != bytes32(0)) { throw; }

    // Create a channel
    bytes32 id = sha3(msg.sender, to, now);

    // Initialize the channel
    Channel memory _channel;
    _channel.agentA = msg.sender;
    _channel.agentB = to;
    _channel.token = token;
    _channel.depositA = amount;     // Note that the actor opening the channel is actorA
    _channel.openA = true;
    _channel.openB = true;

    // Make the deposit
    ERC20 t = ERC20(token);
    if (!t.transferFrom(msg.sender, address(this), amount)) { throw; }

    channels[id] = _channel;

    // Add it to the lookup table
    active_ids[msg.sender][to] = id;
	}


  /**
   * Add to either depositA or depositB
   *
   * bytes32 id     Channel id
   * uint amount    Amount of tokens to be deposited
   */
  function AddDeposit(bytes32 id, uint amount) {
    // Make sure the channel exists
    if (channels[id].token == address(0)) { throw; }

    Channel memory _channel;
    _channel = channels[id];
    ERC20 t = ERC20(_channel.token);

    // As long as the channel exists, either party can add to the deposit
    if (msg.sender == _channel.agentA && _channel.openA == true) {
      if (!t.transferFrom(msg.sender, address(this), amount)) { throw; }
      _channel.depositA += amount;
    } else if (msg.sender == _channel.agentB && _channel.openB == true) {
      if (!t.transferFrom(msg.sender, address(this), amount)) { throw; }
      _channel.depositB += amount;
    } else {
      throw;
    }

  }


	/**
	 * Close a channel at any time. May only be called by sender or recipient.
   * The "value" is sent to the recipient and the remainder is refunded to the sender.
	 *
	 * bytes32 id     Identifier of "channels" mapping
	 * bytes32 h      [ id, msg_hash, r, s ]
	 * uint8 v        Component of signature of "h" coming from sender
	 * bytes32 r      Component of signature of "h" coming from sender
	 * bytes32 s      Component of signature of "h" coming from sender
	 * uint value     Amount of wei sent
	 */
	function CloseChannel(bytes32[4] h, uint8 v, uint256 value) {
    // h[0]    Channel id
    // h[1]    Hash of (id, value)
    // h[2]    r of signature
    // h[3]    s of signature

    // Make sure the channel is open
    if (channels[h[0]].token == address(0)) { throw; }
    Channel memory _channel;
    _channel = channels[h[0]];

    if (msg.sender != _channel.agentA && msg.sender != _channel.agentB) { throw; }

    // Get the message signer and construct a proof
    address signer = ecrecover(h[1], v, h[2], h[3]);
    bytes32 proof = sha3(h[0], value);
    // Make sure the hash provided is of the channel id and the amount sent
    // Ensure the proof matches, send the value, send the remainder, and delete the channel
    if (proof != h[1]) { throw; }

    // Pay recipient and refund sender the remainder
    ERC20 t = ERC20(_channel.token);

    if (msg.sender == _channel.agentA && signer == _channel.agentB) {
      // Close out the B->A side of the channel
      if (value > _channel.depositB) { throw; }

      if (!t.transfer(_channel.agentA, value)) { throw; }
      else if (!t.transfer(_channel.agentB, _channel.depositB-value)) { throw; }
      // Close this side of the channel
      _channel.openB = false;
      // Close the other side if no deposit was ever made
      if (_channel.depositA == 0) {
        _channel.openA = false;
      }
      // Update the state
      channels[h[0]] = _channel;
    } else if (msg.sender == _channel.agentB && signer == _channel.agentA) {
      // Close out the A->B side of the channel
      if (value > _channel.depositA) { throw; }

      if (!t.transfer(_channel.agentB, value)) { throw; }
      else if (!t.transfer(_channel.agentA, _channel.depositA-value)) { throw; }
      // Close this side of the channel
      _channel.openA = false;
      // Update the state
      channels[h[0]] = _channel;
    }

    // If both sides of the channel are closed, delete the channel
    if (_channel.openA == false && _channel.openB == false) {
      // Close the channel
      delete channels[h[0]];
      delete active_ids[_channel.agentA][_channel.agentB];
    }

	}

  //============================================================================
  // CONSTANT FUNCTIONS
  //============================================================================

  /**
   * Verify that a message sent will allow the channel to close.
   * Parameters are the same as for CloseChannel
   */
  function VerifyMsg(bytes32[4] h, uint8 v, uint256 value) public constant returns (bool) {
    // h[0]    Channel id
    // h[1]    Hash of (id, value)
    // h[2]    r of signature
    // h[3]    s of signature

    // Make sure the channel is open
    if (channels[h[0]].token == address(0)) { return false; }
    Channel memory _channel;
    _channel = channels[h[0]];

    if (msg.sender != _channel.agentA && msg.sender != _channel.agentB) { return false; }

    // Get the message signer and construct a proof
    address signer = ecrecover(h[1], v, h[2], h[3]);
    bytes32 proof = sha3(h[0], value);
    // Make sure the hash provided is of the channel id and the amount sent
    // Ensure the proof matches, send the value, send the remainder, and delete the channel
    if (proof != h[1]) { return false; }

    // Pay recipient and refund sender the remainder
    ERC20 t = ERC20(_channel.token);

    if (msg.sender == _channel.agentA && signer == _channel.agentB) {
      if (value > _channel.depositB) { return false; }

      // Close out the B->A side of the channel
      if (!t.transfer(_channel.agentA, value)) { return false; }
      else if (!t.transfer(_channel.agentB, _channel.depositB-value)) { return false; }
      // Close this side of the channel
      _channel.openB = false;
      // Close the other side if no deposit was ever made
      if (_channel.depositA == 0) {
        _channel.openA = false;
      }
    } else if (msg.sender == _channel.agentB && signer == _channel.agentA) {
      if (value > _channel.depositA) { return false; }

      // Close out the A->B side of the channel
      if (!t.transfer(_channel.agentB, value)) { return false; }
      else if (!t.transfer(_channel.agentA, _channel.depositA-value)) { return false; }
    }

    return true;
  }

  // GETTERS

  function GetChannelId(address from, address to) public constant returns (bytes32) {
    return active_ids[from][to];
  }

  function GetDepositA(bytes32 id) public constant returns (uint) {
    return channels[id].depositA;
  }

  function GetDepositB(bytes32 id) public constant returns (uint) {
    return channels[id].depositB;
  }

  function GetAgentA(bytes32 id) public constant returns (address) {
    return channels[id].agentA;
  }

  function GetAgentB(bytes32 id) public constant returns (address) {
    return channels[id].agentB;
  }

  function GetToken(bytes32 id) public constant returns (address) {
    return channels[id].token;
  }


}
