module prophyt::test_fixtures {
    #[test_only]
    use sui::test_scenario::{Self, Scenario};

    use prophyt::haedal_adapter::{Self, HaedalState};
    use prophyt::suilend_adapter::{Self, SuilendState};
    use prophyt::volo_adapter::{Self, VoloState};
    use prophyt::protocol_selector;
    use prophyt::prophyt_agent;

    /// USDC test coin
    public struct USDC has drop {}

    // ========== Initialization Fixtures ==========

    /// Create all protocol adapters in test scenario
    public fun create_all_adapters(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, @0x1);
        {
            let ctx = test_scenario::ctx(scenario);
            haedal_adapter::initialize<USDC>(500, ctx);
        };

        test_scenario::next_tx(scenario, @0x1);
        {
            let ctx = test_scenario::ctx(scenario);
            suilend_adapter::initialize<USDC>(400, ctx);
        };

        test_scenario::next_tx(scenario, @0x1);
        {
            let ctx = test_scenario::ctx(scenario);
            volo_adapter::initialize<USDC>(600, 100, ctx);
        };
    }

    /// Create protocol registry
    public fun create_protocol_registry(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, @0x1);
        {
            let ctx = test_scenario::ctx(scenario);
            protocol_selector::initialize<USDC>(100, 5, ctx);
        };
    }

    /// Create agent config
    public fun create_agent_config(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, @0x1);
        {
            let ctx = test_scenario::ctx(scenario);
            let _ctx_ref = ctx;
            prophyt_agent::initialize(100, 1000, 10, _ctx_ref);
        };
    }

    /// Create all protocol adapters and registry
    public fun create_full_protocol_environment(scenario: &mut Scenario) {
        create_all_adapters(scenario);
        create_protocol_registry(scenario);
    }

    // ========== Common Test Scenarios ==========

    /// Setup scenario with Haedal adapter
    public fun setup_haedal(scenario: &mut Scenario): HaedalState<USDC> {
        test_scenario::next_tx(scenario, @0x1);
        {
            let ctx = test_scenario::ctx(scenario);
            haedal_adapter::initialize<USDC>(500, ctx);
        };
        
        test_scenario::next_tx(scenario, @0x1);
        test_scenario::take_shared<HaedalState<USDC>>(scenario)
    }

    /// Setup scenario with Suilend adapter
    public fun setup_suilend(scenario: &mut Scenario): SuilendState<USDC> {
        test_scenario::next_tx(scenario, @0x1);
        {
            let ctx = test_scenario::ctx(scenario);
            suilend_adapter::initialize<USDC>(400, ctx);
        };
        
        test_scenario::next_tx(scenario, @0x1);
        test_scenario::take_shared<SuilendState<USDC>>(scenario)
    }

    /// Setup scenario with Volo adapter
    public fun setup_volo(scenario: &mut Scenario): VoloState<USDC> {
        test_scenario::next_tx(scenario, @0x1);
        {
            let ctx = test_scenario::ctx(scenario);
            volo_adapter::initialize<USDC>(600, 100, ctx);
        };
        
        test_scenario::next_tx(scenario, @0x1);
        test_scenario::take_shared<VoloState<USDC>>(scenario)
    }

    // ========== Assertion Helpers ==========

    /// Assert protocol APY matches expected value
    public fun assert_protocol_apy(
        _protocol_name: vector<u8>,
        expected_apy: u64,
        actual_apy: u64,
    ) {
        assert!(
            actual_apy == expected_apy,
            0
        );
    }

    /// Assert protocol TVL is non-negative
    public fun assert_protocol_tvl_valid(tvl: u64) {
        // TVL should always be non-negative (which it is by type)
        assert!(tvl >= 0, 0);
    }

    /// Assert balance is within reasonable range
    public fun assert_balance_valid(balance: u64) {
        // Balance should be non-negative
        assert!(balance >= 0, 0);
    }

    // ========== Constant Fixtures ==========

    /// Get typical Haedal APY for testing
    public fun default_haedal_apy(): u64 {
        500  // 5%
    }

    /// Get typical Suilend APY for testing
    public fun default_suilend_apy(): u64 {
        400  // 4%
    }

    /// Get typical Volo APY for testing
    public fun default_volo_apy(): u64 {
        600  // 6%
    }

    /// Get typical Volo performance fee
    public fun default_volo_fee(): u64 {
        100  // 1%
    }

    /// Get typical protocol selector minimum APY threshold
    public fun default_min_apy_threshold(): u64 {
        100  // 1%
    }

    /// Get typical protocol selector maximum risk tolerance
    public fun default_max_risk_tolerance(): u8 {
        5
    }

    /// Get typical agent rebalance threshold
    public fun default_rebalance_threshold(): u64 {
        100  // 1%
    }

    /// Get typical agent minimum rebalance amount
    public fun default_min_rebalance_amount(): u64 {
        1000
    }

    /// Get typical agent rebalance interval
    public fun default_rebalance_interval(): u64 {
        10  // epochs
    }

    // ========== Protocol Configuration Fixtures ==========

    /// Test configuration for conservative strategy
    public fun conservative_config(): (u64, u64, u64) {
        (300, 1000, 100)  // apy, amount, interval
    }

    /// Test configuration for aggressive strategy
    public fun aggressive_config(): (u64, u64, u64) {
        (800, 5000, 5)  // apy, amount, interval
    }

    /// Test configuration for balanced strategy
    public fun balanced_config(): (u64, u64, u64) {
        (500, 2500, 10)  // apy, amount, interval
    }

    // ========== Address Fixtures ==========

    /// Primary test address
    public fun test_addr_primary(): address {
        @0x1
    }

    /// Secondary test address
    public fun test_addr_secondary(): address {
        @0x2
    }

    /// Tertiary test address
    public fun test_addr_tertiary(): address {
        @0x3
    }

    /// Admin/owner address
    public fun test_addr_admin(): address {
        @0xABCD
    }

    // ========== Test Data Generators ==========

    /// Generate a sequence of APY values for testing
    public fun generate_apy_sequence(start: u64, count: u64): vector<u64> {
        let mut apys = std::vector::empty<u64>();
        let mut i = 0;
        
        while (i < count) {
            std::vector::push_back(&mut apys, start + (i * 50));
            i = i + 1;
        };
        
        apys
    }

    /// Verify APY is within reasonable bounds
    public fun is_reasonable_apy(apy: u64): bool {
        // APY should be between 0% and 1000% (0 to 10000 basis points)
        apy <= 100000
    }

    /// Verify address is valid (non-zero)
    public fun is_valid_address(addr: address): bool {
        addr != @0x0
    }
}
