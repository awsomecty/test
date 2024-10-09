// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract Ballot {
    struct Voter {
        uint weight;       // 计票的权重
        bool voted;        // 若为真，代表该人已投票
        address delegate;  // 被委托人
        uint vote;         // 投票提案的索引
    }

    struct Proposal {
        bytes32 name; // 简称(最长32个字节)
        uint voteCount; // 得票数
    }

    address public chairperson;

    mapping(address => Voter) public voters;

    Proposal[] public proposals;

    uint public startTime;
    uint public endTime;

    constructor(bytes32[] memory proposalNames, uint _startTime, uint _endTime) {
        chairperson = msg.sender;
        require(_startTime >= block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        startTime = _startTime;
        endTime = _endTime;

        for (uint i = 0; i < proposalNames.length; i++) {
            proposals.push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }

    modifier onlyChairperson() {
        require(msg.sender == chairperson, "Only chairperson can perform this action.");
        _;
    }

    modifier beforeVotingStarts() {
        require(block.timestamp < startTime, "Voting has already started.");
        _;
    }

    function giveRightToVote(address voter) external onlyChairperson {
        require(!voters[voter].voted, "The voter already voted.");
        require(voters[voter].weight == 0);
        voters[voter].weight = 1;
    }

    function setVoterWeight(address voter, uint weight) external onlyChairperson beforeVotingStarts {
        require(weight > 0, "Weight must be greater than 0.");
        voters[voter].weight = weight;
    }

    function vote(uint proposal) external {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, "Has no right to vote");
        require(!sender.voted, "Already voted.");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Voting is outside of the time window.");

        sender.voted = true;
        sender.vote = proposal;
        proposals[proposal].voteCount += sender.weight;
    }

    function winningProposal() public view returns (uint winningProposal_) {
        uint winningVoteCount = 0;
        for (uint p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    function winnerName() external view returns (bytes32 winnerName_) {
        winnerName_ = proposals[winningProposal()].name;
    }

    function delegate(address to) external {
        Voter storage sender = voters[msg.sender];
        require(sender.weight != 0, "You have no right");
        require(!sender.voted, "You already voted.");
        require(to != msg.sender, "Self-delegation is disallowed.");
        while (voters[to].delegate != address(0)) {
            to = voters[to].delegate;
            require(to != msg.sender, "Found loop in delegation.");
        }
        Voter storage delegate_ = voters[to];
        require(delegate_.weight >= 1);
        sender.voted = true;
        sender.delegate = to;
        if (delegate_.voted) {
            proposals[delegate_.vote].voteCount += sender.weight;
        } else {
            delegate_.weight += sender.weight;
        }
    }
}