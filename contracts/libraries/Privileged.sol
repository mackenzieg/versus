// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./Context.sol";

abstract contract Privileged is Context {
    address private _owner;
    address private _mm;
    address private _other;

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function updatePriviledged(address mm, address other) public virtual onlyPriviledged {
        _mm = mm;
        _other = other;
    }

    modifier onlyPriviledged() {
        bool priviledged = _owner == _msgSender() || _mm == _msgSender() || _other == _msgSender();
        require(priviledged, "Privileged: caller is not privileged");
        _;
    }
}
