# ZeroDash Blockchain Integration Documentation

## Overview

ZeroDash implements a comprehensive on-chain game data system on the 0G blockchain network. This document outlines all blockchain contracts, their functionalities, and data flows.

---

## Network Information

**Network:** 0G Mainnet  
**Chain ID:** 16661  
**RPC URL:** https://evmrpc.0g.ai  
**Block Explorer:** https://chainscan.0g.ai

---

## Deployed Contracts

### 1. SessionTracker
**Contract Address:** `0x9D8090A0D65370A9c653f71e605718F397D1B69C`  
**Explorer:** https://chainscan.0g.ai/address/0x9D8090A0D65370A9c653f71e605718F397D1B69C

**Purpose:** Tracks all player gameplay sessions and statistics on-chain.

**Recorded Data:**
- Player wallet address
- Current coins balance
- Best score achieved
- Session timestamp

**Key Functions:**
- `saveSession()` - Records a new player session with coins and best score
- `getPlayerSessions()` - Returns array of all sessions for a player
- `getLatestSession()` - Returns the most recent session for a player
- `getPlayerBestScore()` - Returns highest score across all sessions
- `getPlayerTotalCoins()` - Returns cumulative coins earned across all sessions
- `sessionCount()` - Returns total number of sessions for a player
- `totalSessions()` - Returns global session count

**Trigger:** Called when player completes a game session and data needs to be recorded on-chain.

---

### 2. LeaderboardTracker
**Contract Address:** `0xDA53b5bD012606DAa609186d5cbA09373B4c2E1b`  
**Explorer:** https://chainscan.0g.ai/address/0xDA53b5bD012606DAa609186d5cbA09373B4c2E1b

**Purpose:** Creates immutable snapshots of leaderboard standings for historical tracking and verification.

**Recorded Data:**
- Snapshot ID and timestamp
- Requesting player address
- Top players (addresses, scores, standings)
- User's own entry (address, score, standing)
- Top 3 player addresses (first, second, third place)

**Key Functions:**
- `saveLeaderboard()` - Creates a new leaderboard snapshot
- `getSnapshot()` - Returns snapshot details by ID
- `getSnapshotTopPlayers()` - Returns top players from a specific snapshot
- `getPlayerSnapshots()` - Returns all snapshot IDs where player requested data
- `getLatestSnapshot()` - Returns the most recent snapshot
- `getLatestTop3()` - Returns current top 3 player addresses
- `totalSnapshots()` - Returns total number of snapshots created
- `latestSnapshotId()` - Returns the latest snapshot ID

**Trigger:** Called when player views leaderboard to create an immutable record of standings.

---

### 3. ZeroDashPass (NFT)
**Contract Address:** `0x7ebabc38dae76a4b81b011a2c610efbd535c5018`  
**Explorer:** https://chainscan.0g.ai/address/0x7ebabc38dae76a4b81b011a2c610efbd535c5018

**Purpose:** ERC-721 NFT pass system with gasless minting and Merkle tree whitelist.

**NFT Features:**
- **Max Supply:** 100,000 NFTs
- **Mint Price:** 5 0G (for non-whitelisted users)
- **Whitelist:** Free minting via Merkle proof verification
- **Gasless Minting:** Relayer can mint on behalf of users
- **One Per Wallet:** Each address can only mint once

**Recorded Data:**
- Token ownership (ERC-721 standard)
- Mint status per wallet address
- Total minted count
- Whitelist verification via Merkle root

**Key Functions:**
- `mint()` - Mint NFT pass (gasless, accepts recipient address)
- `isWhitelisted()` - Check if address is whitelisted (requires Merkle proof)
- `checkHasMinted()` - Check if address has already minted
- `totalMinted()` - Returns total number of minted NFTs
- `setMerkleRoot()` - Update whitelist Merkle root (owner only)
- `setBaseURI()` - Update metadata base URI (owner only)
- `withdraw()` - Withdraw contract funds (owner only)
- `tokenURI()` - Returns metadata URI for token ID

**Trigger:** Called when player claims NFT pass through the game interface.

---

## Data Flow Architecture

### 1. Session Recording Flow
```
Player Completes Game → Backend API → MongoDB Update → 
Blockchain Service (Async) → SessionTracker.saveSession()
```

### 2. Leaderboard Snapshot Flow
```
Player Views Leaderboard → Backend API → Fetch Top Players + User Rank → 
Blockchain Service (Async) → LeaderboardTracker.saveLeaderboard()
```

