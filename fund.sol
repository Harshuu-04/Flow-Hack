// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ResearchFundPool {
    /* ========== STATE ========== */
    address public owner;                 // set via initialize()
    bool public initialized;

    uint256 public totalContributed;      // sum of all contributions (wei)
    uint16 public quorumPercent = 50;     // % of totalContributed needed to approve (default 50%)

    uint256 public proposalCount;

    struct Proposal {
        uint256 id;
        address proposer;
        address payable recipient;
        string title;
        string description;
        uint256 requestedAmount;         // wei
        uint256 votesFor;                // weighted by contributions (wei)
        uint256 votesAgainst;            // weighted by contributions (wei)
        uint256 createdAt;               // block.timestamp
        uint256 votingDeadline;          // timestamp when voting ends
        bool executed;
    }

    // proposals storage
    mapping(uint256 => Proposal) public proposals;

    // contributions per address (used as voting weight and for record)
    mapping(address => uint256) public contributions;

    // track if an address has voted on a proposal
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /* ========== REENTRANCY GUARD ========== */
    bool private _locked;

    modifier noReentrant() {
        require(!_locked, "Reentrant");
        _locked = true;
        _;
        _locked = false;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Only owner");
        _;
    }

    modifier onlyInitialized() {
        require(initialized, "Not initialized");
        _;
    }

    /* ========== EVENTS ========== */
    event Initialized(address indexed owner);
    event Contributed(address indexed contributor, uint256 amount);
    event ProposalCreated(uint256 indexed id, address indexed proposer, address recipient, uint256 requestedAmount, uint256 votingDeadline);
    event Voted(uint256 indexed id, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id, address indexed recipient, uint256 amount);
    event QuorumPercentChanged(uint16 oldPercent, uint16 newPercent);

    /* ========== INITIALIZE (no constructor) ========== */
    /// @notice Must be called once by the deployer to become owner.
    function initialize() external {
        require(!initialized, "Already initialized");
        owner = msg.sender;
        initialized = true;
        emit Initialized(owner);
    }

    /* ========== CONTRIBUTIONS ========== */
    /// @notice Contribute ETH to the research fund. Contribution amount is used as voting weight.
    function contribute() external payable onlyInitialized {
        require(msg.value > 0, "Zero contribution");

        // update contributor balance and total
        contributions[msg.sender] += msg.value;
        totalContributed += msg.value;

        emit Contributed(msg.sender, msg.value);
    }

    /* ========== PROPOSALS ========== */
    /// @notice Create a new research funding proposal.
    /// @param _recipient Address that will receive funds if proposal passes.
    /// @param _requestedAmount Amount in wei requested to fund the project.
    /// @param _title Short title.
    /// @param _description Longer description.
    /// @param _votingPeriodSeconds How long voting remains open (seconds). Must be > 0 and reasonable.
    function propose(
        address payable _recipient,
        uint256 _requestedAmount,
        string calldata _title,
        string calldata _description,
        uint256 _votingPeriodSeconds
    ) external onlyInitialized returns (uint256) {
        require(_recipient != address(0), "Invalid recipient");
        require(_requestedAmount > 0, "Amount must be > 0");
        require(_votingPeriodSeconds >= 1 hours && _votingPeriodSeconds <= 30 days, "Voting period 1h-30d");
        require(_requestedAmount <= address(this).balance, "Requested > contract balance");

        proposalCount += 1;
        uint256 pid = proposalCount;

        proposals[pid] = Proposal({
            id: pid,
            proposer: msg.sender,
            recipient: _recipient,
            title: _title,
            description: _description,
            requestedAmount: _requestedAmount,
            votesFor: 0,
            votesAgainst: 0,
            createdAt: block.timestamp,
            votingDeadline: block.timestamp + _votingPeriodSeconds,
            executed: false
        });

        emit ProposalCreated(pid, msg.sender, _recipient, _requestedAmount, proposals[pid].votingDeadline);
        return pid;
    }

    /* ========== VOTING ========== */
    /// @notice Vote on a proposal. Voting weight equals your contributed ETH amount.
    /// @param _proposalId Proposal id.
    /// @param _support true to vote for, false to vote against.
    function vote(uint256 _proposalId, bool _support) external onlyInitialized {
        Proposal storage p = proposals[_proposalId];
        require(p.id != 0, "No such proposal");
        require(block.timestamp <= p.votingDeadline, "Voting closed");
        require(contributions[msg.sender] > 0, "No contribution => no vote");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");

        uint256 weight = contributions[msg.sender];
        require(weight > 0, "Zero weight");

        hasVoted[_proposalId][msg.sender] = true;

        if (_support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }

        emit Voted(_proposalId, msg.sender, _support, weight);
    }

    /* ========== EXECUTION ========== */
    /// @notice Execute a proposal if it has met quorum and voting deadline passed. Sends funds to recipient.
    /// @param _proposalId Proposal id.
    function executeProposal(uint256 _proposalId) external onlyInitialized noReentrant {
        Proposal storage p = proposals[_proposalId];
        require(p.id != 0, "No such proposal");
        require(!p.executed, "Already executed");
        require(block.timestamp > p.votingDeadline, "Voting still open");
        require(p.requestedAmount <= address(this).balance, "Insufficient contract balance");

        // Check quorum: votesFor must be >= quorumPercent of totalContributed
        // Note: totalContributed could be zero if no contributions; handle that
        require(totalContributed > 0, "No contributions");
        uint256 required = (uint256(quorumPercent) * totalContributed) / 100;
        require(p.votesFor >= required, "Quorum not reached");

        // Mark executed first (checks-effects-interactions)
        p.executed = true;

        // Transfer requested funds to recipient
        (bool sent, ) = p.recipient.call{value: p.requestedAmount}("");
        require(sent, "Transfer failed");

        emit ProposalExecuted(_proposalId, p.recipient, p.requestedAmount);
    }

    /* ========== OWNER CONTROLS ========== */
    /// @notice Owner can change quorum percentage (1-99)
    function setQuorumPercent(uint16 _percent) external onlyOwner onlyInitialized {
        require(_percent >= 1 && _percent <= 99, "Percent 1-99");
        uint16 old = quorumPercent;
        quorumPercent = _percent;
        emit QuorumPercentChanged(old, _percent);
    }

    /// @notice In case of emergency owner may withdraw unallocated funds (use carefully).
    /// Only allows withdrawing funds not locked by pending approved proposals: to keep logic simple,
    /// this withdraws any amount up to contract balance. Use with caution.
    function ownerEmergencyWithdraw(address payable _to, uint256 _amount) external onlyOwner onlyInitialized noReentrant {
        require(_to != address(0), "Invalid to");
        require(_amount <= address(this).balance, "Amount > balance");
        (bool ok, ) = _to.call{value: _amount}("");
        require(ok, "Withdraw failed");
    }

    /* ========== VIEW HELPERS ========== */
    function proposalExists(uint256 _id) external view returns (bool) {
        return proposals[_id].id != 0;
    }

    function timeLeftToVote(uint256 _id) external view returns (uint256) {
        Proposal storage p = proposals[_id];
        if (p.id == 0) return 0;
        if (block.timestamp >= p.votingDeadline) return 0;
        return p.votingDeadline - block.timestamp;
    }

    /* ========== FALLBACKS ========== */
    receive() external payable {
        // Accept plain transfers; treat them as contributions
        contributions[msg.sender] += msg.value;
        totalContributed += msg.value;
        emit Contributed(msg.sender, msg.value);
    }

    fallback() external payable {
        // Accept fallback ETH as contribution
        if (msg.value > 0) {
            contributions[msg.sender] += msg.value;
            totalContributed += msg.value;
            emit Contributed(msg.sender, msg.value);
        }
    }
}
0x76C11e9B6427237e011B5b76B9A5a5D5578f0689
