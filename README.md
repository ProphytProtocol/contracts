# Prophyt Protocol - Contracts

Prophyt is a decentralized prediction market protocol built on the Sui blockchain that integrates with multiple DeFi yield protocols to generate passive income from betting funds while markets are active.

## Overview

Prophyt combines prediction markets with automated yield farming, allowing users to:
- Create and participate in prediction markets
- Earn yield on deposited funds through integration with leading Sui DeFi protocols
- Receive commemorative NFTs as proof of participation
- Benefit from automated yield optimization through the Prophyt Agent

## Architecture

### Core Components

#### Prediction Market (`prediction_market.move`)
- **Market Creation**: Users can create prediction markets with custom questions and durations
- **Betting System**: Users place bets on binary outcomes (Yes/No)
- **Resolution**: Markets are resolved by authorized users after the end time
- **Claim System**: Winners can claim their share of the losing pool plus yield earnings
- **Fee Structure**: Protocol and transaction fees are configurable

#### Protocol Selector (`protocol_selector.move`)
- **Multi-Protocol Integration**: Manages connections to Suilend, Haedal, and Volo protocols
- **Automatic Selection**: Chooses optimal protocol based on APY, TVL, and risk metrics
- **Yield Optimization**: Automatically deposits and withdraws funds across protocols
- **Balance Management**: Tracks user balances across all integrated protocols

#### Prophyt Agent (`prophyt_agent.move`)
- **Automated Rebalancing**: Monitors APY differences and triggers rebalancing
- **Risk Management**: Configurable thresholds and risk tolerance levels
- **Performance Tracking**: Records rebalancing history and statistics
- **Opportunity Analysis**: Identifies yield optimization opportunities

### Protocol Adapters

#### Suilend Adapter (`suilend_adapter.move`)
- Integrates with Suilend lending protocol
- Manages deposits, withdrawals, and balance tracking
- Provides current APY and TVL information

#### Haedal Adapter (`haedal_adapter.move`)
- Integrates with Haedal liquid staking protocol
- Includes whitelist functionality for access control
- Manages validator staking and unstaking operations

#### Volo Adapter (`volo_adapter.move`)
- Integrates with Volo yield farming protocol
- Implements share-based accounting system
- Supports multiple yield strategies
- Includes performance fee mechanism

### Supporting Components

#### Walrus Proof NFTs (`walrus_proof_nft.move`)
- **Bet Proof NFTs**: Minted when users place bets
- **Winning Proof NFTs**: Minted when users claim winnings
- **Market Proof NFTs**: General market participation proofs
- **Walrus Integration**: Uses Walrus for decentralized blob storage

#### Access Control (`access_control.move`)
- Owner capabilities for administrative functions
- Pausable functionality for emergency stops
- Role-based permission system

#### Constants (`constants.move`)
- Protocol identifiers and fee limits
- Risk level definitions
- Scoring weights for protocol selection

## Key Features

### 1. Yield-Generating Prediction Markets
- Funds deposited in prediction markets automatically earn yield
- Users receive their original bet plus a share of generated yield
- Multiple DeFi protocols ensure optimal yield rates

### 2. Intelligent Protocol Selection
- Automated selection based on APY, TVL, and risk metrics
- Dynamic rebalancing to maximize returns
- Fallback mechanisms for protocol failures

### 3. Commemorative NFTs
- Proof of participation stored on Walrus
- Detailed metadata including bet information and outcomes
- Visual representations with custom images

### 4. Risk Management
- Configurable risk tolerance levels
- Pausable contracts for emergency situations
- Owner controls for critical functions

## Technical Specifications

### Dependencies
- **Sui Framework**: Core blockchain functionality
- **Walrus**: Decentralized blob storage for NFT metadata

### Supported Protocols
1. **Suilend** (ID: 1) - Lending protocol with stable yields
2. **Haedal** (ID: 2) - Liquid staking with validator rewards
3. **Volo** (ID: 3) - Yield farming with strategy optimization

### Fee Structure
- **Protocol Fee**: Up to 20% of generated yield (configurable)
- **Transaction Fee**: Up to 10% of bet amount (configurable)
- **Performance Fee**: Protocol-specific (Volo example)

## Contract Interactions

### Market Lifecycle
1. **Market Creation**: `create_market()` with question, description, and duration
2. **Betting Phase**: `place_bet()` with position and amount
3. **Yield Generation**: Funds automatically deposited to optimal protocol
4. **Market Resolution**: `resolve_market()` after end time
5. **Claim Winnings**: `claim_winnings()` to receive rewards and yield

### Yield Optimization
1. **Automatic Deposits**: Best protocol selected based on current metrics
2. **Rebalancing**: Agent monitors and triggers fund movements
3. **Withdrawals**: Funds retrieved from protocols as needed

## Security Features

- **Access Controls**: Owner-only functions for critical operations
- **Pausable Contracts**: Emergency stop functionality
- **Input Validation**: Comprehensive error checking
- **Time-Based Logic**: Proper market lifecycle enforcement
- **Balance Tracking**: Accurate accounting across all protocols

## Development and Testing

### Test Coverage
- Unit tests for individual components
- Integration tests for cross-contract interactions
- Test fixtures for consistent testing environments

### Configuration
- Flexible parameter settings for different environments
- Configurable fees, thresholds, and risk levels
- Support for testnet and mainnet deployments

## Future Enhancements

- Additional DeFi protocol integrations
- Advanced yield strategies
- Multi-asset market support
- Governance token integration
- Enhanced analytics and reporting

---

**Version**: 1.0.0  
**Edition**: 2024.beta  
**Authors**: Prophyt Team
