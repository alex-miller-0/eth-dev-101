pragma solidity ^0.4.8;

import "./ERC20.sol";

contract TokenA is ERC20 {

    mapping( address => uint ) balances;
    mapping( address => mapping( address => uint ) ) approvals;
    uint public supply;
    string public name;
    uint8 public decimals;
    string public symbol;
    string public version;

    function TokenA( uint _supply, string _name, uint8 _decimals, string _symbol, string _version ) {
        balances[msg.sender] = _supply;
        supply = _supply;
        name = _name;
        decimals = _decimals;
        symbol = _symbol;
        version = _version;
    }
    function totalSupply() constant returns (uint) {
        return supply;
    }
    function balanceOf( address who ) constant returns (uint) {
        return balances[who];
    }

    function transfer( address to, uint value) returns (bool) {
        balances[msg.sender] = safeSub(balances[msg.sender], value);
        balances[to] = safeAdd(balances[to], value);
        Transfer( msg.sender, to, value );
        return true;
    }
    function transferFrom( address from, address to, uint value) returns (bool) {
        approvals[from][msg.sender] = safeSub(approvals[from][msg.sender], value);
        balances[from] = safeSub(balances[from], value);
        balances[to] = safeAdd(balances[to], value);
        Transfer( from, to, value );
        return true;
    }
    function approve(address spender, uint value) returns (bool) {
        approvals[msg.sender][spender] = value;
        Approval( msg.sender, spender, value );
        return true;
    }
    function allowance(address owner, address spender) constant returns (uint) {
        return approvals[owner][spender];
    }



    // Overflow safety;

    /**
     * Check if two unsigned integer values can be safely added together
     * or if they will overflow. If values, overflow return false;
     * param  uint         - Unsigned integer to add
     * param  uint         - Unsigned integer to add
     * return bool         - orderId of the finished order (or 0 for unfinished)
     */
    function safeToAdd(uint a, uint b) internal returns (bool) {
        return (a + b >= a);
    }

    /**
     * Return the sum of the two integers if they can be safely added together;
     * param  uint         - Unsigned integer to add
     * param  uint         - Unsigned integer to add
     * return uint         - Product of the two integers is successfully added.
     */
    function safeAdd(uint a, uint b) internal returns (uint) {
        if (!safeToAdd(a, b)) throw;
        return a + b;
    }

    /**
     * Check if two unsigned integer values can be safely subtracted from each other,
     * or if they will overflow. If values, overflow return false;
     * param  uint         - Unsigned integer to add
     * param  uint         - Unsigned integer to add
     * return bool         - orderId of the finished order (or 0 for unfinished)
     */
    function safeToSubtract(uint a, uint b) internal returns (bool) {
        return (b <= a);
    }

    /**
     * Return the sum of the two integers if they can be safely subtracted from each other;
     * param  uint         - Unsigned integer to add
     * param  uint         - Unsigned integer to add
     * return uint         - Product of the two integers is successfully added.
     */
    function safeSub(uint a, uint b) internal returns (uint) {
        if (!safeToSubtract(a, b)) throw;
        return a - b;
    }

    function() { throw; }
}
