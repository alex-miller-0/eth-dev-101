var web3 = require('web3');
var web3_provider = 'http://localhost';
var web3_port = '8545';
var _web3 = new web3();
_web3.setProvider(new web3.providers.HttpProvider(`${web3_provider}:${web3_port}`));
exports.web3 = _web3;

exports.secrets = {
  enc_password: 'dslkgasjklh',
  host: 'http://localhost',
  port: 3000,
}
