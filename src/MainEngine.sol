// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ArtBlockToken} from "./ArtBlockToken.sol";

contract MainEngine {
    ArtBlockToken private immutable artBlockToken;

    constructor() {
        artBlockToken = new ArtBlockToken();
        artBlockToken.mint(msg.sender, 1000);
    }
}