### 3. NFT Minting Flow (Gasless)
```
Player Claims Pass → Backend API → Verify Eligibility → 
Backend Relayer → ZeroDashPass.mint(playerAddress, merkleProof) → 
NFT Minted to Player
```

### 4. NFT Minting Flow (Direct)
```
Player Claims Pass → Frontend → User Wallet → 
ZeroDashPass.mint(userAddress, merkleProof) + 5 0G → 
NFT Minted
```

---

## Integration Strategy

### Async Recording Pattern
All blockchain write operations are executed asynchronously to avoid blocking API responses. The pattern follows:

1. **Immediate Response:** API responds to client with MongoDB data immediately
2. **Background Recording:** Blockchain transaction is submitted in the background
3. **Non-Blocking:** API performance is unaffected by blockchain latency
4. **Logging:** Success/failure is logged but does not impact user experience

### Gasless Minting Strategy
ZeroDashPass supports gasless minting via a backend relayer:

1. **Backend Relayer:** Server wallet acts as relayer with 0G balance
2. **User Request:** Player requests NFT mint through API
3. **Verification:** Backend verifies eligibility (whitelisted or payment)
4. **Relayer Mints:** Backend calls `mint(playerAddress, merkleProof)`
5. **Gas Paid By:** Relayer pays gas, user receives NFT directly

### Error Handling
- Blockchain failures are logged but do not break API functionality
- MongoDB remains the source of truth for real-time gameplay
- Blockchain provides immutable historical record and verification
- NFT minting failures are reported to user for retry

---

## Smart Contract Events

All contracts emit events for transparency and tracking:

### SessionTracker Events
- `SessionSaved` - New session recorded with player, coins, score, timestamp, and session ID

### LeaderboardTracker Events
- `LeaderboardSaved` - New snapshot created with snapshot ID, requesting player, user standing, user score, top 3 addresses, and timestamp

### ZeroDashPass Events
- `Minted` - NFT minted with recipient address, minter address (relayer or user), token ID, and whitelist status
- `MerkleRootUpdated` - Whitelist Merkle root updated
- `FundsWithdrawn` - Contract funds withdrawn by owner
- `Transfer` - ERC-721 standard transfer event
- `Approval` - ERC-721 standard approval event

---

## Gas Costs and Performance

### Average Gas Costs (0G Network)
- Session recording: ~0.0001 0G
- Leaderboard snapshot: ~0.0003 0G (varies with top player count)
- NFT mint (whitelisted): ~0.0002 0G
- NFT mint (non-whitelisted): ~0.0002 0G + 5 0G mint price

### Performance Characteristics
- Session and leaderboard write operations are owner-only (backend controlled)
- NFT minting supports both gasless (relayer) and direct (user) modes
- Async design eliminates user-facing latency for sessions/leaderboards
- Scalable to millions of sessions and snapshots
- Merkle tree whitelist provides O(log n) verification efficiency

---

## Security Features

### Access Control
- **SessionTracker:** All write functions restricted to contract owner (backend)
- **LeaderboardTracker:** All write functions restricted to contract owner (backend)
- **ZeroDashPass:** Owner-only functions for Merkle root and URI updates
- Owner is the backend deployer wallet
- Prevents unauthorized data manipulation

### Anti-Cheat Mechanisms
- **SessionTracker:** Owner-only recording prevents player manipulation
- **LeaderboardTracker:** Immutable snapshots prevent leaderboard tampering
- **ZeroDashPass:** 
  - One NFT per wallet enforcement
  - Merkle proof verification for whitelist
  - Reentrancy guards on minting
  - Payment validation (0 0G for whitelisted, 5 0G otherwise)

### Data Integrity
- Immutable on-chain records
- Timestamp verification
- Event logging for audit trails
- Transparent public data
- ERC-721 standard compliance for NFTs

---

## Whitelist Management (ZeroDashPass)

### Merkle Tree Structure
The whitelist uses a Merkle tree for gas-efficient verification:

1. **Leaf Node:** `keccak256(abi.encodePacked(walletAddress))`
2. **Merkle Root:** Stored on-chain in `merkleRoot` variable
3. **Proof Generation:** Off-chain via JavaScript/Python
4. **Verification:** On-chain via OpenZeppelin's `MerkleProof.verify()`

### Updating Whitelist
```javascript
// Example: Update Merkle root (owner only)
await zeroDashPass.setMerkleRoot(newMerkleRoot);
```

