# Reward Distributor Smart Contract

A comprehensive reward distribution system built on the Stacks blockchain with staking, vesting, and governance features.

## Overview

The Reward Distributor Smart Contract enables the creation and management of reward pools where users can stake STX tokens and earn rewards over time. The contract includes advanced features such as vesting schedules, emergency controls, and administrative governance.

## Features

- **Multi-Pool Support**: Create up to 100 reward pools with different parameters
- **Flexible Staking**: Users can stake and withdraw STX tokens with dynamic reward calculations
- **Vesting Schedules**: Configure time-locked token distributions with cliff periods
- **Emergency Controls**: Emergency stop functionality and withdrawal capabilities
- **Fee Management**: Configurable fee system for reward distributions
- **Admin Governance**: Multi-admin system with role-based permissions

## Constants

- **Minimum Stake Amount**: 1 STX (1,000,000 microSTX)
- **Maximum Pools**: 100
- **Blocks Per Day**: 144 (approximate)
- **Calculation Precision**: 1,000,000 (6 decimal places)
- **Default Fee**: 5% (500 basis points)

## Contract Structure

### Data Variables

- `contract-owner`: Principal address of the contract owner
- `total-pools`: Current number of active pools
- `emergency-stop`: Emergency stop state flag
- `fee-percentage`: Fee percentage in basis points

### Data Maps

- `pools`: Pool configuration and state information
- `user-stakes`: User staking positions per pool
- `user-rewards`: User reward tracking and calculations
- `vesting-schedules`: Token vesting configurations
- `admins`: Administrative permissions
- `pool-participants`: Pool participation records

## Core Functions

### Pool Management

#### `create-pool`
```clarity
(create-pool name total-rewards duration-blocks min-stake max-participants)
```
Creates a new reward pool with specified parameters.

**Parameters:**
- `name`: Pool identifier (string, max 50 characters)
- `total-rewards`: Total STX rewards for distribution
- `duration-blocks`: Pool duration in blocks
- `min-stake`: Minimum stake requirement
- `max-participants`: Maximum number of participants

**Returns:** Pool ID on success

#### `deactivate-pool`
```clarity
(deactivate-pool pool-id)
```
Deactivates a pool, preventing new stakes.

#### `extend-pool`
```clarity
(extend-pool pool-id additional-blocks additional-rewards)
```
Extends pool duration and adds additional rewards.

### Staking Functions

#### `stake-in-pool`
```clarity
(stake-in-pool pool-id amount)
```
Stakes STX tokens in a specified pool.

**Requirements:**
- Pool must be active
- Amount must meet minimum stake requirement
- Pool must not exceed participant limit
- Must be called before pool end block

#### `withdraw-stake`
```clarity
(withdraw-stake pool-id amount)
```
Withdraws staked tokens from a pool. Automatically calculates and updates pending rewards.

#### `collect-rewards`
```clarity
(collect-rewards pool-id)
```
Claims accumulated rewards from a pool. Applies configured fee percentage.

### Vesting Functions

#### `create-vesting-schedule`
```clarity
(create-vesting-schedule user pool-id total-amount duration-blocks cliff-blocks)
```
Creates a vesting schedule for a user.

**Parameters:**
- `user`: Beneficiary principal
- `pool-id`: Associated pool
- `total-amount`: Total vesting amount
- `duration-blocks`: Vesting duration
- `cliff-blocks`: Cliff period before vesting begins

#### `claim-vested-tokens`
```clarity
(claim-vested-tokens pool-id)
```
Claims available vested tokens based on schedule.

### Administrative Functions

#### `set-admin`
```clarity
(set-admin admin enabled)
```
Grants or revokes admin permissions.

#### `transfer-ownership`
```clarity
(transfer-ownership new-owner)
```
Transfers contract ownership.

#### `set-emergency-stop`
```clarity
(set-emergency-stop stop)
```
Enables or disables emergency stop mode.

#### `set-fee-percentage`
```clarity
(set-fee-percentage fee)
```
Updates the fee percentage (maximum 100%).

### View Functions

#### `get-pool-info`
```clarity
(get-pool-info pool-id)
```
Returns complete pool information.

#### `get-user-stake`
```clarity
(get-user-stake user pool-id)
```
Returns user's stake information for a pool.

#### `get-pending-rewards`
```clarity
(get-pending-rewards user pool-id)
```
Calculates current pending rewards for a user.

#### `get-vesting-info`
```clarity
(get-vesting-info user pool-id)
```
Returns vesting schedule information and claimable amounts.

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR-NOT-AUTHORIZED | Insufficient permissions |
| u101 | ERR-INVALID-AMOUNT | Invalid amount specified |
| u102 | ERR-INSUFFICIENT-BALANCE | Insufficient balance for operation |
| u103 | ERR-POOL-NOT-FOUND | Pool does not exist |
| u104 | ERR-ALREADY-CLAIMED | Rewards already claimed |
| u105 | ERR-NOT-ELIGIBLE | User not eligible for operation |
| u106 | ERR-PERIOD-NOT-ENDED | Time period has not ended |
| u107 | ERR-INVALID-PERIOD | Invalid time period specified |
| u108 | ERR-ZERO-AMOUNT | Amount must be greater than zero |
| u109 | ERR-POOL-INACTIVE | Pool is not active |
| u110 | ERR-VESTING-NOT-STARTED | Vesting period has not started |
| u111 | ERR-ALREADY-VESTED | Tokens already vested |
| u112 | ERR-EMERGENCY-STOPPED | Contract in emergency stop mode |
| u113 | ERR-INVALID-PRINCIPAL | Invalid principal address |
| u114 | ERR-INVALID-POOL-ID | Invalid pool identifier |
| u115 | ERR-INVALID-STRING | Invalid string parameter |

## Reward Calculation

Rewards are calculated using the following formula:

```
User Reward = (User Stake × Blocks Elapsed × Pool Reward Per Block) / Total Pool Staked
```

Where:
- `User Stake`: Amount of STX staked by the user
- `Blocks Elapsed`: Number of blocks since last claim
- `Pool Reward Per Block`: Total pool rewards divided by pool duration
- `Total Pool Staked`: Sum of all stakes in the pool

## Fee Structure

The contract applies a configurable fee to reward distributions:
- Default fee: 5% (500 basis points)
- Maximum fee: 100% (10,000 basis points)
- Fees are transferred to the contract owner
- Net rewards = Total rewards - Fee amount

## Security Features

### Input Validation
- Principal address validation
- Pool ID range validation
- String length validation
- Amount and period validation

### Emergency Controls
- Emergency stop functionality
- Emergency withdrawal for users
- Admin permission system
- Owner-only critical functions

### Reentrancy Protection
- State updates before external calls
- Comprehensive error handling
- Transaction rollback on failure

## Usage Examples

### Creating a Pool
```clarity
;; Create a 30-day reward pool
(contract-call? .reward-distributor create-pool
  "30-Day STX Pool"
  u100000000  ;; 100 STX in rewards
  u4320       ;; 30 days in blocks
  u1000000    ;; 1 STX minimum stake
  u100        ;; Max 100 participants
)
```

### Staking in a Pool
```clarity
;; Stake 10 STX in pool 1
(contract-call? .reward-distributor stake-in-pool u1 u10000000)
```

### Claiming Rewards
```clarity
;; Claim accumulated rewards from pool 1
(contract-call? .reward-distributor collect-rewards u1)
```