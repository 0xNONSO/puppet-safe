// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {SafePuppetSettings} from "./SafePuppetSettings.sol";
import {Message, TypeCasts} from "./lib/Message.sol";
import {Enum} from "@gnosis.pm/zodiac/contracts/core/Module.sol";
import "./interfaces/hyperlane/ILiquidityLayerRouter.sol";
import "./interfaces/hyperlane/IMailbox.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SafePuppetModule is SafePuppetSettings {
    using Message for bytes;
    using SafeERC20 for IERC20;

    // =================================================== STATE ==================================================
    // ================================================= VARIABLES ================================================

    uint32 immutable public domain;
    mapping(bytes32 => bool) public isPuppetMaster;

    // =================================================== EVENTS ==================================================
    // =============================================================================================================

    event Dispatch(uint32 domain, address reciever);
    event DispatchWithToken(uint32 domain, address reciever, address token, uint256 amount);
    event Handle(uint32 domain, address sender);
    event HandleWithToken(uint32  domain, address sender, address token, uint256 amount);

    // =================================================== CUSTOM ==================================================
    // =================================================== ERRORS ==================================================
    
    error ZeroAmount();
    error FalsePuppeteer();
    error SenderNotMailbox();
    error InvalidTokenAddress();
    error ModuleTransactionFailed();

    // ================================================== CONSTRUCTOR ===============================================
    // ==============================================================================================================

    constructor(
        uint32 domainIdentifier,
        address _hyperlaneGasMaster, 
        address _mailbox, 
        address _liquidityRouter,
        address _owner,
        address _avatar,
        address _target
    ) SafePuppetSettings( _hyperlaneGasMaster, _mailbox, _liquidityRouter, _owner, _avatar, _target){
        domain = domainIdentifier;
    }

    // ================================================== EXTERNAL =================================================
    // ================================================= FUNCTIONS =================================================
    function togglePuppeteer(bytes32 puppeteerId) external onlyOwner {
        bool status = isPuppetMaster[puppeteerId];
        isPuppetMaster[puppeteerId] = !status;
    }

    function dispatchMsg(
        uint32 _destDomain,
        uint256 _hyperlaneFee,
        address _puppet,
        address _to,
        uint256 _value,
        bytes memory _data
    ) external onlyOwner {
        bytes memory currentPayload = abi.encodeWithSelector(
            IMailbox.dispatch.selector, 
            _destDomain, 
            TypeCasts.addressToBytes32(_puppet), 
            destPayload(_to, _value, _data, Enum.Operation.Call)
        );
        (bool success, bytes memory returnData) = execAndReturnData(address(mailbox), 0, currentPayload, Enum.Operation.Call);
        if(!success) revert ModuleTransactionFailed();

        bytes32 id = abi.decode(returnData, (bytes32));
        // Call the IGP even if the gas payment is zero. This is to support on-chain
        // fee quoting in IGPs, which should always revert if gas payment is insufficient.
        payForGas(_hyperlaneFee, id, _destDomain);
        emit Dispatch(_destDomain, _to);
    }

    function dispatchMsgWithToken(
        uint32 _destDomain,
        uint256 _hyperlaneFee,
        address _puppet,
        address _token,
        uint256 _amount,
        string calldata _bridge,
        address _to,
        uint256 _value,
        bytes memory _data
    ) external onlyOwner {
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_amount == 0) revert ZeroAmount();

        bytes memory currentPayload = abi.encodeWithSelector(
            ILiquidityLayerRouter.dispatchWithTokens.selector, 
            _destDomain,
            TypeCasts.addressToBytes32(_puppet),
            _token,
            _amount,
            _bridge,
            destPayload(_to, _value, _data, Enum.Operation.Call)
        );
        (bool success, bytes memory returnData) = execAndReturnData(address(liquidityRouter), 0, currentPayload, Enum.Operation.Call);
        if(!success) revert ModuleTransactionFailed();

       payForGas(_hyperlaneFee, abi.decode(returnData, (bytes32)), _destDomain);
       emit DispatchWithToken(_destDomain, _to, _token, _amount);
    }

    function handle(
        uint32,
        bytes32,
        bytes calldata _message
    ) external override onlyMailbox(){
        _exec(_message);
        emit Handle(_message.origin(), _message.senderAddress());
    }

    function handleWithTokens(
        uint32,
        bytes32,
        bytes calldata _message,
        address _token,
        uint256 _amount
    ) external override onlyMailbox(){
        // Approve token transfer if tokens were passed in
        IERC20 token = IERC20(_token);
        if(_amount > 0) { 
            token.safeTransfer(avatar, _amount); 
        }
        if(_message.length == 0) _exec(_message);
        emit HandleWithToken(_message.origin(), _message.senderAddress(), _token, _amount);
    }
    
    // ================================================== INTERNAL =================================================
    // ================================================= FUNCTIONS =================================================

    function payForGas(uint256 _hyperlaneFee, bytes32 id, uint32 _destDomain) internal {
         hyperlaneGasMaster.payForGas{value: _hyperlaneFee}(
            id, 
            _destDomain, 
            500000, 
            address(msg.sender)
        );
    }
    
    function _exec(bytes calldata _message) internal {
        // get message sender and domain
        bytes32 pid = getPuppeteerId(_message.senderAddress(), _message.origin());
        if(!isPuppetMaster[pid]){
            revert FalsePuppeteer();
        }
        (address _to, uint256 _value, bytes memory _data, Enum.Operation _operation) = abi.decode(
            _message.body(),
            (address, uint256, bytes, Enum.Operation)
        );
        // Execute transaction against target
        (bool success, bytes memory returnData) = execAndReturnData(_to, _value, _data, _operation);
        if(!success) revert ModuleTransactionFailed();
        _handleReturnData(returnData);
    }

    function _handleReturnData(bytes memory data) internal {}

    // ==================================================== PURE ===================================================
    // ================================================= FUNCTIONS =================================================

    function getPuppeteerId(address puppeteer, uint32 domainIdentifier) public pure returns(bytes32){
        return keccak256(abi.encode(puppeteer, domainIdentifier));
    }

    function destPayload(
        address _to,
        uint256 _value,
        bytes memory _data,
        Enum.Operation _operation
    ) pure internal returns(bytes memory) {
        return abi.encode(
            _to,
            _value,
            _data,
            _operation
        );
    }

}