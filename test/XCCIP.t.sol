// SPDX-License-Identifier: WTFPL.ETH
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "src/XCCIP.sol";
contract XCCIPTest is Test {
    function setUp() public {}

    XCCIP internal xccip;
    CallDataCheck internal CDCheck;
    constructor(){
        xccip = new XCCIP();
        CDCheck = new CallDataCheck();
    }
    function ENSEncode(bytes[] memory _names) internal pure returns(bytes32 _namehash, bytes memory _name) {
        uint i = _names.length;
        _name = abi.encodePacked(bytes1(0));
        _namehash = bytes32(0);
        unchecked{
            while(i > 0){
                --i;
                _name = bytes.concat(bytes1(uint8(_names[i].length)), _names[i], _name);
                _namehash = keccak256(abi.encodePacked(_namehash, keccak256(_names[i])));
            }
        }
    }

    function testSetup() public {
        bytes[] memory _test = new bytes[](2);
        _test[0] = "bensyc";
        _test[1] = "eth";
        (bytes32 _namehash, bytes memory _name) = ENSEncode(_test);
        assertEq(_name, bytes.concat(bytes1(uint8(6)), "bensyc", bytes1(uint8(3)), "eth", bytes1(0)));
        assertEq(_namehash, bytes32(0xa17cd809a74d642f629c4b3997883d6f5772bb8f9c93b9a5eaea05d000bfdec5));
    }
    function testDomain2Hash() public {
        bytes[] memory _src = new bytes[](2);
        _src[0] = "bensyc";
        _src[1] = "eth";
        (, bytes memory _name) = ENSEncode(_src);

        bytes[] memory _dst = new bytes[](2);
        _dst[0] = "boredensyachtclub";
        _dst[1] = "eth";
        (bytes32 _namehash,) = ENSEncode(_dst);

        assertEq(xccip.ENSDecode(_name), _namehash);
    } 

    function testWildcardDomain2Hash() public {
        bytes[] memory _src = new bytes[](3);
        _src[0] = "vitalik";
        _src[1] = "bensyc";
        _src[2] = "eth";
        (, bytes memory _name) = ENSEncode(_src);

        bytes[] memory _dst = new bytes[](2);
        _dst[0] = "vitalik";
        _dst[1] = "eth";
        (bytes32 _namehash,)= ENSEncode(_dst);

        assertEq(xccip.ENSDecode(_name), _namehash);
    } 
    function testNFTDomain2Hash() public {
        bytes[] memory _src = new bytes[](3);
        _src[0] = "0";
        _src[1] = "bensyc";
        _src[2] = "eth";
        (, bytes memory _name) = ENSEncode(_src);

        bytes[] memory _dst = new bytes[](3);
        _dst[0] = "0";
        _dst[1] = "boredensyachtclub";
        _dst[2] = "eth";
        (bytes32 _namehash,)= ENSEncode(_dst);

        assertEq(xccip.ENSDecode(_name), _namehash);
    } 

    function testNFTDomain2Hash2() public {
        bytes[] memory _src = new bytes[](3);
        _src[0] = "4";
        _src[1] = "bensyc";
        _src[2] = "eth";
        (, bytes memory _name) = ENSEncode(_src);

        bytes[] memory _dst = new bytes[](3);
        _dst[0] = "4";
        _dst[1] = "boredensyachtclub";
        _dst[2] = "eth";
        (bytes32 _namehash, ) = ENSEncode(_dst);

        assertEq(xccip.ENSDecode(_name), _namehash);
    } 
    function testWildcardDomain2Hash2() public {
        bytes[] memory _src = new bytes[](4);
        _src[0] = "www";
        _src[1] = "nick";
        _src[2] = "bensyc";
        _src[3] = "eth";
        (, bytes memory _name) = ENSEncode(_src);

        bytes[] memory _dst = new bytes[](3);
        _dst[0] = "www";
        _dst[1] = "nick";
        _dst[2] = "eth";
        (bytes32 _namehash, )= ENSEncode(_dst);

        assertEq(xccip.ENSDecode(_name), _namehash);
    } 
    function testWildcardNFTDomain2Hash() public {
        bytes[] memory _src = new bytes[](4);
        _src[0] = "nimi";
        _src[1] = "69";
        _src[2] = "bensyc";
        _src[3] = "eth";
        (, bytes memory _name) = ENSEncode(_src);

        bytes[] memory _dst = new bytes[](4);
        _dst[0] = "nimi";
        _dst[1] = "69";
        _dst[2] = "boredensyachtclub";
        _dst[3] = "eth";
        (bytes32 _namehash, )= ENSEncode(_dst);

        assertEq(xccip.ENSDecode(_name), _namehash);
    } 

    function testIsNFT() public{
        assertTrue(xccip.isNFT("0"));
        assertTrue(xccip.isNFT("69")); // after minting
        assertTrue(!xccip.isNFT("9999")); // before minting
        assertTrue(!xccip.isNFT("124abcd"));
        assertTrue(!xccip.isNFT("abcdef"));
        assertTrue(!xccip.isNFT("10000"));

        // _bug/corner case
        assertTrue(xccip.isNFT("001"));
    }

    function testGetResult() public{
        bytes[] memory _dst = new bytes[](2);
        _dst[0] = "boredensyachtclub";
        _dst[1] = "eth";
        (bytes32 _namehash, )= ENSEncode(_dst);
        bytes memory _result = xccip.getResult(_namehash, abi.encodeWithSelector(iResolver.addr.selector, _namehash));
        assertEq(abi.decode(_result, (address)), address(0x5b420EE224881C250C0658fD277DA1aE646a814c));
        _result = xccip.getResult(_namehash, abi.encodeWithSelector(iResolver.text.selector, _namehash, string("avatar")));
        assertEq(abi.decode(_result, (string)), string("ipfs://QmbYMFLgSxrQgRvMZkZyTMuTrPzhwsqu2xRMzE975cYKoq"));
        _result = xccip.getResult(_namehash, abi.encodeWithSelector(iResolver.contenthash.selector, _namehash));
        assertEq(abi.decode(_result, (bytes)), hex"e5010172002408011220546e73f3ef3d9bece42cab6df4b6cec7fc05b823283ad19bbe430c9b400c83fb");
    }

    function testCallDataCheck() public {
        bytes[] memory _src = new bytes[](2);
        _src[0] = "boredensyachtclub";
        _src[1] = "eth";
        (bytes32 _namehash, )= ENSEncode(_src);

        bytes memory _calldata = abi.encodeWithSelector(iResolver.addr.selector, _namehash);
        assertEq(_calldata, CDCheck.getCallData(_namehash, _calldata));
        _calldata = abi.encodeWithSelector(iResolver.text.selector, _namehash, string("avatar"));
        assertEq(_calldata, CDCheck.getCallData(_namehash, _calldata));
        _calldata = abi.encodeWithSelector(iResolver.contenthash.selector, _namehash);
        assertEq(_calldata, CDCheck.getCallData(_namehash, _calldata));
    }

    function testResolveRevert1() public {
        bytes[] memory _src = new bytes[](2);
        _src[0] = "bensyc";
        _src[1] = "eth";
        (bytes32 _srcNamehash, bytes memory _srcName)= ENSEncode(_src);
        bytes memory _calldata = abi.encodeWithSelector(iResolver.addr.selector, _srcNamehash); 
        bytes32 _dstNamehash = xccip.ENSDecode(_srcName);
        _calldata = CDCheck.getCallData(_dstNamehash, _calldata);
        bytes memory _result = xccip.getResult(_dstNamehash, _calldata);
        string[] memory _gateways = new string[](2);
        _gateways[0] = xccip.URLS(0);
        _gateways[1] = xccip.URLS(1);
        bytes memory extradata = abi.encode(
                    keccak256(
                        abi.encodePacked(
                            blockhash(block.number - 1),
                            address(xccip),
                            address(this),
                            _dstNamehash,
                            _calldata,
                            _result
                        )
                    ),
                    block.number,
                    _dstNamehash,
                    _calldata
                );

        vm.expectRevert(
            abi.encodeWithSelector(
                Clone.OffchainLookup.selector, 
                address(xccip),
                _gateways,
                _result,
                XCCIP.resolveWithoutProof.selector,
                extradata
            )
        );
        xccip.resolve(_srcName, _calldata);
        assertEq(
            xccip.resolveWithoutProof(bytes("TEST"), extradata), 
            _result
        );
    }
}
contract CallDataCheck{
    function getCallData(bytes32 _namehash, bytes calldata data) public pure returns(bytes memory) {
        return(data.length > 36) ?
            abi.encodePacked(data[:4], _namehash, data[36:]) :
            abi.encodePacked(data[:4], _namehash);
    }
}
