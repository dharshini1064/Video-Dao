// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.20;

interface VidInterface {
    function getPriorVotes(address account, uint blockNumber) external view returns (uint96);
}

// from https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
contract DAO {
    /// @notice The name of this contract
    string public constant name = "Vedio DAO";

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    function quorumVotes() public pure returns (uint256) { return 100*1000*1000*(10e18); } // 10% of VID

    /// @notice The number of votes required in order for a voter to become a proposer
    function proposalThreshold() public pure returns (uint256) { return 10*1000*1000*(10e18); } // 1% of VID

    /// @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() public pure returns (uint256) { return 10; } // 10 actions

    /// @notice The delay before voting on a proposal may take place, once proposed
    function votingDelay() public pure returns (uint256) { return 1; } // 1 block

    /// @notice The duration of voting on a proposal, in blocks
    function votingPeriod()  public pure returns (uint256) { return 17280; } // ~3 days in blocks (assuming 15s blocks)
    /// @notice the life time of a proposal
    function proposalLifeTime() public pure returns(uint256) { return 14*24*60*60; }


     /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;

        /// @notice Creator of the proposal
        address proposer;

        /// @notice proposal detail, which will be store in ipfs
        string url;

        /// @notice how much money which the proposal need
        uint256 needMoney;
        /// @ notice who receive money after proposal executed
        address receiver;

        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;

        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;

        /// @notice Current number of votes in favor of this proposal
        uint256 forVotes;

        /// @notice Current number of votes in opposition to this proposal
        uint256 againstVotes;

        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;

        /// @notice Flag marking whether the proposal has been executed
        bool executed;

        /// @notice propose expire time
        uint expireTime;

        /// @notice Receipts of ballots for the entire set of voters
        mapping (address => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;

        /// @notice Whether or not the voter supports the proposal
        bool support;

        /// @notice The number of votes the voter had, which were cast
        uint96 votes;
    }

    uint256 proposalCount;
     /// @notice The official record of all proposals ever proposed
    mapping (uint => Proposal) public proposals;

    /// @notice The address of the Video DAO governance token
    VidInterface public vid;

    /// @notice An event emitted when create a proposal
    event ProposalCreated(uint256 indexed id, address indexed proposer, string url, uint256 startBlock, 
        uint256 endBlock,uint256 expireTime);

    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(address voter, uint proposalId, bool support, uint votes);

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint id, uint eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint id);


    constructor(address vid_){
        vid = VidInterface(vid_);
    }

    function propose(string memory url, uint needMoney, address receiver) public returns(uint256) {
        require(vid.getPriorVotes(msg.sender, block.number-1)>proposalThreshold(), "DAO: propose: proposer votes below proposal threshold");

        uint256 proposalId = ++proposalCount;
        Proposal storage proposal = proposals[proposalId];

        //init
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.url = url;
        proposal.needMoney = needMoney;
        proposal.receiver = receiver;
        proposal.startBlock = block.number+votingDelay();
        proposal.endBlock = block.number + votingPeriod();
        proposal.expireTime = block.timestamp + proposalLifeTime();
        proposal.forVotes  = 0;
        proposal.againstVotes = 0;
        proposal.executed = false;
        proposal.canceled = false;

        emit ProposalCreated(proposal.id, proposal.proposer, proposal.url, proposal.startBlock, 
                proposal.endBlock, proposal.expireTime);
        return proposalId;
    }

    function cancel(uint proposalId) public {
        require( state(proposalId) != ProposalState.Executed, "DAO::cancel: cannot cancel executed proposal");

        require(msg.sender == proposals[proposalId].proposer,"DAO:cancel: only proposer of proposal can cancel proposal");
        proposals[proposalId].canceled = true;

        emit ProposalCanceled(proposalId);
    }

    function execute(uint proposalId) public payable {
        require(state(proposalId) == ProposalState.Queued, "DAO::execute: proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        payable(proposal.receiver).transfer(proposal.needMoney);

        emit ProposalExecuted(proposalId);
    }

    function castVote(uint proposalId, bool support) public {
        return _castVote(msg.sender, proposalId, support);
    }

    function _castVote(address voter, uint proposalId, bool support) internal {
        require(state(proposalId) == ProposalState.Active, "DAO::_castVote: voting is closed");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "DAO::_castVote: voter already voted");
        uint96 votes = vid.getPriorVotes(voter, proposal.startBlock);

        if (support) {
            proposal.forVotes = proposal.forVotes + votes;
        } else {
            proposal.againstVotes = proposal.againstVotes + votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(voter, proposalId, support, votes);
    }


    function state(uint proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > 0, "DAO::state: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.expireTime<block.timestamp){
            return ProposalState.Expired;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes()) {
            return ProposalState.Defeated;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else {
            return ProposalState.Queued;
        }
    }
}