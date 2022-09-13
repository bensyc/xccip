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
    bytes32 public immutable secondaryLabelHash; // keccak256 hash of "bensyc"
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
        secondaryLabelHash = keccak256("bensyc");
        secondaryDomainHash = keccak256(abi.encodePacked(baseHash, secondaryLabelHash));
        primaryDomainHash = keccak256(abi.encodePacked(baseHash, keccak256("boredensyachtclub")));
        URLS.push(string("https://ipfs.io/ipfs/<ipfs_hash>/ccip.json?{data}"));
        URLS.push(string("https://dweb.link/ipfs/<ipfs_hash>/ccip.json?{data}"));
    }
    string[] public URLS;

    /// @dev : Modifier to allow only BENSYC dev to execute function
    modifier onlyDev() {
        require(msg.sender == BENSYC.Dev(), "Only Dev");
        _;
    }

    /// @dev : Add gateway in URLS array
    /// @param _gateway : gateway url string to add
    function addGateway(string calldata _gateway) external onlyDev {
        URLS.push(_gateway);
    }

    /// @dev : function to remove gateway 
    /// @param _index : index in URLS array to remove
    function removeGateway(uint _index) external onlyDev {
        unchecked {
            uint last = URLS.length - 1;
            require(last > 0, "BLANK_GATEWAY");
            if (_index != last) {
                URLS[_index] = URLS[last];
            }
            URLS.pop();
        }
    }
    /// @dev : function to replace gateway 
    /// @param _index : index in URLS array to
    function replaceGateway(uint _index, string calldata _gateway) external onlyDev {
        require(_index < URLS.length, "INVALID_ID_LENGTH");
        URLS[_index] = _gateway;
    }

    /// @dev : function to activate CCIP read data:uri 
    /// @notice : https://github.com/ethers-io/ethers.js/issues/3341
    function resetGateway() external onlyDev {
        unchecked {
            uint id = URLS.length;
            while (id > 1) {
                URLS.pop();
                --id;
            }
            URLS[0] = string('data:text/plain,{"data":"{data}"}');
        }
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

    function isNFT(bytes memory _label) public view returns(bool) {
        uint len = _label.length;
        uint k = 0;
        unchecked {
            for (uint i = 0; i < len; i++) {
                if (_label[i] < 0x30 || _label[i] > 0x39) return false;
                k = (k * 10) + (uint8(_label[i]) - 48);
            }
        }
        return (k < BENSYC.totalSupply());
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
                _namehash = baseHash;
                _index -= 3; //index of ...<*>.bensyc.eth
                _namehash = keccak256(
                    abi.encodePacked(
                        isNFT(labels[_index]) ? primaryDomainHash : _namehash,
                        keccak256(labels[_index])
                    )
                );
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
        unchecked {
            uint len = URLS.length;
            string[] memory _gateways = new string[](len);
            for (uint i = 0; i < len; i++) {
                _gateways[i] = URLS[i];
            }
            revert OffchainLookup(
                address(this), // callback contract
                _gateways, // gaateway URL array
                _result, // {data} field
                XCCIP.resolveWithoutProof.selector, // callback function
                abi.encode( // extradata
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
                    block.number,
                    _namehash,
                    _calldata
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
    function resolveWithoutProof(
        bytes calldata response,
        bytes calldata extraData
    ) external view returns(bytes memory _result) {
        (
            bytes32 checkHash,
            uint256 blknum,
            bytes32 _namehash,
            bytes memory _calldata
        ) = abi.decode(extraData, (bytes32, uint256, bytes32, bytes));

        _result = getResult(_namehash, _calldata);
        if (URLS.length == 1 && keccak256(_result) != keccak256(response)) 
            revert InvalidResult(_result, response);

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
            if (check != checkHash || block.number > blknum + 5) {
                revert RequestError(checkHash, check, _calldata, blknum, _result);
            }
        }
    }
}