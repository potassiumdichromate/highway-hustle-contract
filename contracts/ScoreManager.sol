// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ScoreManager
 * @dev Tracks game mode scores and leaderboards on 0G blockchain for Highway Hustle
 * @notice Records all score submissions and creates verifiable leaderboards
 */
contract ScoreManager {
    
    // ========== ENUMS ==========
    enum GameMode { 
        OneWay,      // 0
        TwoWay,      // 1
        TimeAttack,  // 2
        Bomb         // 3
    }
    
    // ========== STRUCTS ==========
    struct ScoreSubmission {
        address playerAddress;
        string identifier;
        GameMode gameMode;
        uint256 score;
        uint256 distance;
        uint256 currency;
        uint256 playTime;
        uint256 timestamp;
        bool verified;
        bool exists;
    }
    
    struct PlayerStats {
        uint256 bestScoreOneWay;
        uint256 bestScoreTwoWay;
        uint256 bestScoreTimeAttack;
        uint256 bestScoreBomb;
        uint256 totalGamesPlayed;
        uint256 totalScore;
        uint256 lastPlayedTime;
        bool exists;
    }
    
    struct LeaderboardEntry {
        string identifier;
        address playerAddress;
        uint256 score;
        uint256 timestamp;
        uint256 rank;
    }
    
    struct LeaderboardSnapshot {
        uint256 snapshotId;
        GameMode gameMode;
        uint256 timestamp;
        uint256 startTime;
        uint256 endTime;
        string period; // "daily", "weekly", "monthly", "alltime"
        LeaderboardEntry[] entries;
        bool exists;
    }
    
    // ========== STATE VARIABLES ==========
    address public owner;
    uint256 public totalSubmissions;
    uint256 public totalPlayers;
    uint256 public totalSnapshots;
    
    // Score tracking
    mapping(uint256 => ScoreSubmission) public submissions;
    mapping(string => PlayerStats) public playerStats;
    mapping(string => uint256[]) public playerSubmissionIds;
    mapping(string => bool) public hasPlayer;
    
    // Leaderboards per game mode
    mapping(GameMode => mapping(string => uint256)) public bestScores; // gameMode => identifier => score
    mapping(GameMode => string[]) public leaderboardPlayers; // gameMode => player identifiers
    
    // Snapshots
    mapping(uint256 => LeaderboardSnapshot) public snapshots;
    mapping(GameMode => uint256[]) public gameModeSnapshots;
    
    // Anti-cheat
    mapping(string => uint256) public lastSubmissionTime;
    uint256 public minSubmissionInterval = 30; // 30 seconds minimum between submissions
    uint256 public maxScorePerSubmission = 1000000; // Reasonable max score
    
    // ========== EVENTS ==========
    event ScoreSubmitted(
        uint256 indexed submissionId,
        string indexed identifier,
        address playerAddress,
        GameMode gameMode,
        uint256 score,
        uint256 timestamp
    );
    
    event NewHighScore(
        string indexed identifier,
        GameMode indexed gameMode,
        uint256 newScore,
        uint256 oldScore,
        uint256 timestamp
    );
    
    event LeaderboardSnapshotCreated(
        uint256 indexed snapshotId,
        GameMode indexed gameMode,
        string period,
        uint256 playerCount,
        uint256 timestamp
    );
    
    event NewPlayer(
        string indexed identifier,
        uint256 timestamp
    );
    
    event ScoreVerified(
        uint256 indexed submissionId,
        string indexed identifier,
        bool verified
    );
    
    // ========== MODIFIERS ==========
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }
    
    modifier validGameMode(GameMode _gameMode) {
        require(uint8(_gameMode) <= 3, "Invalid game mode");
        _;
    }
    
    // ========== CONSTRUCTOR ==========
    constructor() {
        owner = msg.sender;
        totalSubmissions = 0;
        totalPlayers = 0;
        totalSnapshots = 0;
    }
    
    // ========== INTERNAL FUNCTIONS ==========
    
    function registerPlayer(string memory _identifier) internal {
        if (!hasPlayer[_identifier]) {
            hasPlayer[_identifier] = true;
            totalPlayers++;
            
            playerStats[_identifier] = PlayerStats({
                bestScoreOneWay: 0,
                bestScoreTwoWay: 0,
                bestScoreTimeAttack: 0,
                bestScoreBomb: 0,
                totalGamesPlayed: 0,
                totalScore: 0,
                lastPlayedTime: 0,
                exists: true
            });
            
            emit NewPlayer(_identifier, block.timestamp);
        }
    }
    
    function updateBestScore(
        string memory _identifier,
        GameMode _gameMode,
        uint256 _newScore
    ) internal returns (bool isNewRecord) {
        PlayerStats storage stats = playerStats[_identifier];
        uint256 oldScore = 0;
        
        if (_gameMode == GameMode.OneWay) {
            oldScore = stats.bestScoreOneWay;
            if (_newScore > oldScore) {
                stats.bestScoreOneWay = _newScore;
                isNewRecord = true;
            }
        } else if (_gameMode == GameMode.TwoWay) {
            oldScore = stats.bestScoreTwoWay;
            if (_newScore > oldScore) {
                stats.bestScoreTwoWay = _newScore;
                isNewRecord = true;
            }
        } else if (_gameMode == GameMode.TimeAttack) {
            oldScore = stats.bestScoreTimeAttack;
            if (_newScore > oldScore) {
                stats.bestScoreTimeAttack = _newScore;
                isNewRecord = true;
            }
        } else if (_gameMode == GameMode.Bomb) {
            oldScore = stats.bestScoreBomb;
            if (_newScore > oldScore) {
                stats.bestScoreBomb = _newScore;
                isNewRecord = true;
            }
        }
        
        if (isNewRecord) {
            bestScores[_gameMode][_identifier] = _newScore;
            
            // Add to leaderboard if not already there
            bool inLeaderboard = false;
            string[] memory players = leaderboardPlayers[_gameMode];
            for (uint256 i = 0; i < players.length; i++) {
                if (keccak256(bytes(players[i])) == keccak256(bytes(_identifier))) {
                    inLeaderboard = true;
                    break;
                }
            }
            if (!inLeaderboard) {
                leaderboardPlayers[_gameMode].push(_identifier);
            }
            
            emit NewHighScore(_identifier, _gameMode, _newScore, oldScore, block.timestamp);
        }
        
        return isNewRecord;
    }
    
    // ========== MAIN FUNCTIONS ==========
    
    /**
     * @dev Submit a score for a game mode
     */
    function submitScore(
        string memory _identifier,
        address _playerAddress,
        GameMode _gameMode,
        uint256 _score,
        uint256 _distance,
        uint256 _currency,
        uint256 _playTime
    ) external onlyOwner validGameMode(_gameMode) returns (uint256) {
        // Anti-cheat checks
        require(_score <= maxScorePerSubmission, "Score too high");
        require(
            block.timestamp >= lastSubmissionTime[_identifier] + minSubmissionInterval,
            "Submission too frequent"
        );
        
        registerPlayer(_identifier);
        
        // Record submission
        uint256 submissionId = totalSubmissions;
        submissions[submissionId] = ScoreSubmission({
            playerAddress: _playerAddress,
            identifier: _identifier,
            gameMode: _gameMode,
            score: _score,
            distance: _distance,
            currency: _currency,
            playTime: _playTime,
            timestamp: block.timestamp,
            verified: false,
            exists: true
        });
        
        playerSubmissionIds[_identifier].push(submissionId);
        lastSubmissionTime[_identifier] = block.timestamp;
        totalSubmissions++;
        
        // Update player stats
        PlayerStats storage stats = playerStats[_identifier];
        stats.totalGamesPlayed++;
        stats.totalScore += _score;
        stats.lastPlayedTime = block.timestamp;
        
        // Check for new high score
        updateBestScore(_identifier, _gameMode, _score);
        
        emit ScoreSubmitted(
            submissionId,
            _identifier,
            _playerAddress,
            _gameMode,
            _score,
            block.timestamp
        );
        
        return submissionId;
    }
    
    /**
     * @dev Batch submit scores (for offline sessions)
     */
    function batchSubmitScores(
        string memory _identifier,
        address _playerAddress,
        GameMode[] memory _gameModes,
        uint256[] memory _scores,
        uint256[] memory _distances,
        uint256[] memory _currencies,
        uint256[] memory _playTimes
    ) external onlyOwner returns (uint256[] memory) {
        require(_gameModes.length == _scores.length, "Array length mismatch");
        require(_scores.length == _distances.length, "Array length mismatch");
        require(_distances.length == _currencies.length, "Array length mismatch");
        require(_currencies.length == _playTimes.length, "Array length mismatch");
        
        uint256[] memory submissionIds = new uint256[](_gameModes.length);
        
        registerPlayer(_identifier);
        
        for (uint256 i = 0; i < _gameModes.length; i++) {
            require(_scores[i] <= maxScorePerSubmission, "Score too high");
            
            uint256 submissionId = totalSubmissions;
            submissions[submissionId] = ScoreSubmission({
                playerAddress: _playerAddress,
                identifier: _identifier,
                gameMode: _gameModes[i],
                score: _scores[i],
                distance: _distances[i],
                currency: _currencies[i],
                playTime: _playTimes[i],
                timestamp: block.timestamp,
                verified: false,
                exists: true
            });
            
            playerSubmissionIds[_identifier].push(submissionId);
            totalSubmissions++;
            submissionIds[i] = submissionId;
            
            // Update stats
            PlayerStats storage stats = playerStats[_identifier];
            stats.totalGamesPlayed++;
            stats.totalScore += _scores[i];
            stats.lastPlayedTime = block.timestamp;
            
            // Check for high score
            updateBestScore(_identifier, _gameModes[i], _scores[i]);
            
            emit ScoreSubmitted(
                submissionId,
                _identifier,
                _playerAddress,
                _gameModes[i],
                _scores[i],
                block.timestamp
            );
        }
        
        lastSubmissionTime[_identifier] = block.timestamp;
        
        return submissionIds;
    }
    
    /**
     * @dev Verify a score submission (anti-cheat)
     */
    function verifyScore(uint256 _submissionId, bool _verified) 
        external 
        onlyOwner 
    {
        require(_submissionId < totalSubmissions, "Submission does not exist");
        submissions[_submissionId].verified = _verified;
        
        emit ScoreVerified(
            _submissionId,
            submissions[_submissionId].identifier,
            _verified
        );
    }
    
    /**
     * @dev Create leaderboard snapshot
     */
    function createLeaderboardSnapshot(
        GameMode _gameMode,
        string memory _period,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _topN
    ) external onlyOwner validGameMode(_gameMode) returns (uint256) {
        uint256 snapshotId = totalSnapshots;
        
        // Get top N players
        string[] memory players = leaderboardPlayers[_gameMode];
        require(players.length > 0, "No players in leaderboard");
        
        uint256 count = players.length < _topN ? players.length : _topN;
        
        // Sort players by score (simple bubble sort for now, optimize later if needed)
        string[] memory sortedPlayers = new string[](players.length);
        uint256[] memory sortedScores = new uint256[](players.length);
        
        for (uint256 i = 0; i < players.length; i++) {
            sortedPlayers[i] = players[i];
            sortedScores[i] = bestScores[_gameMode][players[i]];
        }
        
        // Bubble sort (descending)
        for (uint256 i = 0; i < sortedPlayers.length; i++) {
            for (uint256 j = i + 1; j < sortedPlayers.length; j++) {
                if (sortedScores[j] > sortedScores[i]) {
                    // Swap scores
                    uint256 tempScore = sortedScores[i];
                    sortedScores[i] = sortedScores[j];
                    sortedScores[j] = tempScore;
                    
                    // Swap players
                    string memory tempPlayer = sortedPlayers[i];
                    sortedPlayers[i] = sortedPlayers[j];
                    sortedPlayers[j] = tempPlayer;
                }
            }
        }
        
        // Create snapshot
        LeaderboardSnapshot storage snapshot = snapshots[snapshotId];
        snapshot.snapshotId = snapshotId;
        snapshot.gameMode = _gameMode;
        snapshot.timestamp = block.timestamp;
        snapshot.startTime = _startTime;
        snapshot.endTime = _endTime;
        snapshot.period = _period;
        snapshot.exists = true;
        
        // Add top N entries
        for (uint256 i = 0; i < count; i++) {
            string memory playerId = sortedPlayers[i];
            
            snapshot.entries.push(LeaderboardEntry({
                identifier: playerId,
                playerAddress: address(0), // Can be populated if needed
                score: sortedScores[i],
                timestamp: block.timestamp,
                rank: i + 1
            }));
        }
        
        gameModeSnapshots[_gameMode].push(snapshotId);
        totalSnapshots++;
        
        emit LeaderboardSnapshotCreated(
            snapshotId,
            _gameMode,
            _period,
            count,
            block.timestamp
        );
        
        return snapshotId;
    }
    
    // ========== VIEW FUNCTIONS ==========
    
    /**
     * @dev Get player stats
     */
    function getPlayerStats(string memory _identifier)
        external
        view
        returns (
            uint256 bestScoreOneWay,
            uint256 bestScoreTwoWay,
            uint256 bestScoreTimeAttack,
            uint256 bestScoreBomb,
            uint256 totalGamesPlayed,
            uint256 totalScore,
            uint256 lastPlayedTime
        )
    {
        PlayerStats memory stats = playerStats[_identifier];
        return (
            stats.bestScoreOneWay,
            stats.bestScoreTwoWay,
            stats.bestScoreTimeAttack,
            stats.bestScoreBomb,
            stats.totalGamesPlayed,
            stats.totalScore,
            stats.lastPlayedTime
        );
    }
    
    /**
     * @dev Get player's best score for a game mode
     */
    function getPlayerBestScore(string memory _identifier, GameMode _gameMode)
        external
        view
        returns (uint256)
    {
        return bestScores[_gameMode][_identifier];
    }
    
    /**
     * @dev Get player's submission IDs
     */
    function getPlayerSubmissions(string memory _identifier)
        external
        view
        returns (uint256[] memory)
    {
        return playerSubmissionIds[_identifier];
    }
    
    /**
     * @dev Get submission details
     */
    function getSubmission(uint256 _submissionId)
        external
        view
        returns (
            address playerAddress,
            string memory identifier,
            GameMode gameMode,
            uint256 score,
            uint256 distance,
            uint256 currency,
            uint256 playTime,
            uint256 timestamp,
            bool verified
        )
    {
        require(_submissionId < totalSubmissions, "Submission does not exist");
        ScoreSubmission memory s = submissions[_submissionId];
        return (
            s.playerAddress,
            s.identifier,
            s.gameMode,
            s.score,
            s.distance,
            s.currency,
            s.playTime,
            s.timestamp,
            s.verified
        );
    }
    
    /**
     * @dev Get leaderboard for a game mode (top N)
     */
    function getLeaderboard(GameMode _gameMode, uint256 _topN)
        external
        view
        returns (
            string[] memory identifiers,
            uint256[] memory scores,
            uint256[] memory ranks
        )
    {
        string[] memory players = leaderboardPlayers[_gameMode];
        uint256 count = players.length < _topN ? players.length : _topN;
        
        // Create arrays for sorting
        string[] memory sortedPlayers = new string[](players.length);
        uint256[] memory sortedScores = new uint256[](players.length);
        
        for (uint256 i = 0; i < players.length; i++) {
            sortedPlayers[i] = players[i];
            sortedScores[i] = bestScores[_gameMode][players[i]];
        }
        
        // Bubble sort (descending)
        for (uint256 i = 0; i < sortedPlayers.length; i++) {
            for (uint256 j = i + 1; j < sortedPlayers.length; j++) {
                if (sortedScores[j] > sortedScores[i]) {
                    uint256 tempScore = sortedScores[i];
                    sortedScores[i] = sortedScores[j];
                    sortedScores[j] = tempScore;
                    
                    string memory tempPlayer = sortedPlayers[i];
                    sortedPlayers[i] = sortedPlayers[j];
                    sortedPlayers[j] = tempPlayer;
                }
            }
        }
        
        // Return top N
        identifiers = new string[](count);
        scores = new uint256[](count);
        ranks = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            identifiers[i] = sortedPlayers[i];
            scores[i] = sortedScores[i];
            ranks[i] = i + 1;
        }
        
        return (identifiers, scores, ranks);
    }
    
    /**
     * @dev Get snapshot details
     */
    function getSnapshot(uint256 _snapshotId)
        external
        view
        returns (
            GameMode gameMode,
            uint256 timestamp,
            uint256 startTime,
            uint256 endTime,
            string memory period,
            uint256 entryCount
        )
    {
        require(_snapshotId < totalSnapshots, "Snapshot does not exist");
        LeaderboardSnapshot storage snapshot = snapshots[_snapshotId];
        return (
            snapshot.gameMode,
            snapshot.timestamp,
            snapshot.startTime,
            snapshot.endTime,
            snapshot.period,
            snapshot.entries.length
        );
    }
    
    /**
     * @dev Get snapshot entries
     */
    function getSnapshotEntries(uint256 _snapshotId)
        external
        view
        returns (
            string[] memory identifiers,
            uint256[] memory scores,
            uint256[] memory ranks
        )
    {
        require(_snapshotId < totalSnapshots, "Snapshot does not exist");
        LeaderboardSnapshot storage snapshot = snapshots[_snapshotId];
        
        uint256 count = snapshot.entries.length;
        identifiers = new string[](count);
        scores = new uint256[](count);
        ranks = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            identifiers[i] = snapshot.entries[i].identifier;
            scores[i] = snapshot.entries[i].score;
            ranks[i] = snapshot.entries[i].rank;
        }
        
        return (identifiers, scores, ranks);
    }
    
    /**
     * @dev Get all snapshots for a game mode
     */
    function getGameModeSnapshots(GameMode _gameMode)
        external
        view
        returns (uint256[] memory)
    {
        return gameModeSnapshots[_gameMode];
    }
    
    /**
     * @dev Get player rank in a game mode
     */
    function getPlayerRank(string memory _identifier, GameMode _gameMode)
        external
        view
        returns (uint256 rank, uint256 totalPlayers)
    {
        string[] memory players = leaderboardPlayers[_gameMode];
        uint256 playerScore = bestScores[_gameMode][_identifier];
        
        if (playerScore == 0) {
            return (0, players.length);
        }
        
        uint256 betterCount = 0;
        for (uint256 i = 0; i < players.length; i++) {
            if (bestScores[_gameMode][players[i]] > playerScore) {
                betterCount++;
            }
        }
        
        return (betterCount + 1, players.length);
    }
    
    /**
     * @dev Get contract stats
     */
    function getStats()
        external
        view
        returns (
            uint256 _totalSubmissions,
            uint256 _totalPlayers,
            uint256 _totalSnapshots,
            address _owner
        )
    {
        return (totalSubmissions, totalPlayers, totalSnapshots, owner);
    }
    
    /**
     * @dev Check if player exists
     */
    function playerExists(string memory _identifier)
        external
        view
        returns (bool)
    {
        return hasPlayer[_identifier];
    }
    
    // ========== ADMIN FUNCTIONS ==========
    
    /**
     * @dev Update anti-cheat parameters
     */
    function updateAntiCheatParams(
        uint256 _minInterval,
        uint256 _maxScore
    ) external onlyOwner {
        minSubmissionInterval = _minInterval;
        maxScorePerSubmission = _maxScore;
    }
    
    /**
     * @dev Transfer ownership
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }
    
    /**
     * @dev Emergency withdraw
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}