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

    // Note that ERC20 tokens have metadata including name, symbol, and decimals.
    assert.equal(parseInt(balance), 5000*Math.pow(10, 8))

    done();
  });

  // 5 characters shorter than standard address - 0xe4a6ab4433be5877e5ad8c53abbf0bb4e4bf681b
  var randomAddress = '0xe4a6ab4433be5877e5ad8c53abbf0bb4e4b';

  it('Should send the blockchain a transaction to move tokens to a random address.', function(done) {
    done();
  })

  it('Should get the balance of the random address.', function(done) {
    done();
  });

})