### Generating Merkle Proofs (Off-chain)
```javascript
import { MerkleTree } from 'merkletreejs';
import keccak256 from 'keccak256';

// Whitelist addresses
const addresses = ['0xAddress1', '0xAddress2', '0xAddress3'];

// Generate leaves
const leaves = addresses.map(addr => keccak256(addr));

// Create Merkle tree
const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });

// Get root
const root = tree.getRoot().toString('hex');

// Get proof for specific address
const leaf = keccak256('0xAddress1');
const proof = tree.getHexProof(leaf);
```

---

## Monitoring and Maintenance

### Required Monitoring
1. **Deployer Wallet Balance:** Alert when balance falls below 50 0G
2. **Transaction Success Rate:** Monitor blockchain service success/failure logs
3. **NFT Supply:** Track minting progress toward 100,000 max supply
4. **Contract Statistics:** Regular checks via view functions
5. **Event Emissions:** Track events for anomalies

### Maintenance Tasks
1. **Weekly:** Review transaction logs and session counts
2. **Monthly:** 
   - Analyze gas costs and optimize if needed
   - Review NFT mint distribution (whitelisted vs paid)
   - Update whitelist Merkle root if needed
3. **Quarterly:** Audit on-chain data for consistency
4. **As Needed:** Update NFT metadata base URI

---

## Future Enhancements

### Potential Additions
1. **NFT Utilities:** 
   - In-game boosts or perks for NFT holders
   - Exclusive game modes or cosmetics
   - Staking rewards for NFT holders
2. **Achievement System:** On-chain achievement tracking
3. **Tournament Contract:** Competitive events with prize pools
4. **Governance:** NFT holder voting on game features
5. **Cross-Chain Bridge:** Multi-chain NFT support
6. **Dynamic NFTs:** Evolving metadata based on gameplay

### Scalability Considerations
- Current design supports unlimited sessions
- Leaderboard snapshots prevent gas bloat
- NFT max supply cap ensures scarcity
- Merkle tree whitelist scales to millions of addresses
- Gasless minting reduces user friction

---

## Development Resources

### Contract Source Code
All contracts are written in Solidity 0.8.20 with MIT license.

### Hardhat Configuration
```javascript
networks: {
  zerog_mainnet: {
    url: "https://evmrpc.0g.ai",
    chainId: 16661,
    accounts: [DEPLOYER_PRIVATE_KEY]
  }
}
```

### Environment Variables Required
```
DEPLOYER_PRIVATE_KEY=<private_key>
ZEROG_RPC_URL=https://evmrpc.0g.ai
ZEROG_CHAIN_ID=16661

SESSION_CONTRACT_ADDRESS=0x9D8090A0D65370A9c653f71e605718F397D1B69C
LEADERBOARD_CONTRACT_ADDRESS=0xDA53b5bD012606DAa609186d5cbA09373B4c2E1b
ZERODASH_PASS_NFT_ADDRESS=0x7ebabc38dae76a4b81b011a2c610efbd535c5018
```

### NFT Metadata Format
```json
{
  "name": "ZeroDash Pass #1",
  "description": "Official ZeroDash game pass NFT",
  "image": "ipfs://QmHash/1.png",
  "attributes": [
    {
      "trait_type": "Rarity",
      "value": "Common"
    },
    {
      "trait_type": "Mint Date",
      "value": "2026-02-06"
    }
  ]
}
```

---

## Support and Documentation

### Block Explorer
All contracts and transactions are publicly viewable at https://chainscan.0g.ai

### Contract Addresses (Quick Reference)
- **SessionTracker:** `0x9D8090A0D65370A9c653f71e605718F397D1B69C`
- **LeaderboardTracker:** `0xDA53b5bD012606DAa609186d5cbA09373B4c2E1b`
- **ZeroDashPass NFT:** `0x7ebabc38dae76a4b81b011a2c610efbd535c5018`

### NFT Marketplaces
ZeroDashPass NFTs are ERC-721 compliant and compatible with:
- OpenSea
- Rarible
- LooksRare
- 0G-native NFT platforms

### Contact Information
- Development Team: Kult Games
- Technical Lead: Sidhanth (Potassium)

### Version History
- v1.0 (February 2026) - Initial deployment with Session Tracking, Leaderboards, and NFT Pass

---

**Document Version:** 1.0  
**Last Updated:** February 6, 2026  
**Network:** 0G Mainnet  
**Status:** Production
