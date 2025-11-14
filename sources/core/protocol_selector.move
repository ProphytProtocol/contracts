#[allow(duplicate_alias)]
module prophyt::protocol_selector;

use prophyt::constants;
use prophyt::haedal_adapter;
use prophyt::staking_protocol::{Self, ProtocolInfo};
use prophyt::suilend_adapter;
use prophyt::volo_adapter;
use std::string::String;
use std::vector;
use sui::coin::{Self, Coin};
use sui::event;
use sui::object::{Self, UID, ID};
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::TxContext;

const E_NO_PROTOCOLS_AVAILABLE: u64 = 1;

public struct ProtocolRegistry<phantom CoinType> has key {
    id: UID,
    available_protocols: vector<ProtocolInfo>,
    protocol_states: Table<u8, ID>,
    auto_selection_enabled: bool,
    min_apy_threshold: u64,
    max_risk_tolerance: u8,
    total_deposited: u64,
    last_rebalance: u64,
}

public struct ProtocolRegistered has copy, drop {
    protocol_type: u8,
    protocol_address: address,
    name: String,
    apy: u64,
}

public struct ProtocolSelected has copy, drop {
    protocol_type: u8,
    protocol_address: address,
    score: u64,
    reason: String,
}

public struct FundsDeposited has copy, drop {
    protocol_type: u8,
    amount: u64,
    user: address,
}

public struct FundsWithdrawn has copy, drop {
    protocol_type: u8,
    amount: u64,
    user: address,
}

public fun initialize<CoinType>(
    min_apy_threshold: u64,
    max_risk_tolerance: u8,
    ctx: &mut TxContext,
) {
    let registry = ProtocolRegistry<CoinType> {
        id: object::new(ctx),
        available_protocols: vector::empty(),
        protocol_states: table::new(ctx),
        auto_selection_enabled: true,
        min_apy_threshold,
        max_risk_tolerance,
        total_deposited: 0,
        last_rebalance: tx_context::epoch(ctx),
    };
    transfer::share_object(registry);
}

public fun register_protocol<CoinType>(
    registry: &mut ProtocolRegistry<CoinType>,
    protocol_type: u8,
    protocol_address: address,
    state_id: ID,
    risk_level: u8,
    ctx: &mut TxContext,
) {
    let (name, current_apy, tvl) = get_protocol_details(protocol_type, protocol_address);

    let protocol_info = staking_protocol::new_protocol_info(
        protocol_type,
        protocol_address,
        current_apy,
        name,
        tvl,
        risk_level,
        0,
        tx_context::epoch(ctx),
    );

    vector::push_back(&mut registry.available_protocols, protocol_info);
    table::add(&mut registry.protocol_states, protocol_type, state_id);

    event::emit(ProtocolRegistered {
        protocol_type,
        protocol_address,
        name,
        apy: current_apy,
    });
}

public fun select_best_protocol<CoinType>(
    registry: &mut ProtocolRegistry<CoinType>,
    _ctx: &mut TxContext,
): ProtocolInfo {
    assert!(vector::length(&registry.available_protocols) > 0, E_NO_PROTOCOLS_AVAILABLE);

    update_all_protocol_info(registry);

    let best_protocol = *vector::borrow(&registry.available_protocols, 0);
    let best_score = calculate_protocol_score(&best_protocol);
    let len = vector::length(&registry.available_protocols);
    let i = 1;

    select_best_loop(registry, best_protocol, best_score, i, len)
}

fun select_best_loop<CoinType>(
    registry: &ProtocolRegistry<CoinType>,
    best_protocol: ProtocolInfo,
    best_score: u64,
    i: u64,
    len: u64,
): ProtocolInfo {
    if (i < len) {
        let protocol = vector::borrow(&registry.available_protocols, i);
        let (new_best, new_score) = if (
            staking_protocol::is_active(protocol) &&
                staking_protocol::current_apy(protocol) >= registry.min_apy_threshold &&
                staking_protocol::risk_level(protocol) <= registry.max_risk_tolerance
        ) {
            let score = calculate_protocol_score(protocol);
            if (score > best_score) {
                (*protocol, score)
            } else {
                (best_protocol, best_score)
            }
        } else {
            (best_protocol, best_score)
        };
        select_best_loop(registry, new_best, new_score, i + 1, len)
    } else {
        event::emit(ProtocolSelected {
            protocol_type: staking_protocol::protocol_type(&best_protocol),
            protocol_address: staking_protocol::protocol_address(&best_protocol),
            score: best_score,
            reason: std::string::utf8(b"Highest score based on APY, TVL, and risk"),
        });
        best_protocol
    }
}

