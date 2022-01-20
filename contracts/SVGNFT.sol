// Give the contract some SVG code
// Output an NFT URI with this SVG code
// Storing all the NFT metadata on-chain

// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "base64-sol/base64.sol";

contract SVGNFT is ERC721URIStorage {
    uint256 public tokenCounter;

    event CreatedSVGNFT(uint256 indexed tokenId, string tokenURI); 

    // Called when the contract is deployed
    constructor() ERC721("SVG NFT", "svgNFT") {
        tokenCounter = 0;
    }

    function create(string memory _svg) public {
        // Mint a token to the caller
        _safeMint(msg.sender, tokenCounter);
        string memory imageURI = svgToImageURI(_svg);
        string memory tokenURI = formateTokenURI(imageURI);
        // Associate the formatted base64 json object of the svg with the token
        _setTokenURI(tokenCounter, tokenURI);

        // Emiting an event is just logging the defined parameters on the blockchain. The event data can be seen from the contract address, but they are inaccessable within a contract.
        // I added it here for logging and testing
        emit CreatedSVGNFT(tokenCounter, tokenURI);
        tokenCounter = tokenCounter + 1;
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
    function formateTokenURI(string memory _imageURI)
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
                                '{"name": "SVG NFT", "description": "AN NFT from an SVG", "attributes":"any custom attributes", "image": "',
                                _imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }
}
