//SPDX-License-Identifier: WTFPL.ETH
pragma solidity >0.8.0 <0.9.0;

import "src/Interface.sol";
import "src/Util.sol";

/**
 * @title : BENSYC CCIP Clone Resolver
 * @author : 
 */

abstract contract Clone {

    iBENSYC public immutable BENSYC; // BENSYC contract
    iENS public immutable ENS; // ENS Contract

    bytes32 public immutable baseHash; // ens namehash of ".eth"
    bytes32 public immutable secondaryDomainHash; // ENS namehash of "bensyc.eth"
    bytes32 public immutable primaryDomainHash; // ENS namehash of "boredensyachtclub.eth"

    /// @dev : CCIP https://eips.ethereum.org/EIPS/eip-3668
    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    error RequestError(bytes32 expected, bytes32 check, bytes data, uint256 blknum, bytes result);
    error StaticCallFailed(address resolver, bytes _call, bytes _error);
    error InvalidResult(bytes expected, bytes actual);
    error ResolverNotSet(bytes32 node, bytes data);
    constructor() {
        BENSYC = iBENSYC(0xd3E58Bf93A1ad3946bfD2D298b964d4eCe1A9E7E);
        ENS = iENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
        baseHash = keccak256(abi.encodePacked(bytes32(0), keccak256("eth")));
        secondaryDomainHash = keccak256(abi.encodePacked(baseHash, keccak256("bensyc")));
        primaryDomainHash = keccak256(abi.encodePacked(baseHash, keccak256("boredensyachtclub")));
    }
    /**
     * @dev : withdraw ether to multisig, anyone can trigger
     */
    function withdrawEther() external payable {
        (bool ok, ) = address(BENSYC.Dev()).call {
            value: address(this).balance
        }("");
        require(ok, "ETH_TRANSFER_FAILED");
    }

    /**
     * @dev : to be used in case some tokens get locked in the contract
     * @param token : address of token
     * @param  bal : balance of token to withdraw
     */
    function withdrawToken(address token, uint bal) external payable {
        iERC20(token).transferFrom(address(this), BENSYC.Dev(), bal);
    }

    /// @dev : revert on fallback
    fallback() external payable {
        revert();
    }

    /// @dev : revert on receive
    receive() external payable {
        revert();
    }

}

contract XCCIP is Clone {
    function supportsInterface(bytes4 sig) external pure returns(bool) {
        return (sig == XCCIP.resolve.selector || sig == XCCIP.supportsInterface.selector);
    }
    /**
     * @dev : dnsDecode()
     * @param name : dns encoded domain name
     * @return _namehash : returns bytes32 namehash of domain name
     */
    function ENSDecode(bytes calldata name) public view returns(bytes32 _namehash) {
        uint i = 0;
        uint _index = 0;
        bytes[] memory labels = new bytes[](10);
        uint len = 0;
        while (name[i] != 0x0) {
            unchecked {
                len = uint8(bytes1(name[i: ++i]));
                labels[_index] = name[i: i += len];
                ++_index;
            }
        }
        if (_index > 2){ // ..*.bensyc.eth
            unchecked{
                _index -= 3; //index of ...<*>.bensyc.eth
                _namehash = keccak256(
                    abi.encodePacked(
                        primaryDomainHash,
                        keccak256(labels[_index])
                    )
                );
                if(ENS.resolver(_namehash) == address(0)){
                    _namehash = keccak256(
                        abi.encodePacked(
                            baseHash,
                            keccak256(labels[_index])
                        )
                    );
                }
                while (_index > 0) {
                    _namehash = keccak256(
                        abi.encodePacked(
                            _namehash,
                            keccak256(labels[--_index])
                        )
                    );
                }
            }
        } else { // bensyc.eth
            _namehash = primaryDomainHash;
        }
    }

    /**
     * @dev : resolve()
     * @param name : name
     * @param data : data
     */
    function resolve(bytes calldata name, bytes calldata data) external view returns(bytes memory) {
        bytes32 _namehash = ENSDecode(name);
        bytes memory _calldata = (data.length > 36) ?
            abi.encodePacked(data[:4], _namehash, data[36:]) :
            abi.encodePacked(data[:4], _namehash);
        bytes memory _result = getResult(_namehash, _calldata);
        string[] memory _urls = new string[](2);
        _urls[0] = 'data:text/plain,{"data":"{data}"}';
        _urls[1] = 'data:application/json,{"data":"{data}"}';
        unchecked {
            revert OffchainLookup(
                address(this), // callback contract
                _urls, // gateway URL array
                abi.encodePacked(
                    _namehash, 
                    _calldata
                ), // {data} field
                XCCIP.resolveOnChain.selector, // callback function
                abi.encodePacked( // extradata
                    keccak256(
                        abi.encodePacked(
                            blockhash(block.number - 1),
                            address(this),
                            msg.sender,
                            _namehash,
                            _calldata,
                            _result
                        )
                    ),
                    block.number
                )
            );
        }
    }

    /**
     * @dev : get result from onchain data
     * @param _namehash : _namehash
     * @param _calldata : _calldata
     */
    function getResult(bytes32 _namehash, bytes memory _calldata) public view returns(bytes memory) {
        address _resolver = ENS.resolver(_namehash);
        if (_resolver == address(0)) revert ResolverNotSet(_namehash, _calldata);
        (bool ok, bytes memory _result) = _resolver.staticcall(_calldata);
        if (!ok) revert StaticCallFailed(_resolver, _calldata, _result);
        return _result;
    }

    /**
     * Callback used by CCIP read compatible clients to verify and parse the response.
     * @param response : 
     * @param extraData : 
     */
    function resolveOnChain(
        bytes calldata response,
        bytes calldata extraData
    ) external view returns(bytes memory _result) {
        bytes32 checkHash = bytes32(extraData[:32]);
        uint256 blknum = uint(bytes32(extraData[32:]));
        bytes32 _namehash = bytes32(response[:32]);
        bytes memory _calldata = response[32:];
        _result = getResult(_namehash, _calldata);
        unchecked{
            bytes32 check = keccak256(
                abi.encodePacked(
                    blockhash(blknum - 1),
                    address(this),
                    msg.sender,
                    _namehash,
                    _calldata,
                    _result
                )
            );
            if (check != checkHash || block.number > blknum + 5)
                revert RequestError(checkHash, check, _calldata, blknum, _result);
        }
    }
}