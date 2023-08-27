// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SafePuppetModule.sol";

contract SafePuppetTest is Test {
    SafePuppetModule private safePuppetModule;

    function setUp() public {
        uint32 domainIdentifier;
        address _hyperlaneGasMaster;
        address _mailbox;
        address _liquidityRouter;
        address _owner = address(this);
        address _avatar;
        address _target;

        safePuppetModule = new SafePuppetModule(
            domainIdentifier,
            _hyperlaneGasMaster,
            _mailbox,
            _liquidityRouter,
            _owner,
            _avatar,
            _target
        );
    }

    function createSafe() internal {}
}
