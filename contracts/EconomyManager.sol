// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EconomyManager
 * @dev Tracks currency, transactions, and rewards on 0G blockchain for Highway Hustle
 * @notice Records all economic activities including earnings, spending, and rewards
 */
contract EconomyManager {
    
    // ========== ENUMS ==========
    enum TransactionType {
        GameEarning,        // 0 - Earned from gameplay
        VehiclePurchase,    // 1 - Spent on vehicle
        MissionReward,      // 2 - Mission completion reward
        AchievementReward,  // 3 - Achievement unlock reward
        DailyReward,        // 4 - Daily login reward
        WeeklyReward,       // 5 - Weekly reward
        ReferralBonus,      // 6 - Referral bonus
        AdminGrant,         // 7 - Admin granted currency
        Other               // 8 - Other transactions
    }
    
    // ========== STRUCTS ==========
    struct Transaction {
        address playerAddress;
        string identifier;
        TransactionType transactionType;
        int256 amount; // positive = earned, negative = spent
        uint256 balanceAfter;
        string description;
        uint256 timestamp;
        bool exists;
    }
    
    struct PlayerEconomy {
        uint256 totalEarned;
        uint256 totalSpent;
        uint256 currentBalance;
        uint256 lastWeekBalance;
        uint256 lifetimeBalance;
        uint256 transactionCount;
        uint256 lastTransactionTime;
        bool exists;
    }
    
    struct RewardClaim {
        address playerAddress;
        string identifier;
        string rewardId;
        uint256 amount;
        uint256 timestamp;
        bool exists;
    }
    
    struct DailyStreak {
        uint256 currentStreak;
        uint256 longestStreak;
        uint256 lastClaimDate; // day number since epoch
        uint256 totalClaims;
    }
    
    // ========== STATE VARIABLES ==========
    address public owner;
    uint256 public totalTransactions;
    uint256 public totalRewardsClaimed;
    uint256 public totalPlayers;
    uint256 public totalCurrencyCirculation;
    
    // Economy tracking
    mapping(uint256 => Transaction) public transactions;
    mapping(string => PlayerEconomy) public playerEconomy;
    mapping(string => uint256[]) public playerTransactionIds;
    mapping(string => bool) public hasPlayer;
    
    // Rewards
    mapping(uint256 => RewardClaim) public rewardClaims;
    mapping(string => uint256[]) public playerRewardIds;
    mapping(string => mapping(string => bool)) public hasClaimedReward;
    mapping(string => DailyStreak) public dailyStreaks;
    
    // Daily reward configuration
    uint256 public baseRewardAmount = 1000;
    uint256 public streakBonusMultiplier = 100; // +100 per day streak
    uint256 public maxStreakBonus = 5000;
    
    // Transaction limits (anti-cheat)
    uint256 public maxTransactionAmount = 1000000;
    uint256 public minTransactionInterval = 5; // 5 seconds
    
    // ========== EVENTS ==========
    event TransactionRecorded(
        uint256 indexed transactionId,
        string indexed identifier,
        address playerAddress,
        TransactionType transactionType,
        int256 amount,
        uint256 balanceAfter,
        uint256 timestamp
    );
    
    event RewardClaimed(
        uint256 indexed rewardId,
        string indexed identifier,
        address playerAddress,
        string rewardType,
        uint256 amount,
        uint256 timestamp
    );
    
    event DailyRewardClaimed(
        string indexed identifier,
        uint256 amount,
        uint256 streak,
        uint256 timestamp
    );
    
    event BalanceUpdated(
        string indexed identifier,
        uint256 oldBalance,
        uint256 newBalance,
        uint256 timestamp
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
        totalTransactions = 0;
        totalRewardsClaimed = 0;
        totalPlayers = 0;
        totalCurrencyCirculation = 0;
    }
    
    // ========== INTERNAL FUNCTIONS ==========
    
    function registerPlayer(string memory _identifier, uint256 _initialBalance) internal {
        if (!hasPlayer[_identifier]) {
            hasPlayer[_identifier] = true;
            totalPlayers++;
            
            playerEconomy[_identifier] = PlayerEconomy({
                totalEarned: _initialBalance,
                totalSpent: 0,
                currentBalance: _initialBalance,
                lastWeekBalance: 0,
                lifetimeBalance: _initialBalance,
                transactionCount: 0,
                lastTransactionTime: 0,
                exists: true
            });
            
            dailyStreaks[_identifier] = DailyStreak({
                currentStreak: 0,
                longestStreak: 0,
                lastClaimDate: 0,
                totalClaims: 0
            });
            
            totalCurrencyCirculation += _initialBalance;
            
            emit NewPlayer(_identifier, block.timestamp);
        }
    }
    
    function getCurrentDay() internal view returns (uint256) {
        return block.timestamp / 1 days;
    }
    
    // ========== MAIN FUNCTIONS ==========
    
    /**
     * @dev Record a transaction
     */
    function recordTransaction(
        string memory _identifier,
        address _playerAddress,
        TransactionType _transactionType,
        int256 _amount,
        string memory _description
    ) external onlyOwner returns (uint256) {
        require(_amount != 0, "Amount cannot be zero");
        require(
            uint256(_amount > 0 ? _amount : -_amount) <= maxTransactionAmount,
            "Amount exceeds maximum"
        );
        
        // Initialize player if new with default balance
        if (!hasPlayer[_identifier]) {
            registerPlayer(_identifier, 20000); // Default starting balance
        }
        
        PlayerEconomy storage economy = playerEconomy[_identifier];
        
        // Check transaction interval (only for spending)
        if (_amount < 0) {
            require(
                block.timestamp >= economy.lastTransactionTime + minTransactionInterval,
                "Transaction too frequent"
            );
        }
        
        // Update balance
        uint256 oldBalance = economy.currentBalance;
        
        if (_amount > 0) {
            // Earning
            economy.currentBalance += uint256(_amount);
            economy.totalEarned += uint256(_amount);
            economy.lifetimeBalance += uint256(_amount);
            totalCurrencyCirculation += uint256(_amount);
        } else {
            // Spending
            uint256 spendAmount = uint256(-_amount);
            require(economy.currentBalance >= spendAmount, "Insufficient balance");
            economy.currentBalance -= spendAmount;
            economy.totalSpent += spendAmount;
        }
        
        uint256 newBalance = economy.currentBalance;
        
        // Record transaction
        uint256 transactionId = totalTransactions;
        transactions[transactionId] = Transaction({
            playerAddress: _playerAddress,
            identifier: _identifier,
            transactionType: _transactionType,
            amount: _amount,
            balanceAfter: newBalance,
            description: _description,
            timestamp: block.timestamp,
            exists: true
        });
        
        playerTransactionIds[_identifier].push(transactionId);
        economy.transactionCount++;
        economy.lastTransactionTime = block.timestamp;
        totalTransactions++;
        
        emit TransactionRecorded(
            transactionId,
            _identifier,
            _playerAddress,
            _transactionType,
            _amount,
            newBalance,
            block.timestamp
        );
        
        emit BalanceUpdated(_identifier, oldBalance, newBalance, block.timestamp);
        
        return transactionId;
    }
    
    /**
     * @dev Batch record transactions
     */
    function batchRecordTransactions(
        string memory _identifier,
        address _playerAddress,
        TransactionType[] memory _types,
        int256[] memory _amounts,
        string[] memory _descriptions
    ) external onlyOwner returns (uint256[] memory) {
        require(_types.length == _amounts.length, "Array length mismatch");
        require(_amounts.length == _descriptions.length, "Array length mismatch");
        
        if (!hasPlayer[_identifier]) {
            registerPlayer(_identifier, 20000);
        }
        
        uint256[] memory transactionIds = new uint256[](_types.length);
        PlayerEconomy storage economy = playerEconomy[_identifier];
        
        for (uint256 i = 0; i < _types.length; i++) {
            require(_amounts[i] != 0, "Amount cannot be zero");
            
            uint256 oldBalance = economy.currentBalance;
            
            if (_amounts[i] > 0) {
                economy.currentBalance += uint256(_amounts[i]);
                economy.totalEarned += uint256(_amounts[i]);
                economy.lifetimeBalance += uint256(_amounts[i]);
                totalCurrencyCirculation += uint256(_amounts[i]);
            } else {
                uint256 spendAmount = uint256(-_amounts[i]);
                require(economy.currentBalance >= spendAmount, "Insufficient balance");
                economy.currentBalance -= spendAmount;
                economy.totalSpent += spendAmount;
            }
            
            uint256 newBalance = economy.currentBalance;
            
            uint256 transactionId = totalTransactions;
            transactions[transactionId] = Transaction({
                playerAddress: _playerAddress,
                identifier: _identifier,
                transactionType: _types[i],
                amount: _amounts[i],
                balanceAfter: newBalance,
                description: _descriptions[i],
                timestamp: block.timestamp,
                exists: true
            });
            
            playerTransactionIds[_identifier].push(transactionId);
            economy.transactionCount++;
            totalTransactions++;
            transactionIds[i] = transactionId;
            
            emit TransactionRecorded(
                transactionId,
                _identifier,
                _playerAddress,
                _types[i],
                _amounts[i],
                newBalance,
                block.timestamp
            );
            
            emit BalanceUpdated(_identifier, oldBalance, newBalance, block.timestamp);
        }
        
        economy.lastTransactionTime = block.timestamp;
        
        return transactionIds;
    }
    
    /**
     * @dev Claim a specific reward
     */
    function claimReward(
        string memory _identifier,
        address _playerAddress,
        string memory _rewardId,
        uint256 _amount,
        string memory _rewardType
    ) external onlyOwner returns (uint256) {
        require(!hasClaimedReward[_identifier][_rewardId], "Reward already claimed");
        require(_amount > 0, "Reward amount must be positive");
        require(_amount <= maxTransactionAmount, "Reward amount too high");
        
        if (!hasPlayer[_identifier]) {
            registerPlayer(_identifier, 20000);
        }
        
        // Mark as claimed
        hasClaimedReward[_identifier][_rewardId] = true;
        
        // Update balance
        PlayerEconomy storage economy = playerEconomy[_identifier];
        uint256 oldBalance = economy.currentBalance;
        economy.currentBalance += _amount;
        economy.totalEarned += _amount;
        economy.lifetimeBalance += _amount;
        totalCurrencyCirculation += _amount;
        
        // Record reward claim
        uint256 rewardId = totalRewardsClaimed;
        rewardClaims[rewardId] = RewardClaim({
            playerAddress: _playerAddress,
            identifier: _identifier,
            rewardId: _rewardId,
            amount: _amount,
            timestamp: block.timestamp,
            exists: true
        });
        
        playerRewardIds[_identifier].push(rewardId);
        totalRewardsClaimed++;
        
        // Also record as transaction
        uint256 transactionId = totalTransactions;
        transactions[transactionId] = Transaction({
            playerAddress: _playerAddress,
            identifier: _identifier,
            transactionType: TransactionType.MissionReward,
            amount: int256(_amount),
            balanceAfter: economy.currentBalance,
            description: string(abi.encodePacked("Reward: ", _rewardId)),
            timestamp: block.timestamp,
            exists: true
        });
        
        playerTransactionIds[_identifier].push(transactionId);
        economy.transactionCount++;
        totalTransactions++;
        
        emit RewardClaimed(
            rewardId,
            _identifier,
            _playerAddress,
            _rewardType,
            _amount,
            block.timestamp
        );
        
        emit BalanceUpdated(_identifier, oldBalance, economy.currentBalance, block.timestamp);
        
        return rewardId;
    }
    
    /**
     * @dev Claim daily reward with streak bonus
     */
    function claimDailyReward(
        string memory _identifier,
        address _playerAddress
    ) external onlyOwner returns (uint256 rewardAmount, uint256 newStreak) {
        if (!hasPlayer[_identifier]) {
            registerPlayer(_identifier, 20000);
        }
        
        DailyStreak storage streak = dailyStreaks[_identifier];
        uint256 currentDay = getCurrentDay();
        
        require(currentDay > streak.lastClaimDate, "Already claimed today");
        
        // Check if streak continues
        if (currentDay == streak.lastClaimDate + 1) {
            // Consecutive day
            streak.currentStreak++;
        } else {
            // Streak broken
            streak.currentStreak = 1;
        }
        
        // Update longest streak
        if (streak.currentStreak > streak.longestStreak) {
            streak.longestStreak = streak.currentStreak;
        }
        
        // Calculate reward with streak bonus
        uint256 streakBonus = (streak.currentStreak - 1) * streakBonusMultiplier;
        if (streakBonus > maxStreakBonus) {
            streakBonus = maxStreakBonus;
        }
        
        rewardAmount = baseRewardAmount + streakBonus;
        
        // Update economy
        PlayerEconomy storage economy = playerEconomy[_identifier];
        uint256 oldBalance = economy.currentBalance;
        economy.currentBalance += rewardAmount;
        economy.totalEarned += rewardAmount;
        economy.lifetimeBalance += rewardAmount;
        totalCurrencyCirculation += rewardAmount;
        
        // Update streak data
        streak.lastClaimDate = currentDay;
        streak.totalClaims++;
        
        // Record transaction
        uint256 transactionId = totalTransactions;
        transactions[transactionId] = Transaction({
            playerAddress: _playerAddress,
            identifier: _identifier,
            transactionType: TransactionType.DailyReward,
            amount: int256(rewardAmount),
            balanceAfter: economy.currentBalance,
            description: string(abi.encodePacked("Daily reward - Streak: ", uintToString(streak.currentStreak))),
            timestamp: block.timestamp,
            exists: true
        });
        
        playerTransactionIds[_identifier].push(transactionId);
        economy.transactionCount++;
        totalTransactions++;
        
        emit DailyRewardClaimed(
            _identifier,
            rewardAmount,
            streak.currentStreak,
            block.timestamp
        );
        
        emit BalanceUpdated(_identifier, oldBalance, economy.currentBalance, block.timestamp);
        
        return (rewardAmount, streak.currentStreak);
    }
    
    /**
     * @dev Update player balance directly (admin function)
     */
    function updateBalance(
        string memory _identifier,
        address _playerAddress,
        uint256 _newBalance,
        string memory _reason
    ) external onlyOwner {
        if (!hasPlayer[_identifier]) {
            registerPlayer(_identifier, _newBalance);
            return;
        }
        
        PlayerEconomy storage economy = playerEconomy[_identifier];
        uint256 oldBalance = economy.currentBalance;
        
        int256 difference = int256(_newBalance) - int256(oldBalance);
        
        economy.currentBalance = _newBalance;
        
        if (difference > 0) {
            economy.totalEarned += uint256(difference);
            economy.lifetimeBalance += uint256(difference);
            totalCurrencyCirculation += uint256(difference);
        } else if (difference < 0) {
            economy.totalSpent += uint256(-difference);
        }
        
        // Record transaction
        uint256 transactionId = totalTransactions;
        transactions[transactionId] = Transaction({
            playerAddress: _playerAddress,
            identifier: _identifier,
            transactionType: TransactionType.AdminGrant,
            amount: difference,
            balanceAfter: _newBalance,
            description: _reason,
            timestamp: block.timestamp,
            exists: true
        });
        
        playerTransactionIds[_identifier].push(transactionId);
        economy.transactionCount++;
        totalTransactions++;
        
        emit BalanceUpdated(_identifier, oldBalance, _newBalance, block.timestamp);
    }
    
    /**
     * @dev Update last week balance (for weekly tracking)
     */
    function updateLastWeekBalance(string memory _identifier, uint256 _balance) 
        external 
        onlyOwner 
    {
        require(hasPlayer[_identifier], "Player does not exist");
        playerEconomy[_identifier].lastWeekBalance = _balance;
    }
    
    // ========== VIEW FUNCTIONS ==========
    
    /**
     * @dev Get player economy stats
     */
    function getPlayerEconomy(string memory _identifier)
        external
        view
        returns (
            uint256 totalEarned,
            uint256 totalSpent,
            uint256 currentBalance,
            uint256 lastWeekBalance,
            uint256 lifetimeBalance,
            uint256 transactionCount
        )
    {
        PlayerEconomy memory economy = playerEconomy[_identifier];
        return (
            economy.totalEarned,
            economy.totalSpent,
            economy.currentBalance,
            economy.lastWeekBalance,
            economy.lifetimeBalance,
            economy.transactionCount
        );
    }
    
    /**
     * @dev Get player's current balance
     */
    function getBalance(string memory _identifier)
        external
        view
        returns (uint256)
    {
        return playerEconomy[_identifier].currentBalance;
    }
    
    /**
     * @dev Get player's transaction IDs
     */
    function getPlayerTransactions(string memory _identifier)
        external
        view
        returns (uint256[] memory)
    {
        return playerTransactionIds[_identifier];
    }
    
    /**
     * @dev Get transaction details
     */
    function getTransaction(uint256 _transactionId)
        external
        view
        returns (
            address playerAddress,
            string memory identifier,
            TransactionType transactionType,
            int256 amount,
            uint256 balanceAfter,
            string memory description,
            uint256 timestamp
        )
    {
        require(_transactionId < totalTransactions, "Transaction does not exist");
        Transaction memory t = transactions[_transactionId];
        return (
            t.playerAddress,
            t.identifier,
            t.transactionType,
            t.amount,
            t.balanceAfter,
            t.description,
            t.timestamp
        );
    }
    
    /**
     * @dev Get player's reward IDs
     */
    function getPlayerRewards(string memory _identifier)
        external
        view
        returns (uint256[] memory)
    {
        return playerRewardIds[_identifier];
    }
    
    /**
     * @dev Get reward claim details
     */
    function getRewardClaim(uint256 _rewardId)
        external
        view
        returns (
            address playerAddress,
            string memory identifier,
            string memory rewardId,
            uint256 amount,
            uint256 timestamp
        )
    {
        require(_rewardId < totalRewardsClaimed, "Reward does not exist");
        RewardClaim memory r = rewardClaims[_rewardId];
        return (r.playerAddress, r.identifier, r.rewardId, r.amount, r.timestamp);
    }
    
    /**
     * @dev Check if reward has been claimed
     */
    function hasPlayerClaimedReward(string memory _identifier, string memory _rewardId)
        external
        view
        returns (bool)
    {
        return hasClaimedReward[_identifier][_rewardId];
    }
    
    /**
     * @dev Get player's daily streak
     */
    function getDailyStreak(string memory _identifier)
        external
        view
        returns (
            uint256 currentStreak,
            uint256 longestStreak,
            uint256 lastClaimDate,
            uint256 totalClaims,
            bool canClaimToday
        )
    {
        DailyStreak memory streak = dailyStreaks[_identifier];
        uint256 currentDay = getCurrentDay();
        bool canClaim = currentDay > streak.lastClaimDate;
        
        return (
            streak.currentStreak,
            streak.longestStreak,
            streak.lastClaimDate,
            streak.totalClaims,
            canClaim
        );
    }
    
    /**
     * @dev Calculate daily reward amount for player
     */
    function calculateDailyReward(string memory _identifier)
        external
        view
        returns (uint256 rewardAmount, uint256 projectedStreak)
    {
        DailyStreak memory streak = dailyStreaks[_identifier];
        uint256 currentDay = getCurrentDay();
        
        uint256 newStreak;
        if (currentDay == streak.lastClaimDate + 1) {
            newStreak = streak.currentStreak + 1;
        } else {
            newStreak = 1;
        }
        
        uint256 streakBonus = (newStreak - 1) * streakBonusMultiplier;
        if (streakBonus > maxStreakBonus) {
            streakBonus = maxStreakBonus;
        }
        
        return (baseRewardAmount + streakBonus, newStreak);
    }
    
    /**
     * @dev Get contract stats
     */
    function getStats()
        external
        view
        returns (
            uint256 _totalTransactions,
            uint256 _totalRewardsClaimed,
            uint256 _totalPlayers,
            uint256 _totalCurrencyCirculation,
            address _owner
        )
    {
        return (
            totalTransactions,
            totalRewardsClaimed,
            totalPlayers,
            totalCurrencyCirculation,
            owner
        );
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
     * @dev Update reward configuration
     */
    function updateRewardConfig(
        uint256 _baseReward,
        uint256 _streakBonus,
        uint256 _maxBonus
    ) external onlyOwner {
        baseRewardAmount = _baseReward;
        streakBonusMultiplier = _streakBonus;
        maxStreakBonus = _maxBonus;
    }
    
    /**
     * @dev Update transaction limits
     */
    function updateTransactionLimits(
        uint256 _maxAmount,
        uint256 _minInterval
    ) external onlyOwner {
        maxTransactionAmount = _maxAmount;
        minTransactionInterval = _minInterval;
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
    
    // ========== HELPER FUNCTIONS ==========
    
    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}