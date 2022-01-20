// Code pepared as part of a project for course BGK 519E İTÜ 2022
// By Ahmet and Murat

// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "base64-sol/base64.sol";

contract RandomSVG is ERC721URIStorage, VRFConsumerBase{
    uint256 public tokenCounter;

    bytes32 internal keyHash;
    uint256 internal fee;
    // SVG params
    uint256 public maxNumberOfPaths;
    uint256 public maxNumberOfPathCommands;
    uint256 public size;
    string[] public pathCommands;
    string[] public colors;

    mapping(bytes32 => address) public requestIdToSender;
    mapping(uint256 => uint256) public tokenIdToRandomNumber;
    mapping(bytes32 => uint256) public requestIdToTokenId;

    event CreatedRandomSVG(uint256 indexed tokenId, string tokenURI);
    event CreatedUnfinishedRandomSVG(uint256 indexed tokenId, uint256 randomNumber);
    event requestedRandomSVG(bytes32 indexed requestId, uint256 indexed tokenId); 
    // Called when the contract is deployed
    constructor(address _VRFCoordinator, address _LinkToken, bytes32 _keyHash, uint256 _fee) 
    VRFConsumerBase(_VRFCoordinator, _LinkToken) 
    ERC721("RandomSVG", "rNFT") {
        fee = _fee;
        keyHash = _keyHash;
        tokenCounter = 0;
        
        maxNumberOfPaths = 10;
        maxNumberOfPathCommands = 5;
        size = 500;
        pathCommands = ["M","L"];
        colors = ["red", "blue", "green", "yellow", "black", "white"];
    }

    // Get a random number - Will use VRF oracle to get a random number
    // Use that number to generate a random SVG code
    // base64 encode the SVG code
    // get the tokenURI and mint the NFT.
    function create() public returns (bytes32 requestId) {
        requestId = requestRandomness(keyHash, fee);
        requestIdToSender[requestId] = msg.sender;
        uint256 tokenId = tokenCounter; 
        requestIdToTokenId[requestId] = tokenId;
        tokenCounter = tokenCounter + 1;
        emit requestedRandomSVG(requestId, tokenId);
    }

    // Check to see if it's been minted and a random number have already been returned.
    // Generate the random SVG
    // Turn that into an image URI.
    function finishMint(uint256 tokenId) public {
        // Some security checks
        require(bytes(tokenURI(tokenId)).length <= 0, "tokenURI is already set!"); 
        require(tokenCounter > tokenId, "TokenId has not been minted yet!");
        require(tokenIdToRandomNumber[tokenId] > 0, "Need to wait for the Chainlink node to respond!");

        uint256 randomNumber = tokenIdToRandomNumber[tokenId];
        string memory svg = generateSVG(randomNumber);
        string memory imageURI = svgToImageURI(svg);
        _setTokenURI(tokenId, formatTokenURI(imageURI));
        emit CreatedRandomSVG(tokenId, svg);
    }

    
    // This function gets called by ChainLink VRF with the random number.
    function fulfillRandomness(bytes32 requestId, uint256 randomNumber) internal override{
        address nftOwner = requestIdToSender[requestId];
        uint256 tokenId = requestIdToTokenId[requestId];
        _safeMint(nftOwner, tokenId);
        // Can't generate the SVG here because Chainlink VRF has a limit of 20k gas. My function takes much more than that. So wil send a call back to my smart contract so it can start generating the SVG
        tokenIdToRandomNumber[tokenId] = randomNumber;
        emit CreatedUnfinishedRandomSVG(tokenId, randomNumber);
    }



    function generateSVG(uint256 _randomNumber) public view returns (string memory finalSVG){
        uint256 numberOfPaths = (_randomNumber % maxNumberOfPaths) + 1;
        finalSVG = string(abi.encodePacked("<svg xmlns='http://www.w3.org/2000/svg' height='", uint2str(size),"' width='",uint2str(size),"'>"));

        // Generate a random path
        for(uint i =0; i<numberOfPaths; i++){
            uint256 newRNG = uint256(keccak256(abi.encode(_randomNumber, i)));
            string memory pathSVG = generatePath(newRNG);
            finalSVG = string(abi.encodePacked(finalSVG, pathSVG));
        }

        finalSVG = string(abi.encodePacked(finalSVG, "</svg>"));
    }

    function generatePath(uint256 _randomNumber) public view returns(string memory pathSVG){
        uint256 numberOfPathCommands = (_randomNumber % maxNumberOfPathCommands) + 1;
        pathSVG = "<path d='";
        for(uint i = 0; i<numberOfPathCommands; i++){
            uint256 newRNG = uint256(keccak256(abi.encode(_randomNumber, size + i)));
            string memory pathCommand = generatePathCommand(newRNG);
            pathSVG = string(abi.encodePacked(pathSVG, pathCommand));
        }
        string memory color = colors[_randomNumber % colors.length];
        pathSVG = string(abi.encodePacked(pathSVG, "' fill='transparent' stroke='", color, "'/>"));
    }

    function generatePathCommand(uint256 _randomNumber) public view returns(string memory pathCommand) {
        pathCommand = pathCommands[_randomNumber % pathCommands.length];
        uint256 parameterOne = uint256(keccak256(abi.encode(_randomNumber, size * 2))) % size;
        uint256 parameterTwo = uint256(keccak256(abi.encode(_randomNumber, size * 3))) % size;
        pathCommand = string(abi.encodePacked(pathCommand, " ", uint2str(parameterOne), " ", uint2str(parameterTwo)));
    }

    // Turn svg string to an img uri of type base64 encoding
    function svgToImageURI(string memory _svg)
        public
        pure
        returns (string memory)
    {
        string memory baseURL = "data:image/svg+xml;base64,";
        // Encode using open library. Can be found here: https://github.com/OpenZeppelin/solidity-jwt/blob/master/contracts/Base64.sol
        string memory svgBase64Encoded = Base64.encode(
            bytes(string(abi.encodePacked(_svg)))
        );
        string memory imageURI = string(
            abi.encodePacked(baseURL, svgBase64Encoded)
        );

        return imageURI;
    }

    // Create a base64 encoded JSON object to hold the metadata of the svg with the base64 encoded version of it.
    function formatTokenURI(string memory _imageURI)
        public
        pure
        returns (string memory)
    {
        string memory baseURL = "data:application/json;base64,";
        return
            string(
                abi.encodePacked(
                    baseURL,
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name": "SVG NFT", "description": "An SVG created as part of a proof of concept for BGK 519E ITU 2022", "attributes":"any custom attributes", "image": "',
                                _imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    // Taken as is from Stackoverflow: https://stackoverflow.com/questions/47129173/how-to-convert-uint-to-string-in-solidity
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
