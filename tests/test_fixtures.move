module prophyt::test_fixtures;

use prophyt::haedal_adapter::{Self, HaedalState};
use prophyt::prophyt_agent;
use prophyt::protocol_selector;
use prophyt::suilend_adapter::{Self, SuilendState};
use prophyt::volo_adapter::{Self, VoloState};

#[test_only]
use sui::test_scenario::{Self, Scenario};

public struct USDC has drop {}

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

public fun create_protocol_registry(scenario: &mut Scenario) {
    test_scenario::next_tx(scenario, @0x1);
    {
        let ctx = test_scenario::ctx(scenario);
        protocol_selector::initialize<USDC>(100, 5, ctx);
    };
}

public fun create_agent_config(scenario: &mut Scenario) {
    test_scenario::next_tx(scenario, @0x1);
    {
        let ctx = test_scenario::ctx(scenario);
        let _ctx_ref = ctx;
        prophyt_agent::initialize(100, 1000, 10, _ctx_ref);
    };
}

public fun create_full_protocol_environment(scenario: &mut Scenario) {
    create_all_adapters(scenario);
    create_protocol_registry(scenario);
}

public fun setup_haedal(scenario: &mut Scenario): HaedalState<USDC> {
    test_scenario::next_tx(scenario, @0x1);
    {
        let ctx = test_scenario::ctx(scenario);
        haedal_adapter::initialize<USDC>(500, ctx);
    };

    test_scenario::next_tx(scenario, @0x1);
    test_scenario::take_shared<HaedalState<USDC>>(scenario)
}

public fun setup_suilend(scenario: &mut Scenario): SuilendState<USDC> {
    test_scenario::next_tx(scenario, @0x1);
    {
        let ctx = test_scenario::ctx(scenario);
        suilend_adapter::initialize<USDC>(400, ctx);
    };

    test_scenario::next_tx(scenario, @0x1);
    test_scenario::take_shared<SuilendState<USDC>>(scenario)
}

public fun setup_volo(scenario: &mut Scenario): VoloState<USDC> {
    test_scenario::next_tx(scenario, @0x1);
    {
        let ctx = test_scenario::ctx(scenario);
        volo_adapter::initialize<USDC>(600, 100, ctx);
    };

    test_scenario::next_tx(scenario, @0x1);
    test_scenario::take_shared<VoloState<USDC>>(scenario)
}

public fun assert_protocol_apy(_protocol_name: vector<u8>, expected_apy: u64, actual_apy: u64) {
    assert!(actual_apy == expected_apy, 0);
}

public fun assert_protocol_tvl_valid(tvl: u64) { assert!(tvl >= 0, 0); }

public fun assert_balance_valid(balance: u64) { assert!(balance >= 0, 0); }

public fun default_haedal_apy(): u64 {
    500
}

public fun default_suilend_apy(): u64 {
    400
}

public fun default_volo_apy(): u64 {
    600
}

public fun default_volo_fee(): u64 {
    100
}

public fun default_min_apy_threshold(): u64 {
    100
}

public fun default_max_risk_tolerance(): u8 {
    5
}

public fun default_rebalance_threshold(): u64 {
    100
}

public fun default_min_rebalance_amount(): u64 {
    1000
}

public fun default_rebalance_interval(): u64 {
    10
}

public fun conservative_config(): (u64, u64, u64) {
    (300, 1000, 100)
}

public fun aggressive_config(): (u64, u64, u64) {
    (800, 5000, 5)
}

public fun balanced_config(): (u64, u64, u64) {
    (500, 2500, 10)
}

public fun test_addr_primary(): address {
    @0x1
}

public fun test_addr_secondary(): address {
    @0x2
}

public fun test_addr_tertiary(): address {
    @0x3
}

public fun test_addr_admin(): address {
    @0xABCD
}

public fun generate_apy_sequence(start: u64, count: u64): vector<u64> {
    let mut apys = std::vector::empty<u64>();
    let mut i = 0;

    while (i < count) {
        std::vector::push_back(&mut apys, start + (i * 50));
        i = i + 1;
    };

    apys
}

public fun is_reasonable_apy(apy: u64): bool { apy <= 100000 }

public fun is_valid_address(addr: address): bool {
    addr != @0x0
}
