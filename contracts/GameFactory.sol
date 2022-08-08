// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "./IERC20.sol";

import "./SafeMath.sol";
import "./Address.sol";
import "./Strings.sol";
import "./Ownable.sol";
import "./AccessControlEnumerable.sol";

import "./console.sol";

contract GameFactory is Ownable, AccessControlEnumerable {
    using SafeMath for uint256;
    using Address for address;

    address public paymentTokenAddress; //payment token (Hifi token)

    // Initial Data for gaming factory
    uint256 public _baseStakeAmountForPlay;
    uint256 public _baseStakeAmountForEarn;
    uint256 public _burnFee;

    uint256 public _withdrawFeeForPlay;
    uint256 public _withdrawFeeForEarn;

    uint256 public _baseUnitForWithdrawFee;
    uint256 public _thawingLockingPeriod;
    uint256 public _withdrawLockingPeriod;
    uint256 public _maximumAmountForBoostItem;
    uint256 public _addRewardCandidatePeriod;

    bool public isBurnable;
    uint256 public _goldItemPrice;
    uint256 public _silverItemPrice;
    uint256 public _bronzeItemPrice;
    uint256 public _lastAddCandidateOperationTime;
    // flag controlling whETHer whitelist is enabled.
    bool private whitelistEnabled;

    struct RewardCandidate {
        uint256 approvedAmount;
        uint256 lastRewardedTime;
        bool status;
    }

    struct ThawingCandidate {
        uint256 approvedAmount;
        uint256 startTime;
        uint256 endTime;
        bool status;
    }

    struct GameStatistic {
        uint256 totalApproved;
        uint256 totalRewarded;
        uint256 totalStakedForPlay;
        uint256 totalStakedForEarn;
        uint256 totalStakedForBoost;
        uint256 totalCommission;
        uint256 totalCommissionWithdrawn;
        uint256 totalWithdrawn;
        uint256 totalBurned;
    }

    mapping(uint256 => uint256) public price;
    mapping(uint256 => bool) public listedMap;
    mapping(address => bool) private whitelistMap;

    event AddToWhitelist(address indexed _newAddress);
    event RemoveFromWhitelist(address indexed _removedAddress);

    event Purchase(
        address indexed previousOwner,
        address indexed newOwner,
        uint256 price,
        uint256 nftID,
        string uri
    );
    event Minted(
        address indexed minter,
        uint256 price,
        uint256 nftID,
        string uri
    );
    event Burned(uint256 nftID);
    event PriceUpdate(
        address indexed owner,
        uint256 oldPrice,
        uint256 newPrice,
        uint256 nftID
    );
    event NftListStatus(address indexed owner, uint256 nftID, bool isListed);
    event TokensDeposited(
        uint256 amount,
        uint256 stakeType,
        address indexed wallet
    );
    event FinneyDeposited(uint256 amount, address indexed wallet);
    event Withdrawn(uint256 amount, address indexed wallet);
    event TokensWithdrawn(uint256 amount, address indexed wallet);
    event RewardCandidatesAdded(uint256 totalCandidates, uint256 totalApproved);
    event PurchasedBoostItem(address indexed userAddress, uint256 itemType);
    event SoldBoostItem(
        address indexed userAddress,
        uint256 itemType,
        uint256 count
    );
    event StakedWithdrawn(
        uint256 amount,
        uint256 stakeType,
        address indexed wallet
    );
    event FreezeReward(address indexed user, uint256 amount, uint256 date);
    event ClaimedUserReward(address indexed user, uint256 amount, uint256 date);
    event UpdatedStatisticData(GameStatistic platformStatistic);
    event ThawingStarted(address indexed user, uint256 amount);
    event ThawingCanceled(address indexed user, uint256 amount);
    event CommissionWithdrawn(address indexed to, uint256 amount);

    GameStatistic platformStatistic;
    uint256 public totalWithdrawnTokenByAdmin;
    uint256 public totalWithdrawnETHByAdmin;
    uint256 public maxUserEarningPerDay;
    mapping(address => RewardCandidate) public rewardCandidates;
    mapping(address => ThawingCandidate) public thawingCandidates;
    mapping(address => uint256) public stakeForPlayLists;
    mapping(address => uint256) public stakeForEarningLists;
    mapping(address => mapping(uint256 => uint256)) public userBoostItemBalance;
    mapping(address => mapping(uint256 => uint256)) public boostItemExpireTime;

    bytes32 public constant CMO_ROLE = keccak256("CMO_ROLE");
    bytes32 public constant CFO_ROLE = keccak256("CFO_ROLE");
    uint256 public BOOST_EXPIRE_TIME;

    constructor(
        address _paymetTokenAddress,
        address _cmoAddress,
        address _cfoAddress
    ) {
        paymentTokenAddress = _paymetTokenAddress;
        _baseStakeAmountForPlay = 100 * 10**18;
        _baseStakeAmountForEarn = 1000 * 10**18;
        _burnFee = 10;

        _thawingLockingPeriod = 6 minutes;
        _withdrawLockingPeriod = 30 days;
        _addRewardCandidatePeriod = 1 days;
        _maximumAmountForBoostItem = 1;
        _goldItemPrice = 10000 * 10**18;
        _silverItemPrice = 5000 * 10**18;
        _bronzeItemPrice = 2000 * 10**18;
        isBurnable = false;
        whitelistEnabled = true;

        _baseUnitForWithdrawFee = 5;

        _withdrawFeeForPlay = 5;
        _withdrawFeeForEarn = 4;

        _whitelist(msg.sender);
        _setupRole(CMO_ROLE, _cmoAddress);
        _setupRole(CFO_ROLE, _cfoAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        BOOST_EXPIRE_TIME = 21 days;
    }

    /**
     * @dev Enable or disable the whitelist
     * @param _enabled bool of whETHer to enable the whitelist.
     */
    function enableWhitelist(bool _enabled) external onlyRole(CMO_ROLE) {
        whitelistEnabled = _enabled;
    }

    /**
     * @dev Adds the provided address to the whitelist
     * @param _newAddress address to be added to the whitelist
     */
    function addToWhitelist(address _newAddress) external onlyRole(CMO_ROLE) {
        _whitelist(_newAddress);
        emit AddToWhitelist(_newAddress);
    }

    /**
     * @dev Removes the provided address to the whitelist
     * @param _removedAddress address to be removed from the whitelist
     */
    function removeFromWhitelist(address _removedAddress)
        external
        onlyRole(CMO_ROLE)
    {
        _unWhitelist(_removedAddress);
        emit RemoveFromWhitelist(_removedAddress);
    }

    /**
     * @dev Returns whETHer the address is whitelisted
     * @param _address address to check
     * @return bool
     */
    function isWhitelisted(address _address) public view returns (bool) {
        if (whitelistEnabled) {
            return whitelistMap[_address];
        } else {
            return true;
        }
    }

    /**
     * @dev Internal function for removing an address from the whitelist
     * @param _removedAddress address to unwhitelisted
     */
    function _unWhitelist(address _removedAddress) internal {
        whitelistMap[_removedAddress] = false;
    }

    /**
     * @dev Internal function for adding the provided address to the whitelist
     * @param _newAddress address to be added to the whitelist
     */
    function _whitelist(address _newAddress) internal {
        whitelistMap[_newAddress] = true;
    }

    /**
     * @dev Get configuration parameters
     * */
    // getBaseStakeAmountForPlay
    function getBaseStakeAmountForPlay() external view returns (uint256) {
        return _baseStakeAmountForPlay;
    }

    // getBaseStakeAmountForEarn
    function getBaseStakeAmountForEarn() external view returns (uint256) {
        return _baseStakeAmountForEarn;
    }

    // getBurnFee
    function getBurnFee() external view returns (uint256) {
        return _burnFee;
    }

    // getWithdrawFee
    function getWithdrawFee() external view returns (uint256) {
        return _baseUnitForWithdrawFee;
    }

    // getThawingLockingPeriod
    function getThawingLockingPeriod() external view returns (uint256) {
        return _thawingLockingPeriod;
    }

    // getWithdrawLockingPeriod
    function getWithdrawLockingPeriod() public view returns (uint256) {
        return _withdrawLockingPeriod;
    }

    // _addRewardCandidatePeriod
    function _getAddRewardCandidatePeriod() external view returns (uint256) {
        return _addRewardCandidatePeriod;
    }

    // getGoldItemPrice
    function getGoldItemPrice() external view returns (uint256) {
        return _goldItemPrice;
    }

    // getSilverItemPrice
    function getSilverItemPrice() external view returns (uint256) {
        return _silverItemPrice;
    }

    // getBronzeItemPrice
    function getBronzeItemPrice() external view returns (uint256) {
        return _bronzeItemPrice;
    }

    // Get user's Reward State
    function getRewardStateByUser()
        external
        view
        returns (RewardCandidate memory candidate)
    {
        return rewardCandidates[msg.sender];
    }

    // Get user's Thawing status
    function getThawingStateByUser()
        external
        view
        returns (ThawingCandidate memory candidate)
    {
        return thawingCandidates[msg.sender];
    }

    // Get Staked amount by user address
    function getStakedAmountByUser(address userAddress)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            stakeForPlayLists[userAddress],
            stakeForEarningLists[userAddress],
            userBoostItemBalance[userAddress][1],
            userBoostItemBalance[userAddress][2],
            userBoostItemBalance[userAddress][3]
        );
    }

    // get Game Statistic Data
    function getStatistic()
        external
        view
        returns (GameStatistic memory statistic)
    {
        return platformStatistic;
    }

    /**
     * @dev reset thawing
     */
    function _resetThawing() private {
        thawingCandidates[msg.sender].approvedAmount = 0;
        thawingCandidates[msg.sender].startTime = 0;
        thawingCandidates[msg.sender].endTime = 0;
        thawingCandidates[msg.sender].status = false;
    }

    /**
     * @dev Unfreeze Rewarded token to claim. Start Thawing
     */
    function unfreeze() external {
        require(
            isWhitelisted(msg.sender),
            "You are not allowed to claim Reward"
        );
        require(
            rewardCandidates[msg.sender].approvedAmount > 0,
            "Insufficient approved amount"
        );

        // Move token from rewardCandidates to thawingCandidates
        thawingCandidates[msg.sender].approvedAmount = thawingCandidates[
            msg.sender
        ].approvedAmount.add(rewardCandidates[msg.sender].approvedAmount);
        // start / restart thawing
        thawingCandidates[msg.sender].startTime = block.timestamp;
        thawingCandidates[msg.sender].endTime = block.timestamp.add(
            _thawingLockingPeriod
        );
        thawingCandidates[msg.sender].status = true;

        emit ThawingStarted(
            msg.sender,
            rewardCandidates[msg.sender].approvedAmount
        );

        // remove token from rewardCandidates
        rewardCandidates[msg.sender].approvedAmount = 0;
    }

    /**
     * @dev cancel thawing action
     */
    function cancel() external {
        require(
            thawingCandidates[msg.sender].approvedAmount > 0,
            "Insufficient approved amount"
        );
        // remove token from rewardCandidates
        rewardCandidates[msg.sender].approvedAmount = rewardCandidates[
            msg.sender
        ].approvedAmount.add(thawingCandidates[msg.sender].approvedAmount);
        // reset Thawing
        _resetThawing();

        emit ThawingCanceled(
            msg.sender,
            rewardCandidates[msg.sender].approvedAmount
        );
    }

    /**
     * @dev withdraw rewarded token to user address
     */
    function claimReward() external returns (bool) {
        require(
            isWhitelisted(msg.sender),
            "You are not allowed to claim Reward"
        );

        require(
            block.timestamp >= thawingCandidates[msg.sender].endTime,
            "The reward is still locked"
        );
        require(
            thawingCandidates[msg.sender].approvedAmount > 0,
            "unsufficient balance to withdraw"
        );

        uint256 contractTokenBalance = IERC20(paymentTokenAddress).balanceOf(
            address(this)
        );
        require(
            contractTokenBalance >=
                thawingCandidates[msg.sender].approvedAmount,
            "unsufficient funds"
        );

        uint256 commissionFee = thawingCandidates[msg.sender]
            .approvedAmount
            .mul(_baseUnitForWithdrawFee)
            .div(100);
        require(
            IERC20(paymentTokenAddress).transfer(
                msg.sender,
                thawingCandidates[msg.sender].approvedAmount.sub(commissionFee)
            )
        );

        // record statistic data
        platformStatistic.totalRewarded = platformStatistic.totalRewarded.add(
            thawingCandidates[msg.sender].approvedAmount
        );
        platformStatistic.totalCommission = platformStatistic
            .totalCommission
            .add(commissionFee);

        emit ClaimedUserReward(
            msg.sender,
            thawingCandidates[msg.sender].approvedAmount.sub(commissionFee),
            block.timestamp
        );
        emit UpdatedStatisticData(platformStatistic);

        // reset thawing
        _resetThawing();

        return true;
    }

    /**
     * @dev Reinvest rewarded token to Stake For Earn
     */
    function freeze() external returns (bool) {
        require(
            isWhitelisted(msg.sender),
            "You are not allowed to claim Reward"
        );
        require(
            block.timestamp >= thawingCandidates[msg.sender].endTime,
            "The reward is still locked"
        );
        require(
            thawingCandidates[msg.sender].approvedAmount > 0,
            "unsufficient balance to withdraw"
        );
        platformStatistic.totalStakedForEarn = platformStatistic
            .totalStakedForEarn
            .add(thawingCandidates[msg.sender].approvedAmount);
        stakeForEarningLists[msg.sender] = stakeForEarningLists[msg.sender].add(
            thawingCandidates[msg.sender].approvedAmount
        );

        emit FreezeReward(
            msg.sender,
            rewardCandidates[msg.sender].approvedAmount,
            block.timestamp
        );
        emit UpdatedStatisticData(platformStatistic);
        // reset thawing
        _resetThawing();

        return true;
    }

    /**
     * @dev Deposite token from staked balance by User
     * @param stakeType, staked Type: 1 : StakedForPlay, 2 : StakedForEarning
     * @param amount amount to deposit
     */
    function stakeTokens(uint256 stakeType, uint256 amount) external {
        require(isWhitelisted(msg.sender), "You are not allowed to stake");
        if (stakeType == 1) {
            require(
                amount >= _baseStakeAmountForPlay,
                "Insufficient amount for playing game"
            );
            require(
                IERC20(paymentTokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    amount
                )
            );
            stakeForPlayLists[msg.sender] = stakeForPlayLists[msg.sender].add(
                amount
            );
            platformStatistic.totalStakedForPlay = platformStatistic
                .totalStakedForPlay
                .add(amount);
            emit TokensDeposited(amount, stakeType, msg.sender);
        }
        if (stakeType == 2) {
            require(
                amount >= _baseStakeAmountForEarn,
                "Insufficient amount for earming"
            );
            require(
                IERC20(paymentTokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    amount
                )
            );
            stakeForEarningLists[msg.sender] = stakeForEarningLists[msg.sender]
                .add(amount);
            platformStatistic.totalStakedForEarn = platformStatistic
                .totalStakedForEarn
                .add(amount);
            emit TokensDeposited(amount, stakeType, msg.sender);
        }
        emit UpdatedStatisticData(platformStatistic);
    }

    /**
     * @dev Buy Boost Item
     * @param itemType  Boost Item type.
     */
    function stakeForBoost(uint256 itemType) external {
        require(isWhitelisted(msg.sender), "You are not allowed to stake");
        uint256 tokenBalance = IERC20(paymentTokenAddress).balanceOf(
            msg.sender
        );
        require(
            boostItemExpireTime[msg.sender][1] == 0 ||
                boostItemExpireTime[msg.sender][1] < block.timestamp,
            "You already have an active boost item"
        );
        require(
            boostItemExpireTime[msg.sender][2] == 0 ||
                boostItemExpireTime[msg.sender][2] < block.timestamp,
            "You already have an active boost item"
        );
        require(
            boostItemExpireTime[msg.sender][3] == 0 ||
                boostItemExpireTime[msg.sender][3] < block.timestamp,
            "You already have an active boost item"
        );
        uint256 amount = 0;
        if (itemType == 1) {
            amount = _goldItemPrice;
        } else if (itemType == 2) {
            amount = _silverItemPrice;
        } else if (itemType == 3) {
            amount = _bronzeItemPrice;
        } else {
            require(false, "Invalid item type");
        }

        require(tokenBalance >= amount, "Insufficient balance for boost");
        require(
            IERC20(paymentTokenAddress).transferFrom(
                msg.sender,
                address(this),
                amount
            ),
            "Token Stake error"
        );

        platformStatistic.totalStakedForBoost = platformStatistic
            .totalStakedForBoost
            .add(amount);
        platformStatistic.totalCommission = platformStatistic
            .totalCommission
            .add(amount);
        userBoostItemBalance[msg.sender][itemType] = userBoostItemBalance[
            msg.sender
        ][itemType].add(1);
        boostItemExpireTime[msg.sender][itemType] = block.timestamp.add(
            BOOST_EXPIRE_TIME
        );

        emit PurchasedBoostItem(msg.sender, itemType);
        emit UpdatedStatisticData(platformStatistic);
    }

    /**
     * @dev burn
     * @param amount  token amount to burn.
     */
    function burn_new(uint256 amount) internal {
        require(
            IERC20(paymentTokenAddress).transfer(
                address(0x000000000000000000000000000000000000dEaD),
                amount
            )
        );
    }

    /**
     * @dev Withdraw token from staked balance by User
     * @param stakeType, staked Type: 1 : StakedForPlay, 2 : StakedForEarning, 3 : StakedForBoost
     * @param amount amount to withdraw
     */
    function withdrawStakedToken(uint256 stakeType, uint256 amount) external {
        require(amount > 0, "You need to withdraw at least some tokens");
        if (stakeType == 1) {
            uint256 commissionFee = amount.mul(_withdrawFeeForPlay).div(100);
            require(
                stakeForPlayLists[msg.sender] >= amount,
                "Insufficient Staked amount for Playing"
            );
            require(
                IERC20(paymentTokenAddress).transfer(
                    msg.sender,
                    amount.sub(commissionFee)
                )
            );
            stakeForPlayLists[msg.sender] = stakeForPlayLists[msg.sender].sub(
                amount
            );
            platformStatistic.totalStakedForPlay = platformStatistic
                .totalStakedForPlay
                .sub(amount);
            platformStatistic.totalWithdrawn = platformStatistic
                .totalWithdrawn
                .add(amount.sub(commissionFee));
            platformStatistic.totalCommission = platformStatistic
                .totalCommission
                .add(commissionFee);
            emit StakedWithdrawn(
                amount.sub(commissionFee),
                stakeType,
                msg.sender
            );
        }
        if (stakeType == 2) {
            uint256 commissionFee = amount.mul(_withdrawFeeForEarn).div(100);
            require(
                stakeForEarningLists[msg.sender] >= amount,
                "Insufficient Staked amount for Earn"
            );
            require(
                IERC20(paymentTokenAddress).transfer(
                    msg.sender,
                    amount.sub(commissionFee)
                )
            );
            stakeForEarningLists[msg.sender] = stakeForEarningLists[msg.sender]
                .sub(amount);
            platformStatistic.totalStakedForEarn = platformStatistic
                .totalStakedForEarn
                .sub(amount);
            platformStatistic.totalWithdrawn = platformStatistic
                .totalWithdrawn
                .add(amount.sub(commissionFee));
            platformStatistic.totalCommission = platformStatistic
                .totalCommission
                .add(commissionFee);
            emit StakedWithdrawn(
                amount.sub(commissionFee),
                stakeType,
                msg.sender
            );
        }
        emit UpdatedStatisticData(platformStatistic);
    }

    /**
     * @dev _setBaseStakeAmountForPlay
     * @param _newBaseStakeAmountForPlay  _newBaseStakeAmountForPlay.
     */
    function _setBaseStakeAmountForPlay(uint256 _newBaseStakeAmountForPlay)
        external
        onlyRole(CFO_ROLE)
    {
        require(
            _newBaseStakeAmountForPlay >= 100 &&
                _newBaseStakeAmountForPlay <= 1000000 * 10**18,
            "Invalid Parameter"
        );
        _baseStakeAmountForPlay = _newBaseStakeAmountForPlay;
    }

    /**
     * @dev _setBaseStakeAmountForEarn
     * @param _newBaseStakeAmountForEarn  _newBaseStakeAmountForEarn.
     */
    function _setBaseStakeAmountForEarn(uint256 _newBaseStakeAmountForEarn)
        external
        onlyRole(CFO_ROLE)
    {
        require(
            _newBaseStakeAmountForEarn >= 1000 &&
                _newBaseStakeAmountForEarn <= 10000000 * 10**18,
            "Invalid Parameter"
        );
        _baseStakeAmountForEarn = _newBaseStakeAmountForEarn;
    }

    /**
     * @dev _setBurFee
     * @param _newBurnFee  _newBurnFee.
     */
    function _setBurFee(uint256 _newBurnFee) external onlyRole(CFO_ROLE) {
        require(_newBurnFee > 0 && _newBurnFee <= 10, "Invalid Parameter");
        _burnFee = _newBurnFee;
    }

    /**
     * @dev _setWithdrawFee
     * @param _newWithdrawFee  _newWithdrawFee.
     */
    function _setWithdrawFee(uint256 _newWithdrawFee)
        external
        onlyRole(CFO_ROLE)
    {
        require(
            _newWithdrawFee > 0 && _newWithdrawFee <= 10,
            "Invalid Parameter"
        );
        _baseUnitForWithdrawFee = _newWithdrawFee;
    }

    /**
     * @dev _setThawingPeriod
     * @param _newThawingPeriod  _newThawingPeriod.
     * maximum period:  1 day
     */
    function _setThawingPeriod(uint256 _newThawingPeriod)
        external
        onlyRole(CMO_ROLE)
    {
        require(
            _newThawingPeriod > 0 && _newThawingPeriod <= 86400,
            "Invalid Parameter"
        );
        _thawingLockingPeriod = _newThawingPeriod;
    }

    /**
     * @dev _addRewardCandidatePeriod.
     * @param _newAddRewardCandidatePeriod  new Add Reward Candidate Period.
     * maximum period 2 days
     */
    function _setAddRewardCandidatePeriod(uint256 _newAddRewardCandidatePeriod)
        external
        onlyOwner
    {
        require(
            _newAddRewardCandidatePeriod > 0 &&
                _newAddRewardCandidatePeriod <= 172800,
            "Invalid Parameter"
        );
        _addRewardCandidatePeriod = _newAddRewardCandidatePeriod;
    }

    /**
     * @dev Whitelists a bunch of addresses.
     * @param _whitelistees address[] of addresses to whitelist.
     */
    function initWhitelist(address[] memory _whitelistees)
        external
        onlyRole(CMO_ROLE)
    {
        // Add all whitelistees.
        for (uint256 i = 0; i < _whitelistees.length; i++) {
            address creator = _whitelistees[i];
            if (!isWhitelisted(creator)) {
                _whitelist(creator);
            }
        }
    }

    /**
     * @dev unWhitelists a bunch of addresses.
     * @param _unwhitelistees address[] of addresses to unwhitelist.
     */
    function removeFromWhitelist(address[] memory _unwhitelistees)
        external
        onlyRole(CMO_ROLE)
    {
        // Add all whitelistees.
        for (uint256 i = 0; i < _unwhitelistees.length; i++) {
            address creator = _unwhitelistees[i];
            if (isWhitelisted(creator)) {
                _unWhitelist(creator);
            }
        }
    }

    /**
     * @dev Add users into Reward candidate list.
     * @param userAddresses  user addresses to be added in reward candidate list.
     * @param approveAmounts reward amounts per user.
     */
    function batchAddRewardCandidates(
        address[] memory userAddresses,
        uint256[] memory approveAmounts
    ) external onlyOwner {
        require(userAddresses.length > 0, "Empty List");
        require(
            userAddresses.length == approveAmounts.length,
            "array lengths mismatch"
        );
        require(
            block.timestamp - _lastAddCandidateOperationTime >
                _addRewardCandidatePeriod,
            "Operation is still locked"
        );

        uint256 totalApprovedTokenAmount = 0;
        for (uint256 i = 0; i < userAddresses.length; i++) {
            if (isWhitelisted(msg.sender)) {
                totalApprovedTokenAmount = totalApprovedTokenAmount.add(
                    approveAmounts[i]
                );
            }
        }
        uint256 availableBalance = IERC20(paymentTokenAddress)
            .balanceOf(address(this))
            .add(platformStatistic.totalRewarded)
            .sub(platformStatistic.totalApproved);
        require(
            availableBalance >= totalApprovedTokenAmount,
            "Game Factory Contract does not have sufficient Balance"
        );
        for (uint256 i = 0; i < userAddresses.length; i++) {
            if (isWhitelisted(msg.sender)) {
                //Capping user earnings for the reward cycle.
                uint256 rewardedAmount = approveAmounts[i] >
                    maxUserEarningPerDay
                    ? maxUserEarningPerDay
                    : approveAmounts[i];
                rewardCandidates[userAddresses[i]]
                    .approvedAmount = rewardCandidates[userAddresses[i]]
                    .approvedAmount
                    .add(rewardedAmount);
                rewardCandidates[userAddresses[i]].lastRewardedTime = block
                    .timestamp;
            }
        }
        // Genesis Mining
        platformStatistic.totalApproved = platformStatistic.totalApproved.add(
            totalApprovedTokenAmount
        );
        _lastAddCandidateOperationTime = block.timestamp;
        emit RewardCandidatesAdded(
            userAddresses.length,
            totalApprovedTokenAmount
        );
    }

    /**
     * @dev _setBurnStatus
     * @param _burnableStatus  _burnableStatus.
     */
    function _setBurnStatus(bool _burnableStatus) external onlyOwner {
        isBurnable = _burnableStatus;
    }

    /**
     * @dev _setMaxUserEarningPerDay
     * @param _maxUserEarningPerDay  _maxUserEarningPerDay.
     */
    function _setMaxUserEarningPerDay(uint256 _maxUserEarningPerDay)
        external
        onlyOwner
    {
        maxUserEarningPerDay = _maxUserEarningPerDay;
    }

    // setGoldItemPrice
    function setGoldItemPrice(uint256 _amount) external onlyOwner {
        _goldItemPrice = _amount;
    }

    // setSilverItemPrice
    function setSilverItemPrice(uint256 _amount) external onlyOwner {
        _silverItemPrice = _amount;
    }

    // setBronzeItemPrice
    function setBronzeItemPrice(uint256 _amount) external onlyOwner {
        _bronzeItemPrice = _amount;
    }

    /**
     * @dev withdraw Fee
     * @param   _to withdraw address.
     * @param   amount amount to withdraw.
     */
    function withdrawFee(address _to, uint256 amount) external onlyOwner {
        uint256 availableCommissionBalance = platformStatistic
            .totalCommission
            .sub(platformStatistic.totalCommissionWithdrawn);
        uint256 contractTokenBalance = IERC20(paymentTokenAddress).balanceOf(
            address(this)
        );
        require(
            availableCommissionBalance > amount,
            "insufficient commission balance"
        );
        require(contractTokenBalance > amount, "insufficient contract balance");
        if (isBurnable) {
            // burn(address(this), amount.mul(_burnFee).div(100));
            burn_new(amount.mul(_burnFee).div(100));
            require(
                IERC20(paymentTokenAddress).transfer(
                    _to,
                    amount.sub(amount.mul(_burnFee).div(100))
                )
            );
            platformStatistic.totalBurned = platformStatistic.totalBurned.add(
                amount.mul(_burnFee).div(100)
            );
        } else {
            require(IERC20(paymentTokenAddress).transfer(_to, amount));
        }
        platformStatistic.totalCommissionWithdrawn = platformStatistic
            .totalCommissionWithdrawn
            .add(amount);
        emit CommissionWithdrawn(_to, amount);
    }

    /**
     * @dev update boost expire time
     * @param _BOOST_EXPIRE_TIME  boost expire time.
     */
    function updateBoostExpireTime(uint256 _BOOST_EXPIRE_TIME)
        external
        onlyRole(CFO_ROLE)
    {
        BOOST_EXPIRE_TIME = _BOOST_EXPIRE_TIME;
    }
}
