//SPDX-License-Identifier: WTFPL v6.9
pragma solidity >=0.8.4;

interface iOverloadResolver {
    function addr(bytes32 node, uint256 coinType)
        external
        view
        returns (bytes memory);
}

interface iResolver {
    function contenthash(bytes32 node) external view returns (bytes memory);
    function addr(bytes32 node) external view returns (address payable);
    function pubkey(bytes32 node)
        external
        view
        returns (bytes32 x, bytes32 y);
    function text(bytes32 node, string calldata key)
        external
        view
        returns (string memory);
    function name(bytes32 node) external view returns (string memory);
}

interface iCCIP {
    function resolve(bytes memory name, bytes memory data)
        external
        view
        returns (bytes memory);
}

interface iERC20 {
    function transferFrom(address _from, address _to, uint256 _value)
        external
        returns (bool success);
}

interface iENS {
    event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);
    event Transfer(bytes32 indexed node, address owner);
    event NewResolver(bytes32 indexed node, address resolver);
    event NewTTL(bytes32 indexed node, uint64 ttl);
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function setRecord(
        bytes32 node,
        address owner,
        address resolver,
        uint64 ttl
    )
        external;
    function setSubnodeRecord(
        bytes32 node,
        bytes32 label,
        address owner,
        address resolver,
        uint64 ttl
    )
        external;
    function setSubnodeOwner(bytes32 node, bytes32 label, address owner)
        external
        returns (bytes32);
    function setResolver(bytes32 node, address resolver) external;
    function setOwner(bytes32 node, address owner) external;
    function setTTL(bytes32 node, uint64 ttl) external;
    function setApprovalForAll(address operator, bool approved) external;
    function owner(bytes32 node) external view returns (address);
    function resolver(bytes32 node) external view returns (address);
    function ttl(bytes32 node) external view returns (uint64);
    function recordExists(bytes32 node) external view returns (bool);
    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);
}

interface iERC165 {
    function supportsInterface(bytes4 interfaceID)
        external
        view
        returns (bool);
}

interface iBENSYC {
    function totalSupply() external view returns (uint256);
    function Dev() external view returns (address);
    function Namehash2ID(bytes32 node) external view returns (uint256);
    function ID2Namehash(uint256 id) external view returns (bytes32);
    function ownerOf(uint256 id) external view returns (address);
}