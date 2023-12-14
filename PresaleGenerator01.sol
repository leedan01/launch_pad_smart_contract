// SPDX-License-Identifier: UNLICENSED
// @Credits Unicrypt Network 2021

// This contract generates Presale01 contracts and registers them in the PresaleFactory.
// Ideally you should not interact with this contract directly, and use the Octofi presale app instead so warnings can be shown where necessary.

pragma solidity 0.6.12;

import "./Presale01.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./TransferHelper.sol";
import "./PresaleHelper.sol";

interface IPresaleFactory {
    function registerPresale (address _presaleAddress) external;
    function presaleIsRegistered(address _presaleAddress) external view returns (bool);
}

interface IUniswapV2Locker {
    function lockLPToken (address _lpToken, uint256 _amount, uint256 _unlock_date, address payable _referral, bool _fee_in_eth, address payable _withdrawer) external payable;
}

contract PresaleGenerator01 is Ownable {
    using SafeMath for uint256;

    //create base param
    event presaleGenerator(address  presale01Address,address  presaleOwner,IERC20  presaleToken,IERC20  _baseToken,
    address  referralAddress, uint256 indexed  _projectCode);

    //create base arr[]
    event presaleGeneratorParam(uint256 amount,uint256 tokenPrice,uint256  maxSpendPerBuyer,uint256 hardcap,
    uint256 softcap,uint256 liquidityPercent,uint256 listingRate,uint256 startblock,uint256 endblock,uint256 lockPeriod);



    IPresaleFactory public PRESALE_FACTORY;
    IPresaleSettings public PRESALE_SETTINGS;
    
    struct PresaleParams {
        uint256 amount;
        uint256 tokenPrice;
        uint256 maxSpendPerBuyer;
        uint256 hardcap;
        uint256 softcap;
        uint256 liquidityPercent;
        uint256 listingRate; // sale token listing price on uniswap
        uint256 startblock;
        uint256 endblock;
        uint256 lockPeriod;
    }
    
    constructor() public {
        PRESALE_FACTORY = IPresaleFactory(0xC3eDbe82747BBeD73b772De2b7854609aC5D25c8);
        PRESALE_SETTINGS = IPresaleSettings(0xB9f4e9f8c6f5F440E5b91Afb2854ca6789897DA9);
    }
    
    /**
     * @notice Creates a new Presale contract and registers it in the PresaleFactory.sol.
     */
    function createPresale (
      address payable _presaleOwner,
      IERC20 _presaleToken,
      IERC20 _baseToken,
      address payable _referralAddress,
      uint256  _projectId,
      uint256[10] memory uint_params
      ) public payable {
        
        PresaleParams memory params;
        params.amount = uint_params[0];
        params.tokenPrice = uint_params[1];
        params.maxSpendPerBuyer = uint_params[2];
        params.hardcap = uint_params[3];
        params.softcap = uint_params[4];
        params.liquidityPercent = uint_params[5];
        params.listingRate = uint_params[6];
        params.startblock = uint_params[7];
        params.endblock = uint_params[8];
        params.lockPeriod = uint_params[9];
        
        // if (params.lockPeriod < 4 weeks) {
        //     params.lockPeriod = 4 weeks;
        // }
        
        // Charge ETH fee for contract creation
        require(msg.value == PRESALE_SETTINGS.getEthCreationFee(), 'FEE NOT MET');
        PRESALE_SETTINGS.getEthAddress().transfer(PRESALE_SETTINGS.getEthCreationFee());
        
        if (_referralAddress != address(0)) {
            require(PRESALE_SETTINGS.referrerIsValid(_referralAddress), 'INVALID REFERRAL');
        }
        // require(bytes(_projectCode).length != 0, 'not have projectCode');
        require(params.amount >= 10000, 'MIN DIVIS'); // minimum divisibility
        require(params.endblock.sub(params.startblock) <= PRESALE_SETTINGS.getMaxPresaleLength(),'blocks too long');
        require(params.tokenPrice.mul(params.hardcap) > 0, 'INVALID PARAMS'); // ensure no overflow for future calculations
        require(params.liquidityPercent >= 300 && params.liquidityPercent <= 1000, 'MIN LIQUIDITY'); // 30% minimum liquidity lock
        
        uint256 tokensRequiredForPresale = PresaleHelper.calculateAmountRequired(params.amount, params.tokenPrice, params.listingRate, params.liquidityPercent, PRESALE_SETTINGS.getTokenFee());
        
        Presale01 newPresale = new Presale01(address(this));
        TransferHelper.safeTransferFrom(address(_presaleToken), address(msg.sender), address(newPresale), tokensRequiredForPresale);
        newPresale.init1(_presaleOwner, params.amount, params.tokenPrice, params.maxSpendPerBuyer, params.hardcap, params.softcap, 
        params.liquidityPercent, params.listingRate, params.startblock, params.endblock, params.lockPeriod);
        newPresale.init2(_baseToken, _presaleToken, PRESALE_SETTINGS.getBaseFee(), PRESALE_SETTINGS.getTokenFee(), PRESALE_SETTINGS.getReferralFee(), PRESALE_SETTINGS.getEthAddress(), PRESALE_SETTINGS.getTokenAddress(), _referralAddress);
        PRESALE_FACTORY.registerPresale(address(newPresale));
        
        emit presaleGenerator(address(newPresale),_presaleOwner,_presaleToken,_baseToken,
         _referralAddress,_projectId);
       
        emit presaleGeneratorParam( uint_params[0], uint_params[1],  uint_params[2], uint_params[3],
          uint_params[4],  uint_params[5], uint_params[6],  uint_params[7],  uint_params[8], params.lockPeriod); 
    }
    
}