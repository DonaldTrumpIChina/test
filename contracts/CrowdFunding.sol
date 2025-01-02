// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CrowdFunding is Ownable {
    struct Project {
    uint256  targetAmount;
    uint256  deadline;
    uint256  raisedAmount;
    bool  isCrowdFundingActive;
    uint256  lastContributorIndex;
    mapping(address => uint256)  contributions;
    address[]  contributors;
    }

    using SafeERC20 for IERC20;
    /////////////////////////////////////////////
    ////////////////// ERRORS ///////////////////
    /////////////////////////////////////////////
    error CrowdFunding_hasClosed();
    error CrowdFunding_zeroAmount();
    error CrowdFunding_crowdFundingActive();
    error CrowdFunding_cannotClaim(uint256 _id);

    /////////////////////////////////////////////
    ////////////////// STATE ////////////////////
    /////////////////////////////////////////////
    uint256 constant MAX_LOOP_LENGTH = 500;
    IERC20 public immutable i_token;
    mapping(uint256 => Project) public s_projects;
    uint256 public index;

    /////////////////////////////////////////////
    ///////////////// EVENTS ////////////////////
    /////////////////////////////////////////////
    event ContributeMade(uint256 indexed _index, address indexed _contributor, uint256 _amount);
    event FundsClaimed(uint256 indexed _index, uint256 _amount);
    event CrowdFundingStarted(uint256 indexed _index, uint256  _targetAmount, uint256 _duration);

    /////////////////////////////////////////////
    //////////////// MODIFIER ///////////////////
    /////////////////////////////////////////////
    modifier beforeDeadline(uint256 _id) {
        if(block.timestamp >= s_projects[_id].deadline){
            revert CrowdFunding_hasClosed();
        }
        _;
    }
    modifier moreThanZero(uint256 _amount){
        if(_amount == 0){
            revert CrowdFunding_zeroAmount();
        }
        _;
    }

    /////////////////////////////////////////////
    /////////////// CONSTRUCTOR /////////////////
    /////////////////////////////////////////////
    constructor(address token) Ownable(msg.sender){
        i_token = IERC20(token);
    }

    /////////////////////////////////////////////
    ///////////////// PUBLIC ////////////////////
    /////////////////////////////////////////////
    function contribute(uint256 _id, uint256 _amount) public 
    moreThanZero(_amount) 
    beforeDeadline(_id)
    {
        if (s_projects[_id].contributions[msg.sender] == 0){
            s_projects[_id].contributors.push(msg.sender);
        }
        s_projects[_id].contributions[msg.sender] += _amount;
        s_projects[_id].raisedAmount += _amount;
        emit ContributeMade(_id, msg.sender, _amount);
        i_token.safeTransferFrom(msg.sender, address(this), _amount);
    }
    function claimFunds(uint256 _id) public onlyOwner 
    {
        if (s_projects[_id].raisedAmount < s_projects[_id].targetAmount || block.timestamp < s_projects[_id].deadline){
            revert CrowdFunding_cannotClaim(_id);    
        }else{
            s_projects[_id].isCrowdFundingActive = false;
            emit FundsClaimed(_id, s_projects[_id].raisedAmount);
            i_token.safeTransfer(owner(), s_projects[_id].raisedAmount);
        }
    }
    function startCrowdFunding(uint256 _target, uint256 _d) public onlyOwner 
    {
        s_projects[index].targetAmount = _target;
        s_projects[index].deadline = block.timestamp + _d;
        s_projects[index].raisedAmount = 0;
        s_projects[index].isCrowdFundingActive = true;
        s_projects[index].lastContributorIndex = 0;
        emit CrowdFundingStarted(index, _target, _d);
        ++index;
    }
    /**
        @notice Repay the token to the contributors if the targetAmount is not reached.
        @notice To avoid gas cost out of block limit and DOS, we replay token to 
        a certain number of contributors in each call.
        @dev If all token has been repaid, the function returns true.
    */
    function repayToken(uint256 _id) public onlyOwner returns(bool){
        if(s_projects[_id].raisedAmount < s_projects[_id].targetAmount && block.timestamp >= s_projects[_id].deadline && s_projects[_id].isCrowdFundingActive){
           return _repay(_id);
        }
        revert CrowdFunding_crowdFundingActive();
    }

    /////////////////////////////////////////////
    //////////////// PRIVATE ////////////////////
    /////////////////////////////////////////////
    function _repay(uint256 _id) private returns(bool isdown){
        uint256 len = s_projects[_id].contributors.length;
        uint256 _lastContributorIndex = s_projects[_id].lastContributorIndex;
        uint256 boundry = (_lastContributorIndex + MAX_LOOP_LENGTH) > len ? len : (_lastContributorIndex + MAX_LOOP_LENGTH);
        for(uint256 i = _lastContributorIndex; i < boundry;){
            address contributor = s_projects[_id].contributors[i];
            uint256 amount = s_projects[_id].contributions[contributor];
            i_token.safeTransfer(contributor, amount);
            unchecked{
                ++i;
            }
        }
        isdown = (boundry==len);
        s_projects[_id].lastContributorIndex = boundry;
        if (isdown){
            s_projects[_id].isCrowdFundingActive = false;
        }
    }

    /////////////////////////////////////////////
    ////////////////// VIEWS ////////////////////
    /////////////////////////////////////////////
    function getCrowdFundingProgress(uint256 _id) public view returns(uint256, uint256){
        return (s_projects[_id].raisedAmount, s_projects[_id].targetAmount);
    }
    function getCrowdFundingToken() public view returns(address){
        return address(i_token);
    }
    function getCrowdFundingDeadline(uint256 _id) public view returns(uint256){
        return s_projects[_id].deadline;
    }
    function getCrowdFundingStatus(uint256 _id) public view returns(bool){
        return s_projects[_id].isCrowdFundingActive;
    }
    function getUserContribution(uint256 _id, address _user) public view returns(uint256){
        return s_projects[_id].contributions[_user];
    }
}
