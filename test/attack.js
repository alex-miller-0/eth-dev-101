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

  it('Should find my token balance.', function(done) {

    // Make sure none of your arguments are 0x-prefixed! This is a common mistake.
    var my_address = keys.me.address.substr(2, keys.me.address.length);

    // 70a08231 = first 4 bytes of keccak_256 hash of "balanceOf(address)"
    // This is the method we are calling, see TokenA.sol
    var data = `0x70a08231${zfill(my_address)}`;
    var balance = config.web3.eth.call({ to: testfile.token_a, data: data});


    done();
  });

  // 4 characters shorter than standard address -
  //                    e4a6ab4433be5877e5ad8c53abbf0bb4e4bf681b
  // NOTE: This must be shortened by an integer number of bytes (a.k.a. multiple of 2 characters)
  var random_address = 'e4a6ab4433be5877e5ad8c53abbf0bb4e4bf';
  var my_address = keys.me.address.substr(2, keys.me.address.length);
  var gas = 100000;
  var gasPrice = 10*Math.pow(10, 9);
  var nonce = config.web3.eth.getTransactionCount(`0x${my_address}`);
  var toSend = 1000;
  //       0000000000000000000000000000e4a6ab4433be5877e5ad8c53abbf0bb4e4bf
  var to = zfill(random_address);
  //           000000000000000000000000e4a6ab4433be5877e5ad8c53abbf0bb4e4bf
  var modded = to.substr(4, to.length);
  // 0xa9059cbb000000000000000000000000e4a6ab4433be5877e5ad8c53abbf0bb4e4bf00000000000000000000000000000000000000000000000000000000000003e8
  // converted by EVM to
  // 0xa9059cbb000000000000000000000000e4a6ab4433be5877e5ad8c53abbf0bb4e4bf00000000000000000000000000000000000000000000000000000000000003e80000
  var data = `0xa9059cbb${modded}${zfill(toSend.toString(16))}`;
  var privateKey = new Buffer(keys.me.privateKey, 'hex')

  it('Should send the blockchain a transaction to move tokens to a random address.', function(done) {
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

  it('Should get the balance of the random address.', function(done) {
    var data = `0x70a08231${zfill(`e4a6ab4433be5877e5ad8c53abbf0bb4e4bf0000`)}`;
    var balance = config.web3.eth.call({ to: testfile.token_a, data: data});
    console.log('balance', parseInt(balance));
    done();
  });

})
