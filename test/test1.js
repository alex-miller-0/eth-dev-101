var assert = require('chai').assert;
var Promise = require('bluebird').Promise;
var request = require('request');
var config = require('../config.js');
var jsonfile = Promise.promisifyAll(require('jsonfile'));
var ethUtil = require('ethereumjs-util');
var Tx = require('ethereumjs-tx');

var testfile = require('../test.json');
var keys = require ('../keys.json');

// Pad string or number with zeros up to 64 bytes
function zfill(num) { var s = num+""; while (s.length < 64) s = "0" + s; return s; }

describe('Sending my tokens', function(done) {

  it('Should call the blockchain to find my token balance', function(done) {

    // Make sure none of your arguments are 0x-prefixed! This is a common mistake.
    var my_address = keys.me.address.substr(2, keys.me.address.length);

    // 70a08231 = first 4 bytes of keccak_256 hash of "balanceOf(address)"
    // This is the method we are calling, see TokenA.sol
    var data = `0x70a08231${zfill(my_address)}`;
    var balance = config.web3.eth.call({ to: testfile.token_a, data: data});

    // Note that ERC20 tokens have metadata including name, symbol, and decimals.
    assert.equal(parseInt(balance), 5000*Math.pow(10, 8))

    done();
  });

  it('Should send the blockchain a transaction to move tokens to a random address', function(done) {

    // Again, NOT 0x prefixed when calling a function
    var random_address = "EA674fdDe714fd979de3EdF0F56AA9716B898ec8";
    var my_address = keys.me.address.substr(2, keys.me.address.length);

    // Recover your private key and make it a buffer
    var privateKey = new Buffer(keys.me.privateKey, 'hex')

    var toSend = 1000;
    var data = `0xa9059cbb${zfill(random_address)}${zfill(toSend.toString(16))}`;
    // gas*gasPrice = maximum amount of wei the miner can use to call the function
    // on your behalf
    var gas = 100000;
    var gasPrice = 10*Math.pow(10, 9);

    // A nonce is a number that is used once to prevent your transaction from
    // getting replayed. It is the number of transactions that have ever originated
    // from your address.
    var nonce = config.web3.eth.getTransactionCount(`0x${my_address}`);

    // Configure the unsigned transaction
    var txn = {
      from: `0x${my_address}`,
      to: testfile.token_a,
      gas: `0x${gas.toString(16)}`,
      gasPrice: `0x${gasPrice.toString(16)}`,
      data: data,
      nonce: `0x${nonce.toString(16)}`
    };
    var tx = new Tx(txn);
    tx.sign(privateKey);
    var serializedTx = tx.serialize();

    var txHash = config.web3.eth.sendRawTransaction(serializedTx);
    assert.notEqual(null, txHash);
    console.log('txHash', txHash)
    done();
  })

  it('Should call the blockchain to find my updated token balance', function(done) {
    var my_address = keys.me.address.substr(2, keys.me.address.length);
    var data = `0x70a08231${zfill(my_address)}`;
    var balance = config.web3.eth.call({ to: testfile.token_a, data: data});

    assert.equal(parseInt(balance), 5000*Math.pow(10, 8)-1000)
    done();
  });

})
