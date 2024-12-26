// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CommunityVotingPlatform {
    // Proposal structure
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 creationTime;
        uint256 votingDeadline;
        uint256 minimumQuorum;
        uint256 requiredMajority;
        ProposalStatus status;
        uint256 yesVotes;
        uint256 noVotes;
        mapping(address => bool) hasVoted;
    }

    // Enum for proposal status
    enum ProposalStatus {
        Pending,
        Accepted,
        Rejected,
        Expired
    }

    // Membership structure
    struct Member {
        bool isMember;
        uint256 joinedAt;
        uint256 reputation;
    }

    // State variables
    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    
    uint256 public proposalCounter;
    uint256 public memberCounter;

    // Voting parameters
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MINIMUM_MEMBERSHIP_DURATION = 30 days;
    uint256 public constant MEMBERSHIP_FEE = 0.1 ether;

    // Events
    event MemberRegistered(address indexed member, uint256 joinedAt);
    event ProposalCreated(
        uint256 indexed proposalId, 
        address indexed proposer, 
        string title, 
        uint256 creationTime
    );
    event Voted(
        uint256 indexed proposalId, 
        address indexed voter, 
        bool vote
    );
    event ProposalFinalized(
        uint256 indexed proposalId, 
        ProposalStatus status
    );

    // Modifiers
    modifier onlyMembers() {
        require(members[msg.sender].isMember, "Not a community member");
        _;
    }

    modifier proposalExists(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= proposalCounter, "Proposal does not exist");
        _;
    }

    // Join community by paying membership fee
    function joinCommunity() external payable {
        require(msg.value >= MEMBERSHIP_FEE, "Insufficient membership fee");
        require(!members[msg.sender].isMember, "Already a member");

        members[msg.sender] = Member({
            isMember: true,
            joinedAt: block.timestamp,
            reputation: 1
        });

        memberCounter++;
        emit MemberRegistered(msg.sender, block.timestamp);
    }

    // Create a new proposal
    function createProposal(
        string memory _title, 
        string memory _description,
        uint256 _minimumQuorum,
        uint256 _requiredMajority
    ) external onlyMembers {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_minimumQuorum > 0, "Minimum quorum must be > 0");
        require(_requiredMajority > 0 && _requiredMajority <= 100, "Invalid majority percentage");

        proposalCounter++;

        Proposal storage newProposal = proposals[proposalCounter];
        newProposal.id = proposalCounter;
        newProposal.proposer = msg.sender;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.creationTime = block.timestamp;
        newProposal.votingDeadline = block.timestamp + VOTING_PERIOD;
        newProposal.minimumQuorum = _minimumQuorum;
        newProposal.requiredMajority = _requiredMajority;
        newProposal.status = ProposalStatus.Pending;

        emit ProposalCreated(
            proposalCounter, 
            msg.sender, 
            _title, 
            block.timestamp
        );
    }

    // Vote on a proposal
    function vote(uint256 _proposalId, bool _support) 
        external 
        onlyMembers 
        proposalExists(_proposalId)
    {
        Proposal storage proposal = proposals[_proposalId];
        
        // Validate voting conditions
        require(block.timestamp < proposal.votingDeadline, "Voting period has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        
        // Calculate voting weight based on member reputation
        uint256 votingWeight = calculateVotingWeight(msg.sender);

        // Record the vote
        if (_support) {
            proposal.yesVotes += votingWeight;
        } else {
            proposal.noVotes += votingWeight;
        }

        // Mark voter
        proposal.hasVoted[msg.sender] = true;

        emit Voted(_proposalId, msg.sender, _support);
    }

    // Finalize proposal after voting period
    function finalizeProposal(uint256 _proposalId) 
        external 
        proposalExists(_proposalId)
    {
        Proposal storage proposal = proposals[_proposalId];
        
        // Check if voting period has ended
        require(block.timestamp >= proposal.votingDeadline, "Voting not yet completed");
        require(proposal.status == ProposalStatus.Pending, "Proposal already finalized");

        // Calculate total votes and participation
        uint256 totalVotes = proposal.yesVotes + proposal.noVotes;
        uint256 participationRate = (totalVotes * 100) / memberCounter;

        // Check quorum and majority requirements
        if (participationRate >= proposal.minimumQuorum) {
            uint256 yesPercentage = (proposal.yesVotes * 100) / totalVotes;
            
            if (yesPercentage >= proposal.requiredMajority) {
                proposal.status = ProposalStatus.Accepted;
            } else {
                proposal.status = ProposalStatus.Rejected;
            }
        } else {
            proposal.status = ProposalStatus.Expired;
        }

        emit ProposalFinalized(_proposalId, proposal.status);
    }

    // Calculate voting weight based on member reputation
    function calculateVotingWeight(address _voter) 
        internal 
        view 
        returns (uint256) 
    {
        Member memory member = members[_voter];
        
        // Base voting weight is 1
        uint256 weight = 1;

        // Increase weight for long-standing members
        uint256 membershipDuration = block.timestamp - member.joinedAt;
        if (membershipDuration >= MINIMUM_MEMBERSHIP_DURATION) {
            weight += membershipDuration / MINIMUM_MEMBERSHIP_DURATION;
        }

        return weight;
    }

    // Get proposal details
    function getProposalDetails(uint256 _proposalId)
        external 
        view 
        proposalExists(_proposalId)
        returns (
            address proposer,
            string memory title,
            string memory description,
            uint256 creationTime,
            uint256 votingDeadline,
            ProposalStatus status,
            uint256 yesVotes,
            uint256 noVotes
        )
    {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.creationTime,
            proposal.votingDeadline,
            proposal.status,
            proposal.yesVotes,
            proposal.noVotes
        );
    }

    // Allow contract to receive ETH
    receive() external payable {}
}