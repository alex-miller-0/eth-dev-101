/**
* Claim the agent with an owned keypair.
*/
var assert = require('chai').assert;
var Promise = require('bluebird').Promise;
var config = require('../config.js');
var keys = require(`${process.cwd()}/keys.json`);
var test = require(`${process.cwd()}/test.json`);
var request = require('request');
var ethutil = require('ethereumjs-util')
var util = require('./util.js');
var sha3 = require('solidity-sha3').default;
let channel_id;
let latest_sig;
let latest_msg_hash;
let latest_value;

describe('Channels', function(done) {

  it('Should make sure test account has ether', function(done) {
    Promise.resolve(config.web3.eth.getBalance(keys.test.address))
    .then((balance) => {
      console.log('balance', balance)
      assert.notEqual(parseInt(balance), 0, 'Test account has a zero balance')
      done();
    })
  })

  it('Should create a new channel', function(done) {
    var data = `0x3bb02d29${zfill(keys.test2.address)}${zfill((10000).toString(16))}`
    const deposit = 0.05*Math.pow(10, 18);
    const gas = 150000;
    let unsigned = util.formUnsigned(keys.test.address, test.channels_addr, data, deposit, gas)
    util.sendTx(unsigned, keys.test.privateKey, (txhash) => {
      if (!txhash) { assert.equal(1, 0, "Did not get a tx hash back")}
      else { done(); }
    })
  })

  it('Should get the id of the new channel', function(done) {
    var data = `0x2460ee73${zfill(keys.test.address)}${zfill(keys.test2.address)}`
    Promise.resolve(config.web3.eth.call({ to: test.channels_addr, data: data }))
    .then((_id) => {
      assert.notEqual(_id, '0x0000000000000000000000000000000000000000000000000000000000000000', 'No channel created')
      channel_id = _id.substr(2, _id.length);
      console.log('id', channel_id)
      done();
    })
    .catch((err) => { assert.equal(err, null, err); })
  })

  it('Should sign a message for 0.1ETH', function(done) {
    var _value = 0.1*Math.pow(10, 18)
    var value = _value.toString(16)
    // let msg_hash = ethutil.sha3(channel_id+zfill(_value.toString(16)))

    let _msg_hash = sha3(`0x${channel_id}`, _value);
    let msg_hash = Buffer.from(_msg_hash.substr(2, 64), 'hex')

    let sig = util.ecsign(msg_hash, keys.test.privateKey)
    let parsed_sig = {
      v: sig.v.toString(16),
      r: sig.r.toString('hex'),
      s: sig.s.toString('hex')
    };
    latest_value = value;
    latest_sig = parsed_sig;
    // latest_msg_hash = msg_hash
    latest_msg_hash = msg_hash.toString('hex')
    done();
  })


  it('Should check to see if this message will pass', function(done) {
    // VerifyMsg(bytes32 id, bytes32 h, uint8 v, bytes32 r, bytes32 s, uint value)
    let data = `0xb475be60${channel_id}${latest_msg_hash}${latest_sig.r}${latest_sig.s}${zfill(latest_sig.v)}${zfill(latest_value)}`
    console.log('data', data)
    Promise.resolve(config.web3.eth.call({ to: test.channels_addr, data: data }))
    .then((success) => {
      assert.equal(1, parseInt(success), 'Message did not pass')
      done();
    })
  })


  it('Should run ecrecover in js', function(done) {
    const pubKey  = ethutil.ecrecover(Buffer.from(latest_msg_hash, 'hex'), parseInt('0x'+latest_sig.v), Buffer.from(latest_sig.r,'hex'), Buffer.from(latest_sig.s,'hex'));
    const addrBuf = ethutil.pubToAddress(pubKey);
    const addr    = ethutil.bufferToHex(addrBuf);
    assert.equal(addr, keys.test.address, 'Recovered address is incorrect')
    done();
  })


  it('Should sign a message for 5.1ETH and submit it. This should fail.', function(done) {
    var _value = 5.1*Math.pow(10, 18)
    var value = _value.toString(16)

    let _msg_hash = sha3(`0x${channel_id}`, _value);
    let msg_hash = Buffer.from(_msg_hash.substr(2, 64), 'hex')

    let sig = util.ecsign(msg_hash, keys.test.privateKey)
    let parsed_sig = {
      v: sig.v.toString(16),
      r: sig.r.toString('hex'),
      s: sig.s.toString('hex')
    };

    let data = `0xb475be60${channel_id}${msg_hash.toString('hex')}${parsed_sig.r}${parsed_sig.s}${zfill(parsed_sig.v)}${zfill(value)}`
    Promise.resolve(config.web3.eth.call({ to: test.channels_addr, data: data }))
    .then((success) => {
      assert.equal(0, parseInt(success), 'Message passed but should not have')
      done();
    })
  })

  it('Should close the channel', function(done) {
    const gas = 120000;
    let data = `0x4ac1ec32${channel_id}${latest_msg_hash}${latest_sig.r}${latest_sig.s}${zfill(latest_sig.v)}${zfill(latest_value)}`;

    let unsigned = util.formUnsigned(keys.test.address, test.channels_addr, data, 0, gas)
    util.sendTx(unsigned, keys.test.privateKey, (txhash) => {
      if (!txhash) { assert.equal(1, 0, "Did not get a tx hash back")}
      else { done(); }
    })

  })


})

function zfill(num) { if (num.substr(0,2)=='0x') num = num.substr(2, num.length); var s = num+""; while (s.length < 64) s = "0" + s; return s; }
