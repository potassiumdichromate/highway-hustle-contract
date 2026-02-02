    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.20;

    /**
    * @title PlayerSessionTracker
    * @dev Tracks player sessions on 0G blockchain for Highway Hustle
    * @notice Every GET API call records a session on-chain
    */
    contract PlayerSessionTracker {
        
        // ========== STRUCTS ==========
        struct Session {
            address playerAddress;
            string identifier;      // wallet/email/discord/telegram
            uint256 timestamp;
            string sessionType;     // "all", "privy", "game", "gamemode", "vehicle"
            uint256 currency;
            uint256 bestScore;
            bool exists;
        }

        // ========== STATE VARIABLES ==========
        address public owner;
        uint256 public totalSessions;
        uint256 public totalUniquePlayers;
        
        // Mappings
        mapping(uint256 => Session) public sessions;
        mapping(string => uint256[]) public playerSessions; // identifier => session IDs
        mapping(string => bool) public hasPlayedBefore;
        mapping(string => uint256) public lastSessionTime;
        
        // ========== EVENTS ==========
        event SessionRecorded(
            uint256 indexed sessionId,
            string indexed identifier,
            address playerAddress,
            string sessionType,
            uint256 timestamp
        );
        
        event NewPlayerRegistered(
            string indexed identifier,
            uint256 timestamp
        );

        // ========== MODIFIERS ==========
        modifier onlyOwner() {
            require(msg.sender == owner, "Only owner can call this");
            _;
        }

        // ========== CONSTRUCTOR ==========
        constructor() {
            owner = msg.sender;
            totalSessions = 0;
            totalUniquePlayers = 0;
        }

        // ========== MAIN FUNCTIONS ==========
        
        /**
        * @dev Record a new player session
        * @param _identifier Player identifier (wallet/email/discord/telegram)
        * @param _playerAddress Player's wallet address (0x0 if not available)
        * @param _sessionType Type of API call (all/privy/game/gamemode/vehicle)
        * @param _currency Player's current currency
        * @param _bestScore Player's best score across all modes
        */
        function recordSession(
            string memory _identifier,
            address _playerAddress,
            string memory _sessionType,
            uint256 _currency,
            uint256 _bestScore
        ) external onlyOwner returns (uint256) {
            
            // Check if new player
            if (!hasPlayedBefore[_identifier]) {
                hasPlayedBefore[_identifier] = true;
                totalUniquePlayers++;
                emit NewPlayerRegistered(_identifier, block.timestamp);
            }
            
            // Create session
            uint256 sessionId = totalSessions;
            
            sessions[sessionId] = Session({
                playerAddress: _playerAddress,
                identifier: _identifier,
                timestamp: block.timestamp,
                sessionType: _sessionType,
                currency: _currency,
                bestScore: _bestScore,
                exists: true
            });
            
            // Update mappings
            playerSessions[_identifier].push(sessionId);
            lastSessionTime[_identifier] = block.timestamp;
            totalSessions++;
            
            emit SessionRecorded(
                sessionId,
                _identifier,
                _playerAddress,
                _sessionType,
                block.timestamp
            );
            
            return sessionId;
        }

        // ========== VIEW FUNCTIONS ==========
        
        /**
        * @dev Get total sessions for a player
        */
        function getPlayerSessionCount(string memory _identifier) 
            external 
            view 
            returns (uint256) 
        {
            return playerSessions[_identifier].length;
        }
        
        /**
        * @dev Get all session IDs for a player
        */
        function getPlayerSessionIds(string memory _identifier) 
            external 
            view 
            returns (uint256[] memory) 
        {
            return playerSessions[_identifier];
        }
        
        /**
        * @dev Get specific session details
        */
        function getSession(uint256 _sessionId) 
            external 
            view 
            returns (
                address playerAddress,
                string memory identifier,
                uint256 timestamp,
                string memory sessionType,
                uint256 currency,
                uint256 bestScore
            ) 
        {
            require(_sessionId < totalSessions, "Session does not exist");
            Session memory s = sessions[_sessionId];
            return (
                s.playerAddress,
                s.identifier,
                s.timestamp,
                s.sessionType,
                s.currency,
                s.bestScore
            );
        }
        
        /**
        * @dev Get last session time for a player
        */
        function getLastSessionTime(string memory _identifier) 
            external 
            view 
            returns (uint256) 
        {
            return lastSessionTime[_identifier];
        }
        
        /**
        * @dev Check if player has played before
        */
        function hasPlayed(string memory _identifier) 
            external 
            view 
            returns (bool) 
        {
            return hasPlayedBefore[_identifier];
        }

        /**
        * @dev Get contract stats
        */
        function getStats() 
            external 
            view 
            returns (
                uint256 _totalSessions,
                uint256 _totalUniquePlayers,
                address _owner
            ) 
        {
            return (totalSessions, totalUniquePlayers, owner);
        }

        // ========== ADMIN FUNCTIONS ==========
        
        /**
        * @dev Transfer ownership
        */
        function transferOwnership(address _newOwner) external onlyOwner {
            require(_newOwner != address(0), "Invalid address");
            owner = _newOwner;
        }
        
        /**
        * @dev Emergency withdraw (if any ETH sent accidentally)
        */
        function emergencyWithdraw() external onlyOwner {
            payable(owner).transfer(address(this).balance);
        }
    }