#[allow(lint(self_transfer))]
public fun auto_deposit<CoinType>(
    registry: &mut ProtocolRegistry<CoinType>,
    suilend_state: &mut suilend_adapter::SuilendState<CoinType>,
    haedal_state: &mut haedal_adapter::HaedalState<CoinType>,
    volo_state: &mut volo_adapter::VoloState<CoinType>,
    deposit_coin: Coin<CoinType>,
    ctx: &mut TxContext,
): bool {
    let amount = coin::value(&deposit_coin);
    let user_addr = tx_context::sender(ctx);

    let best_protocol = select_best_protocol(registry, ctx);
    let protocol_type = staking_protocol::protocol_type(&best_protocol);

    let success = if (protocol_type == constants::protocol_suilend()) {
        suilend_adapter::deposit(suilend_state, deposit_coin, ctx)
    } else if (protocol_type == constants::protocol_haedal()) { if (haedal_adapter::is_whitelisted(haedal_state, user_addr)) {
            haedal_adapter::deposit(haedal_state, deposit_coin, ctx)
        } else { suilend_adapter::deposit(suilend_state, deposit_coin, ctx) } } else if (protocol_type == constants::protocol_volo()) {
        volo_adapter::deposit(volo_state, deposit_coin, ctx)
    } else {
        transfer::public_transfer(deposit_coin, user_addr);
        false
    };

    if (success) {
        registry.total_deposited = registry.total_deposited + amount;
        event::emit(FundsDeposited {
            protocol_type,
            amount,
            user: user_addr,
        });
    };

    success
}

public fun auto_withdraw<CoinType>(
    registry: &ProtocolRegistry<CoinType>,
    suilend_state: &mut suilend_adapter::SuilendState<CoinType>,
    haedal_state: &mut haedal_adapter::HaedalState<CoinType>,
    volo_state: &mut volo_adapter::VoloState<CoinType>,
    amount: u64,
    ctx: &mut TxContext,
): Coin<CoinType> {
    let user_addr = tx_context::sender(ctx);
    let len = vector::length(&registry.available_protocols);
    withdraw_from_protocols(
        registry,
        suilend_state,
        haedal_state,
        volo_state,
        amount,
        user_addr,
        0,
        len,
        ctx,
    )
}

fun withdraw_from_protocols<CoinType>(
    registry: &ProtocolRegistry<CoinType>,
    suilend_state: &mut suilend_adapter::SuilendState<CoinType>,
    haedal_state: &mut haedal_adapter::HaedalState<CoinType>,
    volo_state: &mut volo_adapter::VoloState<CoinType>,
    amount: u64,
    user_addr: address,
    i: u64,
    len: u64,
    ctx: &mut TxContext,
): Coin<CoinType> {
    if (i < len) {
        let protocol = vector::borrow(&registry.available_protocols, i);
        let protocol_type = staking_protocol::protocol_type(protocol);

        if (staking_protocol::is_active(protocol)) {
            let balance = get_balance_for_protocol<CoinType>(
                protocol_type,
                user_addr,
                suilend_state,
                haedal_state,
                volo_state,
            );

            if (balance >= amount) {
                let withdrawn_coin = if (protocol_type == constants::protocol_suilend()) {
                    suilend_adapter::withdraw(suilend_state, user_addr, amount, ctx)
                } else if (protocol_type == constants::protocol_haedal()) {
                    haedal_adapter::withdraw(haedal_state, user_addr, amount, ctx)
                } else if (protocol_type == constants::protocol_volo()) {
                    let shares = (amount * 10000) / balance;
                    volo_adapter::withdraw(volo_state, user_addr, shares, ctx)
                } else {
                    coin::zero<CoinType>(ctx)
                };

                if (coin::value(&withdrawn_coin) > 0) {
                    event::emit(FundsWithdrawn {
                        protocol_type,
                        amount: coin::value(&withdrawn_coin),
                        user: user_addr,
                    });
                    withdrawn_coin
                } else {
                    transfer::public_transfer(withdrawn_coin, user_addr);
                    withdraw_from_protocols(
                        registry,
                        suilend_state,
                        haedal_state,
                        volo_state,
                        amount,
                        user_addr,
                        i + 1,
                        len,
                        ctx,
                    )
                }
            } else {
                withdraw_from_protocols(
                    registry,
                    suilend_state,
                    haedal_state,
                    volo_state,
                    amount,
                    user_addr,
                    i + 1,
                    len,
                    ctx,
                )
            }
        } else {
            withdraw_from_protocols(
                registry,
                suilend_state,
                haedal_state,
                volo_state,
                amount,
                user_addr,
                i + 1,
                len,
                ctx,
            )
        }
    } else {
        coin::zero<CoinType>(ctx)
    }
}

