// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MissionManager
 * @dev Tracks missions and achievements on 0G blockchain for Highway Hustle
 * @notice Records mission completions and achievement unlocks on-chain
 */
contract MissionManager {
    
    // ========== ENUMS ==========
    enum MissionType { 
        Distance,           // 0 - Reach X distance
        Score,             // 1 - Achieve X score
        Currency,          // 2 - Earn X currency
        TimeAttack,        // 3 - Complete time attack
        ConsecutiveWins,   // 4 - Win X times in a row
        VehicleUnlock,     // 5 - Unlock all vehicles
        GameMode,          // 6 - Play all game modes
        DailyStreak,       // 7 - Play X days in a row
        Custom             // 8 - Custom mission
    }
    
    enum MissionStatus {
        NotStarted,
        InProgress,
        Completed,
        Claimed
    }
    
    // ========== STRUCTS ==========
    struct Mission {
        string missionId;
        string name;
        string description;
        MissionType missionType;
        uint256 targetValue;
        uint256 rewardAmount;
        uint256 createdAt;
        bool isActive;
        bool exists;
    }
    
    struct MissionCompletion {
        address playerAddress;
        string identifier;
        string missionId;
        uint256 completedValue;
        uint256 rewardClaimed;
        uint256 timestamp;
        bool exists;
    }
    
    struct Achievement {
        string achievementId;
        string name;
        string description;
        uint256 unlockTimestamp;
        bool exists;
    }
    
    // ========== STATE VARIABLES ==========
    address public owner;
    uint256 public totalMissions;
    uint256 public totalCompletions;
    uint256 public totalAchievements;
    uint256 public totalPlayers;
    
    // Mappings
    mapping(string => Mission) public missions;
    mapping(uint256 => MissionCompletion) public completions;
    mapping(string => Achievement) public achievements;
    
    // Player tracking
    mapping(string => bool) public hasPlayer;
    mapping(string => string[]) public playerMissions;
    mapping(string => mapping(string => MissionStatus)) public playerMissionStatus;
    mapping(string => mapping(string => uint256)) public playerMissionProgress;
    mapping(string => uint256[]) public playerCompletionIds;
    mapping(string => string[]) public playerAchievements;
    mapping(string => mapping(string => bool)) public hasAchievement;
    
    // Mission and achievement lists
    string[] public missionIds;
    string[] public achievementIds;
    
    // ========== EVENTS ==========
    event MissionCreated(
        string indexed missionId,
        string name,
        MissionType missionType,
        uint256 targetValue,
        uint256 rewardAmount,
        uint256 timestamp
    );
    
    event MissionCompleted(
        uint256 indexed completionId,
        string indexed identifier,
        string missionId,
        address playerAddress,
        uint256 completedValue,
        uint256 rewardClaimed,
        uint256 timestamp
    );
    
    event AchievementUnlocked(
        string indexed achievementId,
        string indexed identifier,
        address playerAddress,
        uint256 timestamp
    );
    
    event MissionProgressUpdated(
        string indexed identifier,
        string indexed missionId,
        uint256 currentProgress,
        uint256 targetValue
    );
    
    event NewPlayer(
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
        totalMissions = 0;
        totalCompletions = 0;
        totalAchievements = 0;
        totalPlayers = 0;
        
        // Initialize default achievements
        _createDefaultAchievements();
    }
    
    // ========== INTERNAL FUNCTIONS ==========
    
    function _createDefaultAchievements() internal {
        _createAchievement("ACHIEVED_1000M", "Road Warrior", "Travel 1000 meters in one run");
        _createAchievement("ACHIEVED_5000M", "Highway Legend", "Travel 5000 meters in one run");
        _createAchievement("FIRST_WIN", "First Victory", "Win your first game");
        _createAchievement("SPEED_DEMON", "Speed Demon", "Reach maximum speed");
        _createAchievement("COLLECTOR", "Vehicle Collector", "Unlock all vehicles");
        _createAchievement("RICH_RACER", "Rich Racer", "Accumulate 100,000 currency");
        _createAchievement("VETERAN", "Veteran Player", "Play for 10 hours");
        _createAchievement("PERFECT_RUN", "Perfect Run", "Complete a run without damage");
    }
    
    function _createAchievement(
        string memory _achievementId,
        string memory _name,
        string memory _description
    ) internal {
        achievements[_achievementId] = Achievement({
            achievementId: _achievementId,
            name: _name,
            description: _description,
            unlockTimestamp: 0,
            exists: true
        });
        achievementIds.push(_achievementId);
        totalAchievements++;
    }
    
    function registerPlayer(string memory _identifier) internal {
        if (!hasPlayer[_identifier]) {
            hasPlayer[_identifier] = true;
            totalPlayers++;
            emit NewPlayer(_identifier, block.timestamp);
        }
    }
    
    // ========== MISSION MANAGEMENT ==========
    
    /**
     * @dev Create a new mission
     */
    function createMission(
        string memory _missionId,
        string memory _name,
        string memory _description,
        MissionType _missionType,
        uint256 _targetValue,
        uint256 _rewardAmount
    ) external onlyOwner returns (bool) {
        require(!missions[_missionId].exists, "Mission already exists");
        
        missions[_missionId] = Mission({
            missionId: _missionId,
            name: _name,
            description: _description,
            missionType: _missionType,
            targetValue: _targetValue,
            rewardAmount: _rewardAmount,
            createdAt: block.timestamp,
            isActive: true,
            exists: true
        });
        
        missionIds.push(_missionId);
        totalMissions++;
        
        emit MissionCreated(
            _missionId,
            _name,
            _missionType,
            _targetValue,
            _rewardAmount,
            block.timestamp
        );
        
        return true;
    }
    
    /**
     * @dev Update mission progress
     */
    function updateMissionProgress(
        string memory _identifier,
        address _playerAddress,
        string memory _missionId,
        uint256 _currentProgress
    ) external onlyOwner returns (bool) {
        require(missions[_missionId].exists, "Mission does not exist");
        require(missions[_missionId].isActive, "Mission is not active");
        
        registerPlayer(_identifier);
        
        // Update progress
        playerMissionProgress[_identifier][_missionId] = _currentProgress;
        
        // Check if not already completed
        if (playerMissionStatus[_identifier][_missionId] != MissionStatus.Completed &&
            playerMissionStatus[_identifier][_missionId] != MissionStatus.Claimed) {
            
            if (playerMissionStatus[_identifier][_missionId] == MissionStatus.NotStarted) {
                playerMissions[_identifier].push(_missionId);
                playerMissionStatus[_identifier][_missionId] = MissionStatus.InProgress;
            }
            
            emit MissionProgressUpdated(
                _identifier,
                _missionId,
                _currentProgress,
                missions[_missionId].targetValue
            );
        }
        
        return true;
    }
    
    /**
     * @dev Complete a mission
     */
    function completeMission(
        string memory _identifier,
        address _playerAddress,
        string memory _missionId,
        uint256 _completedValue
    ) external onlyOwner returns (uint256) {
        require(missions[_missionId].exists, "Mission does not exist");
        require(
            playerMissionStatus[_identifier][_missionId] != MissionStatus.Completed &&
            playerMissionStatus[_identifier][_missionId] != MissionStatus.Claimed,
            "Mission already completed"
        );
        
        registerPlayer(_identifier);
        
        Mission memory mission = missions[_missionId];
        require(_completedValue >= mission.targetValue, "Target not reached");
        
        // Record completion
        uint256 completionId = totalCompletions;
        completions[completionId] = MissionCompletion({
            playerAddress: _playerAddress,
            identifier: _identifier,
            missionId: _missionId,
            completedValue: _completedValue,
            rewardClaimed: mission.rewardAmount,
            timestamp: block.timestamp,
            exists: true
        });
        
        playerCompletionIds[_identifier].push(completionId);
        playerMissionStatus[_identifier][_missionId] = MissionStatus.Completed;
        totalCompletions++;
        
        emit MissionCompleted(
            completionId,
            _identifier,
            _missionId,
            _playerAddress,
            _completedValue,
            mission.rewardAmount,
            block.timestamp
        );
        
        return completionId;
    }
    
    // ========== ACHIEVEMENT MANAGEMENT ==========
    
    /**
     * @dev Unlock an achievement for a player
     */
    function unlockAchievement(
        string memory _identifier,
        address _playerAddress,
        string memory _achievementId
    ) external onlyOwner returns (bool) {
        require(achievements[_achievementId].exists, "Achievement does not exist");
        require(!hasAchievement[_identifier][_achievementId], "Achievement already unlocked");
        
        registerPlayer(_identifier);
        
        hasAchievement[_identifier][_achievementId] = true;
        playerAchievements[_identifier].push(_achievementId);
        
        emit AchievementUnlocked(
            _achievementId,
            _identifier,
            _playerAddress,
            block.timestamp
        );
        
        return true;
    }
    
    /**
     * @dev Batch unlock achievements
     */
    function batchUnlockAchievements(
        string memory _identifier,
        address _playerAddress,
        string[] memory _achievementIds
    ) external onlyOwner returns (bool) {
        registerPlayer(_identifier);
        
        for (uint256 i = 0; i < _achievementIds.length; i++) {
            string memory achievementId = _achievementIds[i];
            
            if (achievements[achievementId].exists && 
                !hasAchievement[_identifier][achievementId]) {
                
                hasAchievement[_identifier][achievementId] = true;
                playerAchievements[_identifier].push(achievementId);
                
                emit AchievementUnlocked(
                    achievementId,
                    _identifier,
                    _playerAddress,
                    block.timestamp
                );
            }
        }
        
        return true;
    }
    
    // ========== VIEW FUNCTIONS ==========
    
    /**
     * @dev Get mission details
     */
    function getMission(string memory _missionId)
        external
        view
        returns (
            string memory name,
            string memory description,
            MissionType missionType,
            uint256 targetValue,
            uint256 rewardAmount,
            bool isActive
        )
    {
        require(missions[_missionId].exists, "Mission does not exist");
        Mission memory m = missions[_missionId];
        return (m.name, m.description, m.missionType, m.targetValue, m.rewardAmount, m.isActive);
    }
    
    /**
     * @dev Get all mission IDs
     */
    function getAllMissionIds() external view returns (string[] memory) {
        return missionIds;
    }
    
    /**
     * @dev Get player's missions
     */
    function getPlayerMissions(string memory _identifier)
        external
        view
        returns (string[] memory)
    {
        return playerMissions[_identifier];
    }
    
    /**
     * @dev Get mission status for player
     */
    function getPlayerMissionStatus(string memory _identifier, string memory _missionId)
        external
        view
        returns (MissionStatus)
    {
        return playerMissionStatus[_identifier][_missionId];
    }
    
    /**
     * @dev Get mission progress for player
     */
    function getPlayerMissionProgress(string memory _identifier, string memory _missionId)
        external
        view
        returns (uint256)
    {
        return playerMissionProgress[_identifier][_missionId];
    }
    
    /**
     * @dev Get player's completion IDs
     */
    function getPlayerCompletions(string memory _identifier)
        external
        view
        returns (uint256[] memory)
    {
        return playerCompletionIds[_identifier];
    }
    
    /**
     * @dev Get completion details
     */
    function getCompletion(uint256 _completionId)
        external
        view
        returns (
            address playerAddress,
            string memory identifier,
            string memory missionId,
            uint256 completedValue,
            uint256 rewardClaimed,
            uint256 timestamp
        )
    {
        require(_completionId < totalCompletions, "Completion does not exist");
        MissionCompletion memory c = completions[_completionId];
        return (c.playerAddress, c.identifier, c.missionId, c.completedValue, c.rewardClaimed, c.timestamp);
    }
    
    /**
     * @dev Get achievement details
     */
    function getAchievement(string memory _achievementId)
        external
        view
        returns (
            string memory name,
            string memory description,
            uint256 unlockTimestamp
        )
    {
        require(achievements[_achievementId].exists, "Achievement does not exist");
        Achievement memory a = achievements[_achievementId];
        return (a.name, a.description, a.unlockTimestamp);
    }
    
    /**
     * @dev Get all achievement IDs
     */
    function getAllAchievementIds() external view returns (string[] memory) {
        return achievementIds;
    }
    
    /**
     * @dev Get player's achievements
     */
    function getPlayerAchievements(string memory _identifier)
        external
        view
        returns (string[] memory)
    {
        return playerAchievements[_identifier];
    }
    
    /**
     * @dev Check if player has achievement
     */
    function playerHasAchievement(string memory _identifier, string memory _achievementId)
        external
        view
        returns (bool)
    {
        return hasAchievement[_identifier][_achievementId];
    }
    
    /**
     * @dev Get player's achievement count
     */
    function getPlayerAchievementCount(string memory _identifier)
        external
        view
        returns (uint256)
    {
        return playerAchievements[_identifier].length;
    }
    
    /**
     * @dev Get player's completed mission count
     */
    function getPlayerCompletedMissionCount(string memory _identifier)
        external
        view
        returns (uint256)
    {
        return playerCompletionIds[_identifier].length;
    }
    
    /**
     * @dev Get contract stats
     */
    function getStats()
        external
        view
        returns (
            uint256 _totalMissions,
            uint256 _totalCompletions,
            uint256 _totalAchievements,
            uint256 _totalPlayers,
            address _owner
        )
    {
        return (totalMissions, totalCompletions, totalAchievements, totalPlayers, owner);
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
     * @dev Toggle mission active status
     */
    function toggleMissionStatus(string memory _missionId) external onlyOwner {
        require(missions[_missionId].exists, "Mission does not exist");
        missions[_missionId].isActive = !missions[_missionId].isActive;
    }
    
    /**
     * @dev Add new achievement (after deployment)
     */
    function addAchievement(
        string memory _achievementId,
        string memory _name,
        string memory _description
    ) external onlyOwner returns (bool) {
        require(!achievements[_achievementId].exists, "Achievement already exists");
        _createAchievement(_achievementId, _name, _description);
        return true;
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