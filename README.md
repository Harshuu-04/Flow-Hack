# Flow-Hack
Fund pool for collaborative research funding
🧠 Collaborative Research Fund Pool

A decentralized smart contract built in Solidity to manage collaborative research funding.
This system allows multiple contributors to pool ETH, create and vote on research funding proposals, and release funds based on community approval — all transparently on-chain.

🔍 Overview

The Research Fund Pool smart contract enables:

Collective ETH funding by contributors.

Creation of research project proposals requesting funding.

Weighted voting (based on contribution amount).

Automatic fund release when a proposal passes quorum.

Governance managed by contributors, with minimal owner control.

⚙️ Key Features

✅ No Imports or Constructors — works fully standalone.

💸 ETH Pooling System — contributors deposit ETH into a shared pool.

🗳️ Weighted Voting — vote weight = amount contributed.

⏰ Time-Limited Voting — proposals have a voting deadline.

🔒 Reentrancy Protection — safe fund transfers and proposal execution.

⚖️ Configurable Quorum — owner can adjust the quorum percentage (default: 50%).

🔐 Emergency Withdraw (Owner) — owner can withdraw remaining funds if needed.

🏗️ Contract Structure
Section	Description
initialize()	Called once to set the deployer as owner (no constructor used).
contribute()	Deposit ETH into the fund; increases your voting weight.
propose()	Create a proposal for research funding.
vote()	Vote for or against a proposal (weight = your contribution).
executeProposal()	Executes a proposal and transfers funds if it passes quorum.
setQuorumPercent()	Owner can modify quorum percentage (1–99).
ownerEmergencyWithdraw()	Owner can withdraw funds in emergencies.
🧾 Example Workflow

Deploy the contract (no constructor inputs).

Initialize the contract:

contractInstance.initialize();


Contribute ETH:

contractInstance.contribute({ value: 1 ether });


Create a Proposal:

propose(recipient, 0.5 ether, "AI Research", "Fund for AI model training", 7 days);


Vote on Proposals:

vote(1, true); // vote in favor


Execute Proposal after voting period:

executeProposal(1);

📊 Data Tracked

totalContributed: Total ETH in the fund.

contributions[address]: ETH amount contributed by each user.

proposals[id]: Full proposal info (title, recipient, votes, status).

votesFor / votesAgainst: Weighted totals for each proposal.

🧰 Tech Details

Language: Solidity ^0.8.19

License: MIT

Dependencies: None (pure Solidity, no imports)

Deployment: Compatible with Remix, Hardhat, Foundry, or Truffle

🛡️ Security Notes

Contract uses a reentrancy guard for safe fund transfers.

Only the owner can modify quorum or perform emergency withdrawals.

Votes are weighted by contributions to prevent spam voting.

Each address can vote once per proposal.
