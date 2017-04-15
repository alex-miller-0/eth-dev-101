var Promise = require('bluebird').Promise;
var jsonfile = Promise.promisifyAll(require('jsonfile'));
var TokenA = artifacts.require("./TokenA.sol");
var web3 = require(`${process.cwd()}/../config.js`).web3;

var keys_loc = `${process.cwd()}/../keys.json`;
var file_loc = `${process.cwd()}/../test.json`;
var keys = require(keys_loc);
var file = require(file_loc);


contract('Token', function(accounts) {
  var tokenA;

  it("Should deploy Token A and get the address", function() {
    return TokenA.deployed()
    .then(function(instance) {
      tokenA = instance;
      assert.notEqual(instance.address, null);
      file.token_a = instance.address;
      return tokenA.name()
    })
    .then(function(name) {
      assert.equal(typeof name, 'string')
      return tokenA.symbol()
    })
    .then(function(symbol) {
      assert.equal(typeof symbol, 'string')
    })
  });

  it('Should send me some ether and tokens.', function() {
    assert.notEqual(keys.me, null, 'You have not created a key for yourself in test/test.keys')
    var eth = 1*Math.pow(10, 18);
    var tokena = 5000*Math.pow(10, 8);
    var sendObj = {
      from: accounts[0],
      value: eth,
      to: keys.me.address
    }
    Promise.resolve(web3.eth.sendTransaction(sendObj))
    .then(function(txHash) {
      assert.notEqual(txHash, null);
      return web3.eth.getBalance(keys.me.address)
    })
    .then(function(balance) {
      assert.notEqual(balance.toNumber(), 0)
      return tokenA.transfer.sendTransaction(keys.me.address, tokena, { from: accounts[0] })
    })
    .then(function(txHash) {
      assert.notEqual(txHash, null);
      return tokenA.balanceOf.call(keys.me.address)
    })
    .then(function(a_bal) {
      assert.equal(a_bal.toNumber(), 5000*Math.pow(10, 8))
    })
  })

  it('Should save the Token A address to a json file', function() {
    jsonfile.writeFileAsync(file_loc, file, {spaces: 2});
  })

})
