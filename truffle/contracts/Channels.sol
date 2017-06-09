pragma solidity ^0.4.8;

contract Channels {

  //============================================================================
  // GLOBAL VARIABLES
  //============================================================================

  struct Channel {
    address sender;
    address recipient;
    uint startDate;
    uint timeout;
    mapping (bytes32 => address) signatures;
    uint deposit;
  }

  mapping (bytes32 => Channel) channels;
  mapping (address => mapping(address => bytes32)) active_ids;


  //============================================================================
  // STATE TRANSITION FUNCTIONS
  //============================================================================

	/**
	 * Open a channel with a recipient. A non-zero message value must be included.
	 *
	 * address to       Address of recipient
	 * uint timeout     Number of seconds for which the channel will be open
	 */
	function OpenChannel(address to, uint timeout) payable {
    // Sanity checks
    if (msg.value == 0) { throw; }
    if (to == msg.sender) { throw; }

    // Create a channel
    bytes32 id = sha3(msg.sender, to, now+timeout);

    // Initialize the channel
    Channel memory _channel;
		_channel.startDate = now;
		_channel.timeout = now+timeout;
    _channel.deposit = msg.value;
    _channel.sender = msg.sender;
    _channel.recipient = to;
    channels[id] = _channel;

    // Add it to the lookup table
    active_ids[msg.sender][to] = id;
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

    // Grab the channel in question
    if (channels[h[0]].deposit == 0) { throw; }
    Channel memory _channel;
    _channel = channels[h[0]];

    // https://ethereum.stackexchange.com/a/15911/1391
    // TODO put this logic into JS
    address signer = ecrecover(h[1], v, h[2], h[3]);
    if (signer != _channel.sender) { throw; }

    // Make sure the hash provided is of the channel id and the amount sent
    bytes32 proof = sha3(h[0], value);
    // Ensure the proof matches, send the value, send the remainder, and delete the channel
    if (proof != h[1]) { throw; }
    else if (value > _channel.deposit) { throw; }

    // Close the channel
    delete channels[h[0]];

	}

	/**
	 * Delete an expired channel and refund the deposit to the sender.
   * May be called by anyone.
	 *
	 * bytes32 id    Identitifier in "channels" mapping
	 */
	function ChannelTimeout(bytes32 id){
    Channel memory _channel;
    _channel = channels[id];

    // Make sure it's not already closed and is actually expired
    if (_channel.deposit == 0) { throw; }
    else if (_channel.timeout > now) { throw; }
    else if (!_channel.sender.send(_channel.deposit)) { throw; }

    // Close the channel
    delete channels[id];
	}


  //============================================================================
  // CONSTANT FUNCTIONS
  //============================================================================

  /**
   * Get a channel id given a sender and recipient
   *
   * address from    sender
   * address to      recipient
   *
   */
  function GetChannelId(address from, address to) public constant returns (bytes32) {
    return active_ids[from][to];
  }

  /**
   * Verify that a message sent will allow the channel to close.
   * Parameters are the same as for CloseChannel
   */
  function VerifyMsg(bytes32[4] h, uint8 v, uint256 value) public constant returns (bool) {
    // h[0]    Channel id
    // h[1]    Hash of (id, value)
    // h[2]    r of signature
    // h[3]    s of signature

    // Grab the channel in question
    if (channels[h[0]].deposit == 0) { return false; }
    Channel memory _channel;
    _channel = channels[h[0]];

    // https://ethereum.stackexchange.com/a/15911/1391
    // TODO put this logic into JS
    address signer = ecrecover(h[1], v, h[2], h[3]);
    if (signer != _channel.sender) { return false; }

    // Make sure the hash provided is of the channel id and the amount sent
    bytes32 proof = sha3(h[0], value);
    // Ensure the proof matches, send the value, send the remainder, and delete the channel
    if (proof != h[1]) { return false; }
    else if (value > _channel.deposit) { return false; }

    return true;
  }


}
