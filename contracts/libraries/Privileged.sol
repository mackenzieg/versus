// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./Context.sol";

abstract contract Ownable is Context {
    address private _owner;
    address private _mm;
    address private _contender;
    address private _dividend;

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
    }

    function updatePriviledged(address mm, address contender, address dividend) public virtual onlyPriviledged {
        _mm = mm;
        _contender = contender;
        _dividend = dividend;
    }

    modifier onlyPriviledged() {
        bool priviledged = _owner == _msgSender() || _mm == _msgSender() || _contender == _msgSender() || _dividend == _msgSender();
        require(priviledged, "Privileged: caller is not privileged");
        _;
    }
}
