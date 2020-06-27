pragma solidity ^0.6.7;

abstract contract TokenLike {
    function balanceOf(address) virtual public view returns (uint256);
    function transfer(address, uint256) virtual public returns (bool);
    function transferFrom(address, address, uint256) virtual public returns (bool);
}

abstract contract GlobalSettlementLike {
    function shutdownSystem() virtual public;
}

contract ESM {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    /**
     * @notice Add auth to an account
     * @param account Account to add auth to
     */
    function addAuthorization(address account) external emitLog isAuthorized {
        authorizedAccounts[account] = 1;
    }
    /**
     * @notice Remove auth from an account
     * @param account Account to remove auth from
     */
    function removeAuthorization(address account) external emitLog isAuthorized {
        authorizedAccounts[account] = 0;
    }
    /**
    * @notice Checks whether msg.sender can call an authed function
    **/
    modifier isAuthorized {
        require(authorizedAccounts[msg.sender] == 1, "esm/account-not-authorized");
        _;
    }

    TokenLike public protocolToken;                 // collateral
    GlobalSettlementLike public globalSettlement;   // shutdown module
    address public tokenBurner;                     // burner
    uint256 public triggerThreshold;                // threshold
    uint256 public settled;

    mapping(address => uint256) public burntTokens; // per-address balance
    uint256 public totalAmountBurnt;                // total balance

    // --- Logs ---
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  usr,
        bytes32  indexed  arg1,
        bytes32  indexed  arg2,
        bytes             data
    ) anonymous;

    modifier emitLog {
        _;
        assembly {
            // log an 'anonymous' event with a constant 6 words of calldata
            // and four indexed topics: selector, caller, arg1 and arg2
            let mark := mload(0x40)                   // end of memory ensures zero
            mstore(0x40, add(mark, 288))              // update free memory pointer
            mstore(mark, 0x20)                        // bytes type data offset
            mstore(add(mark, 0x20), 224)              // bytes size (padded)
            calldatacopy(add(mark, 0x40), 0, 224)     // bytes payload
            log4(mark, 288,                           // calldata
                 shl(224, shr(224, calldataload(0))), // msg.sig
                 caller(),                            // msg.sender
                 calldataload(4),                     // arg1
                 calldataload(36)                     // arg2
                )
        }
    }

    constructor(
      address protocolToken_,
      address globalSettlement_,
      address tokenBurner_,
      uint256 triggerThreshold_
    ) public {
        authorizedAccounts[msg.sender] = 1;
        protocolToken = TokenLike(protocolToken_);
        globalSettlement = GlobalSettlementLike(globalSettlement_);
        tokenBurner = tokenBurner_;
        triggerThreshold = triggerThreshold_;
    }

    // -- math --
    function addition(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x + y;
        require(z >= x);
    }

    // --- Administration ---
    function modifyParameters(bytes32 parameter, uint256 wad) external emitLog isAuthorized {
        if (parameter == "triggerThreshold") triggerThreshold = wad;
        else revert("esm/modify-unrecognized-param");
    }

    function shutdown() external emitLog {
        require(settled == 0,  "esm/already-settled");
        require(totalAmountBurnt >= triggerThreshold, "esm/threshold-not-reached");
        globalSettlement.shutdownSystem();
        settled = 1;
    }

    function burnTokens(uint256 amountToBurn) external emitLog {
        require(settled == 0, "esm/already-settled");

        burntTokens[msg.sender] = addition(burntTokens[msg.sender], amountToBurn);
        totalAmountBurnt = addition(totalAmountBurnt, amountToBurn);

        require(protocolToken.transferFrom(msg.sender, tokenBurner, amountToBurn), "esm/transfer-failed");
    }
}
