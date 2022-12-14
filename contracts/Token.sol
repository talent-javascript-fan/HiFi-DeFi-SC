// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HiFiToken is ERC20 {
    constructor() ERC20("HIFI Token", "HIFI") {
        _mint(msg.sender, 100000000000000000000000000);
    }
}
