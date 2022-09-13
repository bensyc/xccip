// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/XCCIP.sol";

contract XCCIPScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new XCCIP();
        vm.stopBroadcast();
    }
}
