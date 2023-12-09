// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.20;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UserCenter is Ownable {
    struct User {
        address addr;
        string nickname;
        string bio;
        string email;
        uint256 credits;
    }

    event AccountCreated(address indexed);


    mapping(address=> User) public users;
    address public vidAddress;
    address public daoAddress;

    constructor() Ownable(msg.sender){
       
    }
    function initializeAddress(address vidAddress_, address daoAddress_) external onlyOwner {
        require(vidAddress == address(0));
        vidAddress = vidAddress_;
        daoAddress = daoAddress_;
    }

    function createAccount(string memory nickname, string memory bio, string memory email) public {
        User storage user = users[msg.sender];
        require(user.addr == address(0));
        
        user.addr = msg.sender;
        user.nickname = nickname;
        user.bio = bio;
        user.email = email;

        emit AccountCreated(msg.sender);
    }

    function userExist(address addr) public view returns(bool) {
        return users[addr].addr != address(0);
    }

    function income(address who) public payable {
        uint256 daoValue = msg.value/100;
        uint256 userValue = msg.value/100*99;
        payable(who).transfer(userValue);
        payable(daoAddress).transfer(daoValue);

        // TODO: consider other contribution calculate
        uint256 contribution = daoValue;
        _addUserCredits(who, contribution);
    }

    function convertCreditsToToken(uint256 amount) external {
        require(users[msg.sender].credits >= amount, "UserCenter: insufficient credits");

        unchecked {
            users[msg.sender].credits -= amount;
        }

        IERC20(vidAddress).transfer(msg.sender, amount);
    }

    //internal functions
    function _addUserCredits(address who,uint256 value) internal {
        users[who].credits +=  value;
    }
}