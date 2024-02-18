//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";
import "./IBlast.sol"; 

// Pool for issuing cETH and fETH
contract DegenDongs is
    ERC1155,
    Ownable,
    Pausable,
    ERC1155Burnable,
    ERC1155Supply,
    ReentrancyGuard
{
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using Arrays for uint256[];
    using Arrays for address[];

    uint256 private constant DIX_ID = 0;
    uint256 private constant MIN_DONG_ID = 1;
    uint256 private constant MIN_MEAT_ID = 10000;
    Counters.Counter private _dongTracker;
    Counters.Counter private _meatTracker;
    uint256 public constant DONGS_MAX_SUPPLY = 6969;
    uint256 public constant DONGS_MINT_PRICE = 0.069 ether;
    uint256 public constant DIX_DECIMALS = 18;
    uint256 public constant DIX_MAX_SUPPLY = 69696969696969696969696969;
    uint256 public _meatCurrentId = MIN_MEAT_ID;
    uint256 public _dixCurrentSupply = 0;

    uint256 public tester;

    mapping (uint256 => address) public _dongHolders;
    mapping (uint256 => uint256[]) public _meatHolders;

    constructor() ERC1155("ipfs://k51qzi5uqu5dk8485k3h956mnjbrq35dg6gxp4il0x4wippdps92ap3n6jfrbo/{id}.json") Ownable(msg.sender) {
        IBlast(0x4300000000000000000000000000000000000002).configureAutomaticYield();
        IBlast(0x4300000000000000000000000000000000000002).configureGovernor(msg.sender);
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    // Put up yield-generating ETH as collateral and mint cETH and current fETH
    function mintDong(uint256 amount) external payable nonReentrant {
        require(MIN_DONG_ID + _dongTracker.current() + amount <= DONGS_MAX_SUPPLY, "No dongs left!");
        require(msg.value >= DONGS_MINT_PRICE * amount, "Pay more for your dong");
        for(uint256 i = 0; i < amount; i++) {
            uint256 _currentId = MIN_DONG_ID + _dongTracker.current();
            mint(msg.sender, _currentId, 1, "");
            _dongHolders[_currentId] = msg.sender;
            _dongTracker.increment();
        }
    }

    function burnMeat(uint256 _id) external nonReentrant{
        uint256 _paymentForBurn = _dixCurrentSupply / 100000; // Pareto optimum of meat???
        require(1 <= balanceOf(msg.sender, _id), "You don't hold this meat!");
        require(_paymentForBurn <= balanceOf(msg.sender, DIX_ID), "You don't hold enough DIX to burn meat!");
        _burn(msg.sender, DIX_ID, _paymentForBurn);
        _burn(msg.sender, _id, 1);
    }

    function mintMeatToDong() external nonReentrant {
        uint256 dixToMint = SafeMath.div(DIX_MAX_SUPPLY - _dixCurrentSupply, 1000);
        uint256 currentMaxDong = MIN_DONG_ID + _dongTracker.current();
        (bool success, uint256 dongIdSub) = SafeMath.tryMod(dixToMint, currentMaxDong - 1);
        tester = dongIdSub + 1;
        if (!success) revert();
        address dongHolder = holderOf(dongIdSub + 1);

        uint256 meatId = MIN_MEAT_ID + _meatTracker.current(); 
        mint(dongHolder, meatId, 1, "");
        mint(msg.sender, DIX_ID, dixToMint, "");
        _meatTracker.increment();
    }

    function holderOf(uint256 id) public view returns (address) {
        require(_dongHolders[id] != address(0), "Token has never been owned");
        return _dongHolders[id];
    }

    function updateDongHolders(uint256 id, address newHolder) internal {
        if (id >= MIN_DONG_ID && id <= _dongTracker.current()) {
                _dongHolders[id] = newHolder;
            }
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 id, uint256 value, bytes memory data)
        internal 
    {
        if (id == DIX_ID) {
            require(_dixCurrentSupply + value <= DIX_MAX_SUPPLY, "No DIX left!");
            _dixCurrentSupply += value;
        } else if (id >= MIN_MEAT_ID) {
            _meatCurrentId = id;
        }
        _mint(to, id, value, data);
    }

    function burn(address to, uint256 id, uint256 value)
        public 
        override(ERC1155Burnable)
    {
        super.burn(to, id, value);
        if (id == DIX_ID) {
            require(_dixCurrentSupply + value <= DIX_MAX_SUPPLY, "No DIX left!");
            _dixCurrentSupply -= value;
        }
    }

    function burnBatch(address account, uint256[] memory ids, uint256[] memory values)
        public 
        override(ERC1155Burnable)
    {
        super.burnBatch(account, ids, values);
        for (uint256 id = 0; id < ids.length; ++id) {
            if (id == DIX_ID) {
                uint256 value = values[id];
                require(_dixCurrentSupply - value >= 0, "How did you do that!?");
                _dixCurrentSupply -= value;
            }
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        public
        override(ERC1155)
    {
        super.safeTransferFrom(from, to, id, amount, data);
        updateDongHolders(id, to);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        public
        override(ERC1155)
    {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; ++i) {
            updateDongHolders(ids[i], to);
        }
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override(ERC1155, ERC1155Supply) {
        return super._update(from, to, ids, values);
    }

    function appendValue(uint256[] storage array, uint256 value) internal {
        array.push(value);
    }

    function removeValue(uint256[] storage array, uint256 value) internal {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                array[i] = array[array.length - 1];
                array.pop();
                break; 
            }
        }
    }
}
