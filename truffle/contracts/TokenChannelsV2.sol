/**
 * Version two of the TokenChannels contract
 * Adds nonces to the messages as well as the notion of a challenge period.
 * Either party may challenge the closing channel if they have a message with
 * a higher nonce than the one currently recorded in the channel.
 */
pragma solidity ^0.4.8;
import "./ERC20.sol";

contract TokenChannels {

  //============================================================================
  // GLOBAL VARIABLES
  //============================================================================

  struct Channel {
    address sender;
    address recipient;
    address token;
    uint deposit;
    uint challenge;
    uint nonce;
    uint closeTime;
    uint value;
  }
  mapping (address => uint) balances;

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
	function OpenChannel(address token, address to, uint amount, uint challenge) {
    // Sanity checks
    if (amount == 0) { throw; }
    if (to == msg.sender) { throw; }
    if (active_ids[msg.sender][to] != bytes32(0)) { throw; }

    // Create a channel
    bytes32 id = sha3(msg.sender, to, now);

    // Initialize the channel
    Channel memory _channel;
    _channel.deposit = amount;
    _channel.sender = msg.sender;
    _channel.recipient = to;
    _channel.token = token;
    _channel.challenge = challenge;

    // Make the deposit
    ERC20 t = ERC20(token);
    if (!t.transferFrom(msg.sender, address(this), amount)) { throw; }

    channels[id] = _channel;

    // Add it to the lookup table
    active_ids[msg.sender][to] = id;
	}


	/**
	 * Close a channel at any time. May only be called by recipient.
   * The "value" is sent to the recipient and the remainder is refunded to the sender.
	 *
   * bytes32  h         [ id, msg_hash, r, s ]
	 * uint8    v         Component of signature of "h" coming from sender
	 * uint     value     Amount of wei sent
   * uint     nonce     Number to be hashed with the value to form the message
	 */
	function CloseChannel(bytes32[4] h, uint8 v, uint256 value, uint256 nonce) {
    // h[0]    Channel id
    // h[1]    Hash of (id, value)
    // h[2]    r of signature
    // h[3]    s of signature

    // Grab the channel in question
    if (channels[h[0]].deposit == 0) { throw; }
    Channel memory _channel;
    _channel = channels[h[0]];

    // Only the recipient can close a channel
    if (msg.sender != _channel.recipient) { throw; }

    address signer = ecrecover(h[1], v, h[2], h[3]);
    if (signer != _channel.sender) { throw; }

    // Make sure the hash provided is of the channel id and the amount sent
    bytes32 proof = sha3(h[0], value, nonce);

    // Ensure the proof matches, send the value, send the remainder, and delete the channel
    if (proof != h[1]) { throw; }
    else if (value > _channel.deposit) { throw; }

    if (_channel.challenge == 0) {
      // If there's no challenge period, close out the channel immediately.

      // Pay recipient and refund sender the remainder
      ERC20 t = ERC20(channels[h[0]].token);
      if (!t.transfer(channels[h[0]].recipient, channels[h[0]].value)) { throw; }
      else if (!t.transfer(channels[h[0]].sender, channels[h[0]].deposit-channels[h[0]].value)) { throw; }

      // Delete the channel
      delete active_ids[channels[h[0]].sender][channels[h[0]].recipient];
      delete channels[h[0]];
    } else {
      // Copy the data to the state and allow challenges

      _channel.nonce = nonce;
      _channel.value = value;
      _channel.closeTime = now;
      channels[h[0]] = _channel;
    }
	}


  /**
   * During the challenge period, either party may submit a proof that contains
   * a higher nonce.
   *
   * bytes32  h         [ id, msg_hash, r, s ]
	 * uint8    v         Component of signature of "h" coming from sender
	 * uint     value     Amount of wei sent
   * uint     nonce     Number to be hashed with the value to form the message
   */
  function Challenge(bytes32[4] h, uint8 v, uint256 value, uint256 nonce) {
    // Grab the channel in question
    if (channels[h[0]].deposit == 0) { throw; }
    Channel memory _channel;
    _channel = channels[h[0]];

    // Make sure we're still in the challenge period
    if (_channel.closeTime + _channel.challenge <= now) { throw; }

    // Make sure the nonce is higher
    if (_channel.nonce >= nonce) { throw; }

    if (msg.sender != _channel.sender && msg.sender != _channel.recipient) { throw; }

    address signer = ecrecover(h[1], v, h[2], h[3]);
    if (signer != _channel.sender) { throw; }

    // Make sure the hash provided is of the channel id and the amount sent
    bytes32 proof = sha3(h[0], value, nonce);

    // Ensure the proof matches, send the value, send the remainder, and delete the channel
    if (proof != h[1]) { throw; }
    else if (value > _channel.deposit) { throw; }

    // Pay recipient and refund sender the remainder
    ERC20 t = ERC20(_channel.token);
    if (!t.transfer(_channel.recipient, value)) { throw; }
    else if (!t.transfer(_channel.sender, _channel.deposit-value)) { throw; }

    // Copy data to the state
    _channel.value = value;
    _channel.nonce = nonce;
    channels[h[0]] = _channel;
  }


  /**
   * Once past its challenge period, close a channel and disperse the funds.
   * Anyone can do this.
   *
   * bytes32  id    Channel id
   */
  function Finalize(bytes32 id) {
    // Grab the channel in question
    if (channels[id].deposit == 0) { throw; }

    // Make sure we're past the challenge period
    if (channels[id].closeTime + channels[id].challenge > now) { throw; }

    // Pay recipient and refund sender the remainder
    ERC20 t = ERC20(channels[id].token);
    if (!t.transfer(channels[id].recipient, channels[id].value)) { throw; }
    else if (!t.transfer(channels[id].sender, channels[id].deposit-channels[id].value)) { throw; }

    // Delete the channel
    delete active_ids[channels[id].sender][channels[id].recipient];
    delete channels[id];
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

  // GETTERS

  function GetChannelId(address from, address to) public constant returns (bytes32) {
    return active_ids[from][to];
  }

  function GetDeposit(bytes32 id) public constant returns (uint) {
    return channels[id].deposit;
  }

  function GetSender(bytes32 id) public constant returns (address) {
    return channels[id].sender;
  }

  function GetRecipient(bytes32 id) public constant returns (address) {
    return channels[id].recipient;
  }

  function GetToken(bytes32 id) public constant returns (address) {
    return channels[id].token;
  }

  // Returns true if this is an active channel
  function DoesChannelExist(bytes32 id) public constant returns (bool) {
    return channels[id].token != address(0);
  }
  // Returns true if the channel is closed (or if the channel doesn't exist)
  function IsChannelClosed(bytes32 id) public constant returns (bool) {
    return channels[id].closeTime != 0;
  }

  // This will return 0 unless the channel is currently in the challenge period
  function ChallengeRemaining(bytes32 id) public constant returns (uint) {
    if (channels[id].closeTime == 0) { return 0; }
    else if (channels[id].closeTime + channels[id].challenge < now) { return 0; }
    else { return (channels[id].closeTime + channels[id].challenge) - now; }
  }

}
