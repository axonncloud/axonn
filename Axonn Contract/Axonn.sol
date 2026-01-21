// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IFaces/IPancakeRouter2.sol";
import "./IFaces/IERC20Detailed.sol";

contract AXN_Token is ERC20, Ownable, ReentrancyGuard {
    IcommunityDevelopmentCNT private communityDevelopmentCNTAddr;
    ICreatorTokensCNT private CreatorTokensCNTAddr;
    ICommunityIncentiveCNT private CommunityIncentiveCNTAddr;
    ICakeLockerCNT private CakeLockerCntAddr;
    IAirDropnExchangeCNT private airDropExchangeCntAddr;
    IRewardsTokensCNT private rewardsTokensCntAddr;

    address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    using SafeERC20 for IERC20Detailed;

    address public LiquidityWalletAddress;
    address public preSaleWalletAddress;

    address public CommunityDevelopmentWallet;
    address public CreatorTokensWallet;
    address public airDropExchangeReleaseWallet;
    address public rewardsReleaseWallet;
    address public CakeReleaseWallet;

    address public pancakeSwapV2Pair;

    IPancakeRouter02 public router;
    IERC20Detailed public USDTAddress;

    bool private isInitialDeploy;
    uint256 public constant _decimals = 10**18;
    uint256 public constant _totalSupply = 2500000 * _decimals;

    uint256 public constant liquidityPoolTokens = 125000 * _decimals;
    uint256 public creatorTokens = 250000 * _decimals;
    uint256 public communityIncentiveTokens = 1000000 * _decimals;
    uint256 public communityDevelopmentTokens = 500000 * _decimals;

    uint256 public constant preSaleTokens = 125000 * _decimals;
    uint256 public airDropnExchangeTokens = 250000 * _decimals;
    uint256 public rewardsTokens = 250000 * _decimals;

    uint256 private constant SaleSpan = 24 hours;
    uint256 private constant TokenReleaseSpan = 30 days;
    uint256 private constant CakeReleaseSpan = 365 days;
    uint256 public constant MaxSaleTokensInSpan = 3 * _decimals;
    uint256 public constant MaxSaleTokensInSpanOther = 10 * _decimals;
    // uint16 public constant MaxSalePercSpan = 1;
    uint16 public constant PERCENT_DIVISOR = 100;

    uint16 public constant creatorMonthlyReleasePerc = 3;
    uint16 public constant CakeTokensReleasePerc = 20;
    uint16 public constant RewardsTokeReleaseRate = 7;
    uint16 public constant AirdropTokensReleaseRate = 7;
    uint16 public constant DevelopmentTokensReleaseRate = 7;

    uint16 public CakeTokensReleaseCount = 0;

    mapping(address => uint256) public lastSellTime;
    mapping(address => uint256) public sellableLimit;
    mapping(address => bool) public userAddingliquidity;

    uint256 public lastCreatorRelease = 0;
    uint256 public lastDevelopmentRelease = 0;
    uint256 public lastCakeRelease = 0;

    uint256 public lastAirdropRelease = 0;
    uint256 public lastRewardsRelease = 0;
    bool private BurnIt = false;

    constructor(
        address _LiquidityWalletAddress,
        address _preSaleWalletAddress,
        address _airDropExchangeCntAddr,
        address _rewardsTokensCntAddr,
        address _communityDevelopmentCNTAddr,
        address _CreatorTokensCNTAddr,
        address _CommunityIncentiveCNTAddr,
        address _CakeLockerCntAddr
    ) ERC20("AXONN", "AXN") Ownable(msg.sender) {
        require(
            _LiquidityWalletAddress != address(0),
            "Invalid creator address"
        );

        require(_preSaleWalletAddress != address(0), "Invalid Presale address");

        LiquidityWalletAddress = _LiquidityWalletAddress;
        preSaleWalletAddress = _preSaleWalletAddress;

        airDropExchangeCntAddr = IAirDropnExchangeCNT(_airDropExchangeCntAddr);
        rewardsTokensCntAddr = IRewardsTokensCNT(_rewardsTokensCntAddr);

        communityDevelopmentCNTAddr = IcommunityDevelopmentCNT(
            _communityDevelopmentCNTAddr
        );

        CreatorTokensCNTAddr = ICreatorTokensCNT(_CreatorTokensCNTAddr);
        CommunityIncentiveCNTAddr = ICommunityIncentiveCNT(
            _CommunityIncentiveCNTAddr
        );

        CakeLockerCntAddr = ICakeLockerCNT(_CakeLockerCntAddr);

        _mint(address(this), _totalSupply);

        _transfer(address(this), LiquidityWalletAddress, liquidityPoolTokens);

        _transfer(address(this), preSaleWalletAddress, preSaleTokens);
        _transfer(
            address(this),
            address(airDropExchangeCntAddr),
            airDropnExchangeTokens
        );
        _transfer(address(this), address(rewardsTokensCntAddr), rewardsTokens);
        _transfer(address(this), address(CreatorTokensCNTAddr), creatorTokens);
        _transfer(
            address(this),
            address(CommunityIncentiveCNTAddr),
            communityIncentiveTokens
        );
        _transfer(
            address(this),
            address(communityDevelopmentCNTAddr),
            communityDevelopmentTokens
        );

        isInitialDeploy = true;
        BurnIt = true;
        ///// uncomment in prodd
        lastCakeRelease = block.timestamp + (CakeReleaseSpan * 4);
        lastCreatorRelease = block.timestamp;
        lastDevelopmentRelease = block.timestamp;
        lastAirdropRelease = block.timestamp;
        lastRewardsRelease = block.timestamp;
    }

    function setAddresses(
        address _communityDevelopmentAddr,
        address _CreatorTokensAddr,
        address _airDropExchangeReleaseWallet,
        address _rewardsReleaseWallet,
        address _CakeReleaseWallet
    ) public onlyOwner {
        require(isInitialDeploy, "Initial deployment already completed");
        require(
            _communityDevelopmentAddr != address(0),
            "Invalid community development address"
        );
        require(
            _CreatorTokensAddr != address(0),
            "Invalid creator tokens address"
        );

        require(
            _airDropExchangeReleaseWallet != address(0),
            "Invalid airDropExchangeReleaseWallet"
        );

        require(
            _rewardsReleaseWallet != address(0),
            "Invalid rewardsReleaseWallet"
        );

        require(_CakeReleaseWallet != address(0), "Invalid CakeReleaseWallet");

        CommunityDevelopmentWallet = _communityDevelopmentAddr;
        CreatorTokensWallet = _CreatorTokensAddr;
        airDropExchangeReleaseWallet = _airDropExchangeReleaseWallet;
        rewardsReleaseWallet = _rewardsReleaseWallet;
        CakeReleaseWallet = _CakeReleaseWallet;

        // Disable further updates
        isInitialDeploy = false;
    }

    function releaseAirdropTokens() external {
        require(
            lastAirdropRelease == 0 ||
                block.timestamp >= lastAirdropRelease + TokenReleaseSpan,
            "Monthly release not available yet"
        );

        require(
            airDropnExchangeTokens > 0,
            "All Airdrop tokens have been released"
        );

        uint256 amountToRelease = (airDropnExchangeTokens *
            AirdropTokensReleaseRate) / PERCENT_DIVISOR;

        if (amountToRelease > airDropnExchangeTokens) {
            amountToRelease = airDropnExchangeTokens;
        }

        airDropnExchangeTokens -= amountToRelease;

        BurnIt = false;
        airDropExchangeCntAddr.send(
            airDropExchangeReleaseWallet,
            AirdropTokensReleaseRate
        );
        BurnIt = true;
        lastAirdropRelease = block.timestamp;
    }

    function releaseRewardsTokens() external {
        require(
            lastRewardsRelease == 0 ||
                block.timestamp >= lastRewardsRelease + TokenReleaseSpan,
            "Monthly release not available yet"
        );

        require(rewardsTokens > 0, "All Rewards tokens have been released");

        uint256 amountToRelease = (rewardsTokens * RewardsTokeReleaseRate) /
            PERCENT_DIVISOR;

        if (amountToRelease > rewardsTokens) {
            amountToRelease = rewardsTokens;
        }

        rewardsTokens -= amountToRelease;
        BurnIt = false;
        rewardsTokensCntAddr.send(rewardsReleaseWallet, RewardsTokeReleaseRate);
        BurnIt = true;
        lastRewardsRelease = block.timestamp;
    }

    function releaseCreatorTokens() external {
        require(
            lastCreatorRelease == 0 ||
                block.timestamp >= lastCreatorRelease + TokenReleaseSpan,
            "Monthly release not available yet"
        );

        require(creatorTokens > 0, "All creator tokens have been released");
        // uint256 amountToReleaseRate = 3;
        uint256 amountToRelease = (creatorTokens * creatorMonthlyReleasePerc) /
            PERCENT_DIVISOR;

        if (amountToRelease > creatorTokens) {
            amountToRelease = creatorTokens;
        }

        creatorTokens -= amountToRelease;
        BurnIt = false;
        CreatorTokensCNTAddr.send(
            CreatorTokensWallet,
            creatorMonthlyReleasePerc
        );
        BurnIt = true;
        lastCreatorRelease = block.timestamp;
    }

    function releaseCakeTokens() external {
        require(
            lastCakeRelease == 0 ||
                block.timestamp >= lastCakeRelease + CakeReleaseSpan,
            "Yearly release not available yet"
        );

        //Realse Yearly 20% Of Lockbox
        BurnIt = false;
        uint256 amountToReleaseRate = CakeTokensReleaseCount < 5
            ? CakeTokensReleasePerc
            : 100;
        CakeLockerCntAddr.send(CakeReleaseWallet, amountToReleaseRate);
        CakeTokensReleaseCount = CakeTokensReleaseCount + 1;
        BurnIt = true;
        lastCakeRelease = block.timestamp;
    }

    function releaseDevelopmentTokens() external onlyOwner {
        require(
            lastDevelopmentRelease == 0 ||
                block.timestamp >= lastDevelopmentRelease + TokenReleaseSpan,
            "Monthly release not available yet"
        );

        require(
            communityDevelopmentTokens > 0,
            "All development tokens have been released"
        );

        uint256 amountToRelease = (communityDevelopmentTokens *
            DevelopmentTokensReleaseRate) / PERCENT_DIVISOR;

        // uint256 amountToRelease = developmentMonthlyReleaseRate;

        if (amountToRelease > communityDevelopmentTokens) {
            amountToRelease = communityDevelopmentTokens;
        }

        communityDevelopmentTokens -= amountToRelease;

        BurnIt = false;
        communityDevelopmentCNTAddr.send(
            CommunityDevelopmentWallet,
            DevelopmentTokensReleaseRate
        );
        BurnIt = true;
        lastDevelopmentRelease = block.timestamp;
    }

    function setPancakeSwapV2Pair(
        address _router,
        address _pancakeSwapV2Pair,
        address _USDTAddress
    ) external onlyOwner {
        require(_pancakeSwapV2Pair != address(0), "Invalid pair address");
        require(_router != address(0), "Invalid Router address");

        pancakeSwapV2Pair = _pancakeSwapV2Pair;
        router = IPancakeRouter02(_router);
        USDTAddress = IERC20Detailed(_USDTAddress);
    }

    function GetSellableAmt(address _user) public view returns (uint256) {
        uint256 limit = sellableLimit[_user];

        if (limit == 0) {
            limit = (balanceOf(_user) / PERCENT_DIVISOR);
            if (limit > MaxSaleTokensInSpanOther) {
                limit = MaxSaleTokensInSpanOther;
            }
        } else if (limit > MaxSaleTokensInSpan) {
            limit = MaxSaleTokensInSpan;
        }
        return limit;
    }

    function sendCommunityIncentiveTokens(address recipient, uint256 amount)
        external
        onlyOwner
    {
        require(
            amount <= communityIncentiveTokens,
            "Insufficient Community Incentive Tokens"
        );
        require(recipient != address(0), "Invalid recipient address");

        require(
            balanceOf(recipient) == 0,
            "Recipient must have zero token balance"
        );

        communityIncentiveTokens -= amount;
        BurnIt = false;
        CommunityIncentiveCNTAddr.send(recipient, amount);
        sellableLimit[recipient] = amount;
        BurnIt = true;
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // Apply sell restrictions only if transferring to the PancakeSwap pair

        uint256 burnAmount = BurnIt ? amount / 2000 : 0; // 0.05%
        uint256 sendAmount = amount - burnAmount;

        if (
            // !paused() &&
            from != address(this) &&
            // from != CommunityDevelopmentWallet &&
            // from != CreatorTokensWallet &&
            // from != LiquidityWalletAddress &&
            // from != address(communityDevelopmentCNTAddr) &&
            // from != address(CreatorTokensCNTAddr) &&
            from != address(CommunityIncentiveCNTAddr)
        ) {
            require(
                lastSellTime[from] == 0 ||
                    block.timestamp >= lastSellTime[from] + SaleSpan,
                "You can only transfer, Sale after 24 hours of sale"
            );

            if (userAddingliquidity[from] == false && to == pancakeSwapV2Pair) {
                uint256 limit = sellableLimit[from];

                if (limit == 0) {
                    limit = (balanceOf(from) / PERCENT_DIVISOR);
                    if (limit > MaxSaleTokensInSpanOther) {
                        limit = MaxSaleTokensInSpanOther;
                    }
                } else if (limit > MaxSaleTokensInSpan) {
                    limit = MaxSaleTokensInSpan;
                }

                require(limit > 0, "You cannot sell any tokens");

                require(
                    amount <= limit,
                    "Sell amount exceeds your sellable limit"
                );

                if (sellableLimit[from] > 0) {
                    sellableLimit[from] = (sellableLimit[from] > amount)
                        ? sellableLimit[from] - amount
                        : 0;
                } else {
                    sellableLimit[from] = 0;
                }

                lastSellTime[from] = block.timestamp;
                // Burn 0.05% of the amount
                burnAmount = BurnIt ? amount / 2000 : 0; // 0.05%
                sendAmount = amount - burnAmount;
            }

            // If tokens are transferred from a wallet with a specific sellable limit,
            // reset the sellable limit for the recipient to 1% of their wallet balance
            if (sellableLimit[from] > 0 && to != pancakeSwapV2Pair) {
                sellableLimit[from] = 0;
            }
        }

        if (burnAmount > 0) {
            super._update(
                from,
                // address(CakeLockerCntAddr),
                BURN_ADDRESS,
                burnAmount
            );
        }

        super._update(from, to, sendAmount);
    }

    function returnNonAXN(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(this), "Cannot recover AXN");
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        require(balance > 0, "No balance to recover");
        IERC20(tokenAddress).transfer(owner(), balance);
    }

    // function pause() external onlyOwner {
    //     _pause();
    // }

    // function unpause() external onlyOwner {
    //     _unpause();
    // }

    function addLiquidity(
        uint256 tokenAmount,
        uint256 usdtAmount,
        uint256 tokenAmountMin,
        uint256 usdtAmountMin,
        uint256 deadline
    ) public nonReentrant returns (uint256) {
        // Mark the user as adding liquidity
        IERC20 ThisToken = IERC20(address(this));
        userAddingliquidity[msg.sender] = true;
        BurnIt = false;
        // Validate input amounts
        require(tokenAmount > 0, "Token amount must be greater than 0");
        require(usdtAmount > 0, "USDT amount must be greater than 0");

        // Transfer tokens from the user to the contract
        IERC20(address(ThisToken)).transferFrom(
            msg.sender,
            address(this),
            tokenAmount
        );
        USDTAddress.safeTransferFrom(msg.sender, address(this), usdtAmount);

        // Approve the router to spend the tokens
        IERC20(address(this)).approve(address(router), tokenAmount);
        USDTAddress.approve(address(router), usdtAmount);

        // Add liquidity via the router
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                address(this), // This token
                address(USDTAddress),
                tokenAmount,
                usdtAmount,
                tokenAmountMin,
                usdtAmountMin,
                address(CakeLockerCntAddr), // msg.sender,
                deadline
            );

        // Unmark the user as adding liquidity
        userAddingliquidity[msg.sender] = false;

        // Handle any remaining tokens

        if (tokenAmount > amountA) {
            uint256 remainingToken = tokenAmount - amountA;
            _transfer(address(this), msg.sender, remainingToken);
        }
        if (usdtAmount > amountB) {
            uint256 remainingUSDT = usdtAmount - amountB;
            USDTAddress.safeTransfer(msg.sender, remainingUSDT);
        }
        BurnIt = true;
        return liquidity;
    }
}

interface IcommunityDevelopmentCNT {
    function send(address _user, uint256 _amt) external payable;
}

interface ICreatorTokensCNT {
    function send(address _user, uint256 _amt) external payable;
}

interface ICommunityIncentiveCNT {
    function send(address _user, uint256 _amt) external payable;
}

interface ICakeLockerCNT {
    function send(address _user, uint256 _amt) external payable;
}

interface IAirDropnExchangeCNT {
    function send(address _user, uint256 _amt) external payable;
}

interface IRewardsTokensCNT {
    function send(address _user, uint256 _amt) external payable;
}
