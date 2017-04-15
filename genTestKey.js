/**
 * Generate a test keypair
 */

var keystore = require('eth-lightwallet').keystore;
var Promise = require('bluebird').Promise;
var crypto = require('crypto');
var fs = Promise.promisifyAll(require('fs'));
var jsonfile = Promise.promisifyAll(require('jsonfile'));

var KEYSTORE_DIRECTORY = `.`;
var name = process.argv[2];
var password = "test";

 /**
  * Run the generator
  */
createKeystore(password)
.then(function(ks) {
  return saveProfile(name, ks.keystore, ks.privateKey, ks.address); })
.then(function(saved) { console.log('saved', saved); })
.catch(function(error) { console.log(error); });


 /**
  * Utility Functions
  */
function createKeystore(_password) {
  return new Promise(function(resolve, reject) {
    var password = Buffer(_password).toString('hex');
    keystore.createVault({ password: password }, function(error, ks) {
      if (error) { reject(error); }
      ks.keyFromPassword(password, function(error, dKey) {
        if (error) { reject(error); }
        ks.generateNewAddress(dKey, 1);
        var address = `0x${ks.getAddresses()[0]}`;
        var privateKey = ks.exportPrivateKey(address, dKey);
        var keystore = JSON.parse(ks.serialize());
        resolve({ address, privateKey, keystore });
      });
    });
  });
}

function saveProfile(name, keystore, privateKey, address) {
  return new Promise((resolve, reject) => {
    jsonfile.readFileAsync(`${KEYSTORE_DIRECTORY}/keys.json`, {throws: false})
    .then(function(PROFILES) {
      var profiles = PROFILES || {};
      profiles[`${name}`] = {
        keystore,
        privateKey,
        address
      };
      console.log('profiles', profiles)
      return profiles;
    })
    .then(function(_profiles) {
      return jsonfile.writeFileAsync(`${KEYSTORE_DIRECTORY}/keys.json`, _profiles, {spaces: 2});
    })
    .then(function() { resolve(true); })
    .catch(function(error) { reject(error); });
  })
}
