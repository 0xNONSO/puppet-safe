// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./interfaces/hyperlane/IMessageRecipient.sol";
import "./interfaces/hyperlane/IMailbox.sol";
import "./interfaces/hyperlane/IInterchainGasPaymaster.sol";
import "./interfaces/hyperlane/ILiquidityLayerRouter.sol";
import "./interfaces/hyperlane/ILiquidityLayerMessageRecipient.sol";

import {Module} from "@gnosis.pm/zodiac/contracts/core/Module.sol";

//https://github.com/dove-protocol/dove-protocol/blob/main/src/hyperlane/HyperlaneClient.sol
abstract contract SafePuppetSettings is Module, IMessageRecipient, ILiquidityLayerMessageRecipient {
    IInterchainGasPaymaster public hyperlaneGasMaster;
    IMailbox public mailbox;
    ILiquidityLayerRouter public liquidityRouter;

    modifier onlyMailbox(){
        require(msg.sender == address(mailbox), "NOT MAILBOX");
        _;
    }

    modifier onlyLiquidityLayer(){
        require(msg.sender == address(liquidityRouter), "NOT LIQ ROUTER");
        _;
    }

    constructor(
        address _hyperlaneGasMaster, 
        address _mailbox, 
        address _liquidityRouter,
        address _owner,
        address _avatar,
        address _target
    ){
        bytes memory initializeParams = abi.encode(_owner, _avatar, _target);
        setUp(initializeParams);
        hyperlaneGasMaster = IInterchainGasPaymaster(_hyperlaneGasMaster);
        mailbox = IMailbox(_mailbox);
        liquidityRouter = ILiquidityLayerRouter(_liquidityRouter);
    }

    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init();
        (
            address _owner,
            address _avatar,
            address _target
        ) = abi.decode(initializeParams, (address, address, address));

        setAvatar(_avatar);
        setTarget(_target);
        transferOwnership(_owner);
        //emit ModuleSetUp(owner(), avatar, target, originSender, origin, connext);
    }

    function setHyperlaneGasMaster(address _hyperlaneGasMaster) external onlyOwner {
        hyperlaneGasMaster = IInterchainGasPaymaster(_hyperlaneGasMaster);
    }

    function setMailbox(address _mailbox) external onlyOwner {
        mailbox = IMailbox(_mailbox);
    }
     function setLiquidityLayer(address _liquidityLayer) external onlyOwner {
        liquidityRouter = ILiquidityLayerRouter(_liquidityLayer);
     }
}
