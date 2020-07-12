pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "./ESM.sol";

contract GlobalSettlementMock {
    uint256 public contractEnabled;

    constructor() public { contractEnabled = 1; }
    function shutdownSystem() public { contractEnabled = 0; }
}

contract TestUsr {
    DSToken protocolToken;

    constructor(DSToken protocolToken_) public {
        protocolToken = protocolToken_;
    }
    function callShutdown(ESM esm) external {
        esm.shutdown();
    }

    function callBurnTokens(ESM esm, uint256 wad) external {
        protocolToken.approve(address(esm), uint256(-1));

        esm.burnTokens(wad);
    }
}

contract ESMTest is DSTest {
    ESM     esm;
    DSToken protocolToken;
    GlobalSettlementMock globalSettlement;
    uint256 triggerThreshold;
    address tokenBurner;
    TestUsr usr;
    TestUsr gov;

    function setUp() public {
        protocolToken = new DSToken("PROT");
        protocolToken.mint(1000000 ether);
        globalSettlement = new GlobalSettlementMock();
        usr = new TestUsr(protocolToken);
        gov = new TestUsr(protocolToken);
        tokenBurner = address(0x42);
    }

    function test_constructor() public {
        esm = makeWithCap(10);

        assertEq(address(esm.protocolToken()), address(protocolToken));
        assertEq(address(esm.globalSettlement()), address(globalSettlement));
        assertEq(esm.triggerThreshold(), 10);
        assertEq(esm.settled(), 0);
    }

    function testFail_set_low_threshold() public {
        esm = makeWithCap(10);
        esm.modifyParameters(bytes32("triggerThreshold"), 0);
    }

    function testFail_set_high_threshold() public {
        esm = makeWithCap(10);
        esm.modifyParameters(bytes32("triggerThreshold"), 1000001 ether);
    }

    function test_set_threshold() public {
        esm = makeWithCap(10);
        assertEq(esm.triggerThreshold(), 10);
        esm.modifyParameters(bytes32("triggerThreshold"), 15);
        assertEq(esm.triggerThreshold(), 15);
    }

    function test_Sum_is_internal_balance() public {
        esm = makeWithCap(10);
        protocolToken.mint(address(esm), 10);

        assertEq(esm.totalAmountBurnt(), 0);
    }

    function test_shutdown() public {
        esm = makeWithCap(0);
        gov.callShutdown(esm);

        assertEq(esm.settled(), 1);
        assertEq(globalSettlement.contractEnabled(), 0);
    }

    function testFail_fire_twice() public {
        esm = makeWithCap(0);
        gov.callShutdown(esm);

        gov.callShutdown(esm);
    }

    function testFail_join_after_settled() public {
        esm = makeWithCap(0);
        gov.callShutdown(esm);
        protocolToken.mint(address(usr), 10);

        usr.callBurnTokens(esm, 10);
    }

    function testFail_shutdown_threshold_not_met() public {
        esm = makeWithCap(10);
        assertTrue(esm.totalAmountBurnt() <= esm.triggerThreshold());

        gov.callShutdown(esm);
    }

    // -- user actions --
    function test_burnTokens() public {
        protocolToken.mint(address(usr), 10);
        esm = makeWithCap(10);

        usr.callBurnTokens(esm, 10);

        assertEq(esm.totalAmountBurnt(), 10);
        assertEq(protocolToken.balanceOf(address(esm)), 0);
        assertEq(protocolToken.balanceOf(address(usr)), 0);
        assertEq(protocolToken.balanceOf(address(tokenBurner)), 10);
    }

    function test_join_over_threshold() public {
        protocolToken.mint(address(usr), 20);
        esm = makeWithCap(10);

        usr.callBurnTokens(esm, 10);
        usr.callBurnTokens(esm, 10);
    }

    function testFail_join_insufficient_balance() public {
        assertEq(protocolToken.balanceOf(address(usr)), 0);

        usr.callBurnTokens(esm, 10);
    }

    // -- internal test helpers --
    function makeWithCap(uint256 threshold_) internal returns (ESM) {
        return new ESM(address(protocolToken), address(globalSettlement), tokenBurner, threshold_);
    }
}