public fun get_total_balance<CoinType>(
    registry: &ProtocolRegistry<CoinType>,
    user_addr: address,
    suilend_state: &suilend_adapter::SuilendState<CoinType>,
    haedal_state: &haedal_adapter::HaedalState<CoinType>,
    volo_state: &volo_adapter::VoloState<CoinType>,
): u64 {
    let len = vector::length(&registry.available_protocols);
    sum_balances(registry, user_addr, suilend_state, haedal_state, volo_state, 0, 0, len)
}

fun sum_balances<CoinType>(
    registry: &ProtocolRegistry<CoinType>,
    user_addr: address,
    suilend_state: &suilend_adapter::SuilendState<CoinType>,
    haedal_state: &haedal_adapter::HaedalState<CoinType>,
    volo_state: &volo_adapter::VoloState<CoinType>,
    total: u64,
    i: u64,
    len: u64,
): u64 {
    if (i < len) {
        let protocol = vector::borrow(&registry.available_protocols, i);
        let new_total = if (staking_protocol::is_active(protocol)) {
            let balance = get_balance_for_protocol<CoinType>(
                staking_protocol::protocol_type(protocol),
                user_addr,
                suilend_state,
                haedal_state,
                volo_state,
            );
            total + balance
        } else {
            total
        };
        sum_balances(
            registry,
            user_addr,
            suilend_state,
            haedal_state,
            volo_state,
            new_total,
            i + 1,
            len,
        )
    } else {
        total
    }
}

fun calculate_protocol_score(protocol: &ProtocolInfo): u64 {
    let apy = staking_protocol::current_apy(protocol);
    let tvl = staking_protocol::tvl(protocol);
    let risk = staking_protocol::risk_level(protocol);

    let apy_score = (apy * constants::apy_weight()) / 100;

    let tvl_score = if (tvl > 1000000000000) {
        (constants::tvl_weight() * 110) / 100
    } else {
        constants::tvl_weight()
    };

    let risk_score = ((11 - (risk as u64)) * constants::risk_weight()) / 10;

    apy_score + tvl_score + risk_score
}

fun update_all_protocol_info<CoinType>(_registry: &mut ProtocolRegistry<CoinType>) {}

fun get_protocol_details(protocol_type: u8, _protocol_address: address): (String, u64, u64) {
    if (protocol_type == constants::protocol_suilend()) {
        (suilend_adapter::get_protocol_name(), 500, 100000000)
    } else if (protocol_type == constants::protocol_haedal()) {
        (haedal_adapter::get_protocol_name(), 750, 80000000)
    } else if (protocol_type == constants::protocol_volo()) {
        (volo_adapter::get_protocol_name(), 650, 120000000)
    } else {
        (std::string::utf8(b"Unknown"), 0, 0)
    }
}

fun get_balance_for_protocol<CoinType>(
    protocol_type: u8,
    user_addr: address,
    suilend_state: &suilend_adapter::SuilendState<CoinType>,
    haedal_state: &haedal_adapter::HaedalState<CoinType>,
    volo_state: &volo_adapter::VoloState<CoinType>,
): u64 {
    if (protocol_type == constants::protocol_suilend()) {
        suilend_adapter::get_balance(suilend_state, user_addr)
    } else if (protocol_type == constants::protocol_haedal()) {
        haedal_adapter::get_balance(haedal_state, user_addr)
    } else if (protocol_type == constants::protocol_volo()) {
        volo_adapter::get_balance(volo_state, user_addr)
    } else {
        0
    }
}

public fun get_all_protocols<CoinType>(
    registry: &ProtocolRegistry<CoinType>,
): &vector<ProtocolInfo> {
    &registry.available_protocols
}

public fun get_current_best_apy<CoinType>(registry: &mut ProtocolRegistry<CoinType>): u64 {
    update_all_protocol_info(registry);
    let len = vector::length(&registry.available_protocols);
    find_best_apy_loop(&registry.available_protocols, 0, 0, len)
}

fun find_best_apy_loop(protocols: &vector<ProtocolInfo>, best_apy: u64, i: u64, len: u64): u64 {
    if (i < len) {
        let protocol = vector::borrow(protocols, i);
        let apy = staking_protocol::current_apy(protocol);
        let new_best = if (staking_protocol::is_active(protocol) && apy > best_apy) {
            apy
        } else {
            best_apy
        };
        find_best_apy_loop(protocols, new_best, i + 1, len)
    } else {
        best_apy
    }
}
