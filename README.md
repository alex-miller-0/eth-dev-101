# eth-dev-101
Examples for getting started as an Ethereum web developer

### Setup
To get this set up, clone the repo, run `npm install`, and then run `npm run keygen test && npm run keygen test2` to generate
some test keypairs .You will need truffle and mocha installed globally.

**Typical Ethereum workflow**
This is a basic test just showing you how contracts are deployed and how you can interact with them using an Ethereum ABI
definition and a private key:

`npm run test`

**ERC20 Short AddressAttack**
To simulate [this](http://vessenes.com/the-erc20-short-address-attack-explained/) attack on an ERC20 token:

`npm run attack`

**Payment channels**
To initialize and run a few tests against a basic payment channel:

`npm run channels`


### Troubleshooting

Here are a few FAQs:

*When deploying contracts, I get: Error: sender doesn't have enough funds to send tx*
You have probably run out of funds on `accounts[0]`. The easiest way to get rid of this error is to reboot testrpc.
