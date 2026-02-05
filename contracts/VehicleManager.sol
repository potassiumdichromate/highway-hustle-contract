// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title VehicleManager
 * @dev Manages vehicle purchases and switches on 0G blockchain for Highway Hustle
 * @notice Records all vehicle-related actions on-chain
 */
contract VehicleManager {
    
    // ========== ENUMS ==========
    enum VehicleType { Jeep, Van, Sierra, Sedan, Lamborghini }
    
    // ========== STRUCTS ==========
    struct VehiclePurchase {
        address playerAddress;
        string identifier;
        VehicleType vehicleType;
        uint256 purchasePrice;
        uint256 timestamp;
        bool exists;
    }
    
    struct VehicleSwitch {
        address playerAddress;
        string identifier;
        VehicleType fromVehicle;
        VehicleType toVehicle;
        uint256 timestamp;
        bool exists;
    }
    
    // ========== STATE VARIABLES ==========
    address public owner;
    uint256 public totalPurchases;
    uint256 public totalSwitches;
    uint256 public totalPlayers;
    
    // Mappings
    mapping(uint256 => VehiclePurchase) public purchases;
    mapping(uint256 => VehicleSwitch) public switches;
    mapping(string => uint256[]) public playerPurchaseIds;
    mapping(string => uint256[]) public playerSwitchIds;
    mapping(string => mapping(VehicleType => bool)) public vehiclesOwned;
    mapping(string => VehicleType) public selectedVehicle;
    mapping(string => bool) public hasPlayer;
    mapping(string => uint256) public playerSwitchCount;
    
    // ========== EVENTS ==========
    event VehiclePurchased(
        uint256 indexed purchaseId,
        string indexed identifier,
        address playerAddress,
        VehicleType vehicleType,
        uint256 price,
        uint256 timestamp
    );
    
    event VehicleSwitched(
        uint256 indexed switchId,
        string indexed identifier,
        address playerAddress,
        VehicleType fromVehicle,
        VehicleType toVehicle,
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
        totalPurchases = 0;
        totalSwitches = 0;
        totalPlayers = 0;
    }
    
    // ========== INTERNAL FUNCTIONS ==========
    
    /**
     * @dev Register new player with default vehicle (Jeep)
     */
    function registerPlayer(string memory _identifier, address _playerAddress) internal {
        if (!hasPlayer[_identifier]) {
            hasPlayer[_identifier] = true;
            totalPlayers++;
            vehiclesOwned[_identifier][VehicleType.Jeep] = true;
            selectedVehicle[_identifier] = VehicleType.Jeep;
            emit NewPlayer(_identifier, block.timestamp);
        }
    }
    
    // ========== MAIN FUNCTIONS ==========
    
    /**
     * @dev Record a vehicle purchase
     * @param _identifier Player identifier (wallet/email/discord/telegram)
     * @param _playerAddress Player's wallet address (0x0 if not available)
     * @param _vehicleType Vehicle type (0=Jeep, 1=Van, 2=Sierra, 3=Sedan, 4=Lamborghini)
     * @param _purchasePrice Price paid in game currency
     */
    function purchaseVehicle(
        string memory _identifier,
        address _playerAddress,
        VehicleType _vehicleType,
        uint256 _purchasePrice
    ) external onlyOwner returns (uint256) {
        require(_vehicleType != VehicleType.Jeep, "Jeep is default, cannot purchase");
        
        // Register player if new
        registerPlayer(_identifier, _playerAddress);
        
        // Record purchase
        uint256 purchaseId = totalPurchases;
        purchases[purchaseId] = VehiclePurchase({
            playerAddress: _playerAddress,
            identifier: _identifier,
            vehicleType: _vehicleType,
            purchasePrice: _purchasePrice,
            timestamp: block.timestamp,
            exists: true
        });
        
        playerPurchaseIds[_identifier].push(purchaseId);
        vehiclesOwned[_identifier][_vehicleType] = true;
        totalPurchases++;
        
        emit VehiclePurchased(
            purchaseId,
            _identifier,
            _playerAddress,
            _vehicleType,
            _purchasePrice,
            block.timestamp
        );
        
        return purchaseId;
    }
    
    /**
     * @dev Switch to a different vehicle
     * @param _identifier Player identifier
     * @param _playerAddress Player's wallet address
     * @param _newVehicle New vehicle type to switch to
     */
    function switchVehicle(
        string memory _identifier,
        address _playerAddress,
        VehicleType _newVehicle
    ) external onlyOwner returns (uint256) {
        // Register player if new
        registerPlayer(_identifier, _playerAddress);
        
        // Check ownership
        require(vehiclesOwned[_identifier][_newVehicle], "Vehicle not owned");
        
        VehicleType currentVehicle = selectedVehicle[_identifier];
        require(currentVehicle != _newVehicle, "Already using this vehicle");
        
        // Record switch
        uint256 switchId = totalSwitches;
        switches[switchId] = VehicleSwitch({
            playerAddress: _playerAddress,
            identifier: _identifier,
            fromVehicle: currentVehicle,
            toVehicle: _newVehicle,
            timestamp: block.timestamp,
            exists: true
        });
        
        playerSwitchIds[_identifier].push(switchId);
        selectedVehicle[_identifier] = _newVehicle;
        playerSwitchCount[_identifier]++;
        totalSwitches++;
        
        emit VehicleSwitched(
            switchId,
            _identifier,
            _playerAddress,
            currentVehicle,
            _newVehicle,
            block.timestamp
        );
        
        return switchId;
    }
    
    // ========== VIEW FUNCTIONS ==========
    
    /**
     * @dev Get all vehicles owned by a player
     * @return Array of 5 booleans [Jeep, Van, Sierra, Sedan, Lamborghini]
     */
    function getPlayerVehicles(string memory _identifier) 
        external 
        view 
        returns (bool[5] memory) 
    {
        return [
            vehiclesOwned[_identifier][VehicleType.Jeep],
            vehiclesOwned[_identifier][VehicleType.Van],
            vehiclesOwned[_identifier][VehicleType.Sierra],
            vehiclesOwned[_identifier][VehicleType.Sedan],
            vehiclesOwned[_identifier][VehicleType.Lamborghini]
        ];
    }
    
    /**
     * @dev Get player's selected vehicle
     */
    function getSelectedVehicle(string memory _identifier) 
        external 
        view 
        returns (VehicleType) 
    {
        return selectedVehicle[_identifier];
    }
    
    /**
     * @dev Get all purchase IDs for a player
     */
    function getPlayerPurchaseIds(string memory _identifier)
        external
        view
        returns (uint256[] memory)
    {
        return playerPurchaseIds[_identifier];
    }
    
    /**
     * @dev Get all switch IDs for a player
     */
    function getPlayerSwitchIds(string memory _identifier)
        external
        view
        returns (uint256[] memory)
    {
        return playerSwitchIds[_identifier];
    }
    
    /**
     * @dev Get purchase details
     */
    function getPurchase(uint256 _purchaseId)
        external
        view
        returns (
            address playerAddress,
            string memory identifier,
            VehicleType vehicleType,
            uint256 purchasePrice,
            uint256 timestamp
        )
    {
        require(_purchaseId < totalPurchases, "Purchase does not exist");
        VehiclePurchase memory p = purchases[_purchaseId];
        return (p.playerAddress, p.identifier, p.vehicleType, p.purchasePrice, p.timestamp);
    }
    
    /**
     * @dev Get switch details
     */
    function getSwitch(uint256 _switchId)
        external
        view
        returns (
            address playerAddress,
            string memory identifier,
            VehicleType fromVehicle,
            VehicleType toVehicle,
            uint256 timestamp
        )
    {
        require(_switchId < totalSwitches, "Switch does not exist");
        VehicleSwitch memory s = switches[_switchId];
        return (s.playerAddress, s.identifier, s.fromVehicle, s.toVehicle, s.timestamp);
    }
    
    /**
     * @dev Get player's total switch count
     */
    function getPlayerSwitchCount(string memory _identifier)
        external
        view
        returns (uint256)
    {
        return playerSwitchCount[_identifier];
    }
    
    /**
     * @dev Get player's total purchase count
     */
    function getPlayerPurchaseCount(string memory _identifier)
        external
        view
        returns (uint256)
    {
        return playerPurchaseIds[_identifier].length;
    }
    
    /**
     * @dev Get contract stats
     */
    function getStats()
        external
        view
        returns (
            uint256 _totalPurchases,
            uint256 _totalSwitches,
            uint256 _totalPlayers,
            address _owner
        )
    {
        return (totalPurchases, totalSwitches, totalPlayers, owner);
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