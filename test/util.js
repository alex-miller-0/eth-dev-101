var config = require('../config.js');
var Tx = require('ethereumjs-tx');
let gasPrice = 2*Math.pow(10, 9)
var fs = require('fs');
var ethutil = require('ethereumjs-util');
var request = require('request');


exports.formUnsigned = function(from, to, data, _value, _gas) {
  let nonce = config.web3.eth.getTransactionCount(from)
  let value = _value || 0
  let gas = _gas || 100000
  let tx = {
    from: from,
    to: to,
    data: data,
    value: `0x${value.toString(16)}`,
    gas: `0x${gas.toString(16)}`,
    gasPrice: `0x${gasPrice.toString(16)}`
  };
  return tx;
}

exports.sign = function(txn, pkey) {
  var privateKey = new Buffer(pkey, 'hex')
  var tx = new Tx(txn);
  tx.sign(privateKey);
  var serializedTx = tx.serialize();
  return serializedTx.toString('hex');
}

exports.ecsign = function(msg_hash, pkey) {
  var privateKey = new Buffer(pkey, 'hex');
  var signed = ethutil.ecsign(msg_hash, privateKey);
  return signed
}

exports.sendTx = function(txn, pkey, cb) {
  var privateKey = new Buffer(pkey, 'hex')
  var tx = new Tx(txn);
  tx.sign(privateKey);
  var serializedTx = tx.serialize();
  var txHash = config.web3.eth.sendRawTransaction(serializedTx.toString('hex'));
  cb(txHash)
}


exports.zfill = function(num) { if (num.substr(0,2)=='0x') num = num.substr(2, num.length); var s = num+""; while (s.length < 64) s = "0" + s; return s; }
