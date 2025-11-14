module prophyt::unit_tests;

use prophyt::constants;
use prophyt::haedal_adapter::{Self, HaedalState};
use prophyt::prophyt_agent::{Self, AgentConfig};
use prophyt::suilend_adapter::{Self, SuilendState};
use prophyt::volo_adapter::{Self, VoloState};
use sui::coin;
use sui::test_scenario;

#[test_only]
use std::string;

public struct USDC has drop {}

#[test]
fun test_haedal_initialize() {
    let mut scenario = test_scenario::begin(@0x1);
    {
        let ctx = test_scenario::ctx(&mut scenario);
        haedal_adapter::initialize<USDC>(500, ctx);
    };

    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let state = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
        assert!(haedal_adapter::get_current_apy(&state) == 500, 1);
        test_scenario::return_shared(state);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_haedal_deposit() {
    let mut scenario = test_scenario::begin(@0x1);
    {
        let ctx = test_scenario::ctx(&mut scenario);
        haedal_adapter::initialize<USDC>(500, ctx);
    };

    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let mut state = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);

        let coin = coin::mint_for_testing<USDC>(1000, ctx);
        let success = haedal_adapter::deposit(&mut state, coin, ctx);

        assert!(success == true, 1);
        test_scenario::return_shared(state);
    };

    test_scenario::end(scenario);
}

#[test]
fun test_haedal_get_balance() {
    let mut scenario = test_scenario::begin(@0x1);
    {
        let ctx = test_scenario::ctx(&mut scenario);
        haedal_adapter::initialize<USDC>(500, ctx);
    };

    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let state = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
        let balance = haedal_adapter::get_balance(&state, @0x1);

        assert!(balance == 0, 1);
        test_scenario::return_shared(state);
    };

    test_scenario::end(scenario);
}

#[test]
fun test_haedal_apy() {
    let mut scenario = test_scenario::begin(@0x1);
    {
        let ctx = test_scenario::ctx(&mut scenario);
        haedal_adapter::initialize<USDC>(500, ctx);
    };

    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let state = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
        let apy = haedal_adapter::get_current_apy(&state);

        assert!(apy == 500, 1);
        test_scenario::return_shared(state);
    };

    test_scenario::end(scenario);
}

#[test]
fun test_suilend_initialize() {
    let mut scenario = test_scenario::begin(@0x1);
    {
        let ctx = test_scenario::ctx(&mut scenario);
        suilend_adapter::initialize<USDC>(400, ctx);
    };

    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let state = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
        assert!(suilend_adapter::get_current_apy(&state) == 400, 1);
        test_scenario::return_shared(state);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_suilend_deposit() {
    let mut scenario = test_scenario::begin(@0x1);
    {
        let ctx = test_scenario::ctx(&mut scenario);
        suilend_adapter::initialize<USDC>(400, ctx);
    };

    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let mut state = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);

        let coin = coin::mint_for_testing<USDC>(1000, ctx);
        let success = suilend_adapter::deposit(&mut state, coin, ctx);

        assert!(success == true, 1);
        test_scenario::return_shared(state);
    };

    test_scenario::end(scenario);
}

#[test]
fun test_suilend_get_balance() {
    let mut scenario = test_scenario::begin(@0x1);
    {
        let ctx = test_scenario::ctx(&mut scenario);
        suilend_adapter::initialize<USDC>(400, ctx);
    };

    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let state = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
        let balance = suilend_adapter::get_balance(&state, @0x1);

        assert!(balance == 0, 1);
        test_scenario::return_shared(state);
    };

    test_scenario::end(scenario);
}

#[test]
fun test_volo_initialize() {
    let mut scenario = test_scenario::begin(@0x1);
    {
        let ctx = test_scenario::ctx(&mut scenario);
        volo_adapter::initialize<USDC>(600, 100, ctx);
    };

    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let state = test_scenario::take_shared<VoloState<USDC>>(&scenario);
        assert!(volo_adapter::get_current_apy(&state) == 600, 1);
        test_scenario::return_shared(state);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_volo_get_balance() {
    let mut scenario = test_scenario::begin(@0x1);
    {
        let ctx = test_scenario::ctx(&mut scenario);
        volo_adapter::initialize<USDC>(600, 100, ctx);
    };

    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let state = test_scenario::take_shared<VoloState<USDC>>(&scenario);
        let balance = volo_adapter::get_balance(&state, @0x1);

        assert!(balance == 0, 1);
        test_scenario::return_shared(state);
    };

    test_scenario::end(scenario);
}

#[test]
fun test_agent_initialize() {
    let mut scenario = test_scenario::begin(@0x1);
    {
        let ctx = test_scenario::ctx(&mut scenario);
        prophyt_agent::initialize(100, 1000, 10, ctx);
    };

    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let config = test_scenario::take_shared<AgentConfig>(&scenario);
        let (enabled, _, _, _) = prophyt_agent::get_stats(&config);
        assert!(enabled == true, 1);
        test_scenario::return_shared(config);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_agent_stats() {
    let mut scenario = test_scenario::begin(@0x1);
    {
        let ctx = test_scenario::ctx(&mut scenario);
        prophyt_agent::initialize(100, 1000, 10, ctx);
    };

    test_scenario::next_tx(&mut scenario, @0x1);
    {
        let config = test_scenario::take_shared<AgentConfig>(&scenario);
        let (enabled, total_rebalances, _last_epoch, threshold) = prophyt_agent::get_stats(&config);

        assert!(enabled == true, 1);
        assert!(total_rebalances == 0, 2);
        assert!(threshold == 100, 3);
        test_scenario::return_shared(config);
    };

    test_scenario::end(scenario);
}

#[test]
fun test_protocol_names() {
    assert!(string::as_bytes(&haedal_adapter::get_protocol_name()) == &b"Haedal", 1);
    assert!(string::as_bytes(&suilend_adapter::get_protocol_name()) == &b"Suilend", 2);
    assert!(string::as_bytes(&volo_adapter::get_protocol_name()) == &b"Volo", 3);
}

#[test]
fun test_constants() {
    assert!(constants::basis_points() == 10000, 1);
    assert!(constants::protocol_suilend() == 1, 2);
    assert!(constants::protocol_haedal() == 2, 3);
    assert!(constants::protocol_volo() == 3, 4);
    assert!(constants::apy_weight() == 60, 5);
}
