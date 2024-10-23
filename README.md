# Bitcoin-Based DAO Smart Contract

This smart contract implements a decentralized autonomous organization (DAO) built on the Stacks blockchain, utilizing Bitcoin for governance, voting, fund management, and investment tracking. It features enhanced functionality, including delegation, investment returns, emergency controls, and governance parameter updates.

## Features

- **Governance and Voting:** Allows members to propose and vote on decisions.
- **Fund Management:** Manages a treasury with contributions and allocates funds for proposals.
- **Investment Tracking:** Tracks returns from investments and enables distribution to members.
- **Delegation System:** Members can delegate their voting power to trusted individuals.
- **Emergency Controls:** Administrators can activate emergency modes for DAO security.
- **Governance Parameters:** Adjustable parameters to manage proposal fees, voting delays, quorum thresholds, and more.

## Contract Overview

### Error Codes
- `ERR-NOT-AUTHORIZED` (u100): Unauthorized action.
- `ERR-ALREADY-VOTED` (u101): The user has already voted.
- `ERR-PROPOSAL-EXPIRED` (u102): The proposal has expired.
- `ERR-INSUFFICIENT-FUNDS` (u103): Insufficient funds for the action.
- `ERR-INVALID-AMOUNT` (u104): Invalid amount provided.
- `ERR-PROPOSAL-NOT-ACTIVE` (u105): Proposal is not active.
- `ERR-QUORUM-NOT-REACHED` (u106): Quorum threshold was not met.
- Additional errors handle delegation, emergency control, and parameter validation.

### Data Structures

#### Variables
- **dao-admin:** Administrator of the DAO.
- **minimum-quorum:** Minimum quorum threshold (50% in basis points).
- **voting-period:** Duration of voting (approximately 1 day).
- **treasury-balance:** Current balance of the DAO’s treasury.

#### Maps
- **members:** Tracks DAO members, their voting power, contributions, and withdrawal history.
- **proposals:** Stores active proposals with details like amount, proposer, target, and voting results.
- **votes:** Records votes cast by members on proposals.
- **investment-returns:** Tracks investment returns distributed to members.
- **delegations:** Stores delegated voting power.
- **return-pools:** Tracks pools created for investment returns.

## Key Functionalities

### Membership and Contributions

#### `join-dao` (public)
Allows users to join the DAO by registering their principal and initializing their voting power.

#### `contribute-funds` (public)
Members can contribute STX to the DAO, increasing their voting power proportional to their contribution.

### Proposals and Voting

#### `create-proposal` (public)
DAO members can propose initiatives by providing a title, description, requested funds, and a target recipient.

#### `vote` (public)
Members can vote on proposals, either supporting or opposing them, using their voting power.

#### `execute-proposal` (public)
Once the voting period ends, a proposal can be executed if quorum is reached and it receives majority support.

### Delegation System

#### `delegate-votes` (public)
Members can delegate their voting power to another member for a specified period.

#### `revoke-delegation` (public)
Members can revoke any active delegation, reclaiming their voting power.

### Investment and Returns

#### `create-return-pool` (public)
Creates a pool to manage returns from successful proposals or investments, which members can claim.

#### `claim-returns` (public)
Allows members to claim their share of returns from a successful proposal’s return pool.

### Emergency and Governance Controls

#### `set-emergency-state` (public)
Allows emergency administrators to enable or disable the emergency state of the DAO.

#### `update-dao-parameters` (public)
DAO administrators can update key governance parameters such as proposal fees, voting periods, and quorum thresholds.

## Read-Only Functions

- `get-member-info`: Retrieves a member's voting power, contribution history, and more.
- `get-proposal-by-id`: Fetches a proposal by its ID.
- `get-treasury-balance`: Returns the current balance of the DAO's treasury.
- `has-claimed`: Checks if a member has claimed returns from a specific pool.
- `get-dao-parameters`: Retrieves the current governance parameters.

## Internal Functions

- **percentage-of:** Helper function to calculate percentages.
- **validate-parameters:** Ensures new DAO parameters are valid when updated.
- **calculate-member-share:** Calculates a member's share of a return pool.

## Governance Parameters

- **proposal-fee:** Fee required to create a proposal (default: 0.1 STX).
- **min-proposal-amount:** Minimum amount requested in a proposal (default: 1 STX).
- **voting-period:** Period for voting (default: ~1 day).
- **quorum-threshold:** Minimum votes required for a proposal to pass (default: 50%).

## Emergency Controls

The DAO includes a feature for emergency control, allowing trusted admins to take action during critical situations by enabling or disabling the DAO.

## Setup and Development

### Clarity Environment

To deploy and interact with the contract, follow these steps:

1. Clone the repository and navigate to the project directory.
2. Use the Clarity CLI (`@stacks/clarity-cli`) to test and deploy the contract.
3. Set up a Stacks wallet to interact with the deployed contract.

### Testing

Use the included test suite with **Vitest** and **Stacks transactions** to test all critical functionalities like proposal creation, voting, and governance parameter updates.

### Deploying the Contract

Ensure your environment is configured for deploying Clarity contracts to the Stacks blockchain. Deploy the contract using your preferred tools.