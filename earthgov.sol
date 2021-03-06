// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract EarthGOV is ERC721, AccessControl {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _governorCounter;
    Counters.Counter private _iteration;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DELEGATE_ROLE = keccak256("DELEGATE_ROLE");
    bytes32 public constant SENATOR_ROLE = keccak256("SENATOR_ROLE");
    bytes32 public constant REPRESENTATIVE_ROLE = keccak256("REPRESENTATIVE_ROLE");
    bytes32 public constant CITIZEN_ROLE = keccak256("CITIZEN_ROLE");

    uint256 public PRICE;
    uint256 public MAX_GOVERNORS;
    uint256 private HASHED;
    uint256 private TEMP;

    PaymentSplitter private _splitter;

    constructor(
        address[] memory payees,
        uint256[] memory shares,
        string memory customBaseURI_,
        uint256 price
    ) ERC721("EarthGOV", "EGV") {
        customBaseURI = customBaseURI_;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        PRICE = price;
        MAX_GOVERNORS = 6000;
        _splitter = new PaymentSplitter(payees, shares);

    }

    // ---ADMIN FUNCTIONS---

    bool public isMigrationEnabled;
    bool public isGovernanceEnabled;
    mapping(address => uint256) public migratedWallets;

    function setPrice(uint256 price_) external onlyRole(DEFAULT_ADMIN_ROLE){
        PRICE = price_;
    }

    function toggleIsMigrationEnabled() external onlyRole(DEFAULT_ADMIN_ROLE){
        isMigrationEnabled = !isMigrationEnabled;
    }

    function toggleGovernanceEnabled() external onlyRole(DEFAULT_ADMIN_ROLE){
        isGovernanceEnabled = !isGovernanceEnabled;
    }

    // ---URI HADNLING---

    string private customBaseURI;

    function baseTokenURI() public view returns (string memory) {
        return customBaseURI;
    }

    function setBaseURI(string memory customBaseURI_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        customBaseURI = customBaseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return customBaseURI;
    }

    // ---USER FUNCTIONS---

    function grantCitizenship (address citizen) external onlyRole(REPRESENTATIVE_ROLE){
        require(isGovernanceEnabled,'government shut down');
        _grantRole(CITIZEN_ROLE, citizen);
        payees[citizen]++;
    }

    function grantDelegation (address representative) external onlyRole(CITIZEN_ROLE){
        require(isGovernanceEnabled,'government shut down');
        require(hasRole(REPRESENTATIVE_ROLE,representative),'not a representative');
        _grantRole(DELEGATE_ROLE, representative);
    }

    function grantMintAllowance (address senator) external onlyRole(REPRESENTATIVE_ROLE){
        require(isGovernanceEnabled,'government shut down');
        require(hasRole(SENATOR_ROLE, senator),'not a senator');
        _grantRole(MINTER_ROLE, senator);
        _revokeRole(DELEGATE_ROLE, msg.sender);
    }

    function hashCheck(string hash_) internal returns (bool){
        return true;
        // CONFIDENTIAL
        // HIDDEN
    }

    function migrate() external payable{        
        require(isMigrationEnabled, 'Migration not enabled');
        require(migratedWallets[msg.sender]<1, 'Max 1 per wallet');
        require(message.value == price, 'You are starving the citizens');
        require(maxGovernors > _governorCounter , 'Migration complete');
        require(hashCheck(msg.data), 'you are not an adopter');

        migratedWallets[msg.sender]++;
        _governorCounter.increment();
        uint256 tokenId = _iteration;
        // set tokenUrl will be added (external dao protocol)
        // iteration can be ditched
        _safeMint(msg.sender, tokenId);
	    if (_iteration < 2000){
            _grantRole(SENATOR_ROLE, msg.sender);
        }else{
            _grantRole(REPRESENTATIVE_ROLE, msg.sender);
            payees[msg.sender]++;
        }
    }

    function normalMint(address to) external payable onlyRole(MINTER_ROLE) {
        require(isGovernanceEnabled,'government shut down');
        require(msg.value<price, 'insufficient funds');
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        // needs different token counter that starts from 6000
        _safeMint(to, tokenId);
        _revokeRole(MINTER_ROLE, msg.sender);
        payable(_splitter).transfer(msg.value);
    }

    // ---TRADING---

    mapping (uint256 => uint256) public tokenIdToPrice;

    function allowBuy(uint256 _tokenId, uint256 _price) external {
        require(msg.sender == ownerOf(_tokenId), 'Not owner of this token');
        require(_price > 0, 'Price zero');
        tokenIdToPrice[_tokenId] = _price;
    }

    function disallowBuy(uint256 _tokenId) external {
        require(msg.sender == ownerOf(_tokenId), 'Not owner of this token');
        tokenIdToPrice[_tokenId] = 0;
    }
    
    function trade(uint256 _tokenId) external payable {
        uint256 price = tokenIdToPrice[_tokenId];
        require(price > 0, 'This token is not for sale');
        require(msg.value == price, 'Incorrect value');
        
        address seller = ownerOf(_tokenId);
        _transfer(seller, msg.sender, _tokenId);
        tokenIdToPrice[_tokenId] = 0; // not for sale anymore
        if (_tokenId<2000){
            _revokeRole(SENATOR_ROLE, seller);
            _grantRole(SENATOR_ROLE, msg.sender);
        } else if (_tokenId<6000){
            _revokeRole(REPRESENTATIVE_ROLE, seller);
            _grantRole(REPRESENTATIVE_ROLE, msg.sender);
            payees[msg.sender]++;
            payees[seller]--;
        } 
        payable(seller).transfer(msg.value);

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
