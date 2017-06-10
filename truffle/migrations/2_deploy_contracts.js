var TokenA = artifacts.require('./TokenA.sol');
var Channels = artifacts.require('./Channels.sol');
var TokenChannels = artifacts.require('./TokenChannels.sol');


// uint _supply, string _name, uint8 _decimals, string _symbol, string _version
var supply = 1 * Math.pow(10, 18)
module.exports = function(deployer) {
  deployer.deploy(TokenA, supply, "TokenA", 8, "TKA", "1");
  deployer.deploy(Channels);
  deployer.deploy(TokenChannels);

};
