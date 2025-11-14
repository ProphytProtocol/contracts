#[allow(duplicate_alias)]
module prophyt::prophyt_agent;

use prophyt::haedal_adapter;
use prophyt::protocol_selector;
use prophyt::staking_protocol::{Self, ProtocolInfo};
use prophyt::suilend_adapter;
use prophyt::volo_adapter;
use std::vector;
use sui::event;
use sui::object::{Self, UID};
use sui::transfer;
use sui::tx_context::TxContext;

const E_REBALANCE_NOT_NEEDED: u64 = 1;
const E_AGENT_NOT_ENABLED: u64 = 3;

public struct AgentConfig has key {
    id: UID,
    enabled: bool,
    rebalance_threshold: u64,
    min_rebalance_amount: u64,
    last_rebalance_epoch: u64,
    rebalance_interval: u64,
    total_rebalances: u64,
}

public struct RebalanceProposal has copy, drop {
    from_protocol: u8,
    to_protocol: u8,
    amount: u64,
    expected_apy_gain: u64,
    reason: std::string::String,
}

public struct RebalanceExecuted has copy, drop {
    from_protocol: u8,
    to_protocol: u8,
    amount: u64,
    old_apy: u64,
    new_apy: u64,
    epoch: u64,
}

public struct RebalanceProposed has copy, drop {
    from_protocol: u8,
    to_protocol: u8,
    amount: u64,
    apy_difference: u64,
}

public fun initialize(
    rebalance_threshold: u64,
    min_rebalance_amount: u64,
    rebalance_interval: u64,
    ctx: &mut TxContext,
) {
    let config = AgentConfig {
        id: object::new(ctx),
        enabled: true,
        rebalance_threshold,
        min_rebalance_amount,
        last_rebalance_epoch: 0,
        rebalance_interval,
        total_rebalances: 0,
    };
    transfer::share_object(config);
}

public fun analyze_rebalance_opportunity<CoinType>(
    config: &AgentConfig,
    registry: &protocol_selector::ProtocolRegistry<CoinType>,
    ctx: &mut TxContext,
): (bool, RebalanceProposal) {
    let current_epoch = tx_context::epoch(ctx);

    if (current_epoch - config.last_rebalance_epoch < config.rebalance_interval) {
        return (false, empty_proposal())
    };

    let protocols = protocol_selector::get_all_protocols(registry);
    let len = vector::length(protocols);

    if (len < 2) {
        return (false, empty_proposal())
    };

    find_rebalance_opportunity(protocols, config, 0, len)
}

fun find_rebalance_opportunity(
    protocols: &vector<ProtocolInfo>,
    config: &AgentConfig,
    i: u64,
    len: u64,
): (bool, RebalanceProposal) {
    if (i < len) {
        let best_protocol = find_best_protocol(protocols, 0, len);
        let worst_protocol = find_worst_protocol(protocols, 0, len);

        let best_apy = staking_protocol::current_apy(&best_protocol);
        let worst_apy = staking_protocol::current_apy(&worst_protocol);

        let apy_diff = if (best_apy > worst_apy) { best_apy - worst_apy } else { 0 };

        if (apy_diff >= config.rebalance_threshold) {
            let proposal = RebalanceProposal {
                from_protocol: staking_protocol::protocol_type(&worst_protocol),
                to_protocol: staking_protocol::protocol_type(&best_protocol),
                amount: config.min_rebalance_amount,
                expected_apy_gain: apy_diff,
                reason: std::string::utf8(b"APY difference exceeds threshold"),
            };
            (true, proposal)
        } else {
            (false, empty_proposal())
        }
    } else {
        (false, empty_proposal())
    }
}

fun find_best_protocol(protocols: &vector<ProtocolInfo>, _i: u64, len: u64): ProtocolInfo {
    if (len == 0) {
        abort E_REBALANCE_NOT_NEEDED
    };

    find_best_loop(protocols, *vector::borrow(protocols, 0), 1, len)
}

fun find_best_loop(
    protocols: &vector<ProtocolInfo>,
    best: ProtocolInfo,
    i: u64,
    len: u64,
): ProtocolInfo {
    if (i < len) {
        let protocol = vector::borrow(protocols, i);
        let new_best = if (
            staking_protocol::is_active(protocol) &&
                staking_protocol::current_apy(protocol) > staking_protocol::current_apy(&best)
        ) {
            *protocol
        } else {
            best
        };
        find_best_loop(protocols, new_best, i + 1, len)
    } else {
        best
    }
}

fun find_worst_protocol(protocols: &vector<ProtocolInfo>, _i: u64, len: u64): ProtocolInfo {
    if (len == 0) {
        abort E_REBALANCE_NOT_NEEDED
    };

    find_worst_loop(protocols, *vector::borrow(protocols, 0), 1, len)
}

fun find_worst_loop(
    protocols: &vector<ProtocolInfo>,
    worst: ProtocolInfo,
    i: u64,
    len: u64,
): ProtocolInfo {
    if (i < len) {
        let protocol = vector::borrow(protocols, i);
        let new_worst = if (
            staking_protocol::is_active(protocol) &&
                staking_protocol::current_apy(protocol) < staking_protocol::current_apy(&worst)
        ) {
            *protocol
        } else {
            worst
        };
        find_worst_loop(protocols, new_worst, i + 1, len)
    } else {
        worst
    }
}

public fun execute_rebalance<CoinType>(
    config: &mut AgentConfig,
    proposal: RebalanceProposal,
    registry: &mut protocol_selector::ProtocolRegistry<CoinType>,
    suilend_state: &mut suilend_adapter::SuilendState<CoinType>,
    haedal_state: &mut haedal_adapter::HaedalState<CoinType>,
    volo_state: &mut volo_adapter::VoloState<CoinType>,
    ctx: &mut TxContext,
) {
    assert!(config.enabled, E_AGENT_NOT_ENABLED);

    let current_epoch = tx_context::epoch(ctx);

    event::emit(RebalanceProposed {
        from_protocol: proposal.from_protocol,
        to_protocol: proposal.to_protocol,
        amount: proposal.amount,
        apy_difference: proposal.expected_apy_gain,
    });

    let withdrawn_coin = protocol_selector::auto_withdraw(
        registry,
        suilend_state,
        haedal_state,
        volo_state,
        proposal.amount,
        ctx,
    );

    let _success = protocol_selector::auto_deposit(
        registry,
        suilend_state,
        haedal_state,
        volo_state,
        withdrawn_coin,
        ctx,
    );

    config.last_rebalance_epoch = current_epoch;
    config.total_rebalances = config.total_rebalances + 1;

    event::emit(RebalanceExecuted {
        from_protocol: proposal.from_protocol,
        to_protocol: proposal.to_protocol,
        amount: proposal.amount,
        old_apy: 0,
        new_apy: proposal.expected_apy_gain,
        epoch: current_epoch,
    });
}

public fun set_enabled(config: &mut AgentConfig, enabled: bool, _ctx: &mut TxContext) {
    config.enabled = enabled;
}

public fun set_threshold(config: &mut AgentConfig, threshold: u64, _ctx: &mut TxContext) {
    config.rebalance_threshold = threshold;
}

public fun get_stats(config: &AgentConfig): (bool, u64, u64, u64) {
    (
        config.enabled,
        config.total_rebalances,
        config.last_rebalance_epoch,
        config.rebalance_threshold,
    )
}

fun empty_proposal(): RebalanceProposal {
    RebalanceProposal {
        from_protocol: 0,
        to_protocol: 0,
        amount: 0,
        expected_apy_gain: 0,
        reason: std::string::utf8(b"No rebalancing needed"),
    }
}
