#[allow(duplicate_alias)]
module prophyt::haedal_adapter;

use std::string::{Self, String};
use sui::coin::{Self, Coin};
use sui::object::{Self, UID};
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::TxContext;

const E_INSUFFICIENT_BALANCE: u64 = 1;
const E_INVALID_AMOUNT: u64 = 2;

public struct HaedalState<phantom CoinType> has key {
    id: UID,
    total_staked: u64,
    user_stakes: Table<address, u64>,
    current_apy: u64,
    exchange_rate: u64,
    validator_count: u64,
    whitelist: Table<address, bool>,
    last_update: u64,
}

public fun initialize<CoinType>(initial_apy: u64, ctx: &mut TxContext) {
    let state = HaedalState<CoinType> {
        id: object::new(ctx),
        total_staked: 0,
        user_stakes: table::new(ctx),
        current_apy: initial_apy,
        exchange_rate: 10000,
        validator_count: 10,
        whitelist: table::new(ctx),
        last_update: tx_context::epoch(ctx),
    };
    transfer::share_object(state);
}

public fun deposit<CoinType>(
    state: &mut HaedalState<CoinType>,
    deposit_coin: Coin<CoinType>,
    ctx: &mut TxContext,
): bool {
    let amount = coin::value(&deposit_coin);
    assert!(amount > 0, E_INVALID_AMOUNT);

    let sender = tx_context::sender(ctx);

    // Update user stake
    if (!table::contains(&state.user_stakes, sender)) {
        table::add(&mut state.user_stakes, sender, 0);
    };

    let user_stake = table::borrow_mut(&mut state.user_stakes, sender);
    *user_stake = *user_stake + amount;

    // Update total staked
    state.total_staked = state.total_staked + amount;

    // Transfer to protocol (simulated)
    transfer::public_transfer(deposit_coin, @0x0);

    true
}

public fun withdraw<CoinType>(
    state: &mut HaedalState<CoinType>,
    user_addr: address,
    amount: u64,
    _ctx: &mut TxContext,
): Coin<CoinType> {
    assert!(table::contains(&state.user_stakes, user_addr), E_INSUFFICIENT_BALANCE);

    let user_stake = table::borrow_mut(&mut state.user_stakes, user_addr);
    assert!(*user_stake >= amount, E_INSUFFICIENT_BALANCE);

    *user_stake = *user_stake - amount;
    state.total_staked = state.total_staked - amount;

    // In real integration, unstake from Haedal validators
    coin::zero<CoinType>(_ctx)
}

public fun get_balance<CoinType>(state: &HaedalState<CoinType>, user_addr: address): u64 {
    if (!table::contains(&state.user_stakes, user_addr)) {
        return 0
    };
    *table::borrow(&state.user_stakes, user_addr)
}

public fun get_current_apy<CoinType>(state: &HaedalState<CoinType>): u64 {
    state.current_apy
}

public fun get_protocol_name(): String {
    string::utf8(b"Haedal")
}

public fun get_total_tvl<CoinType>(state: &HaedalState<CoinType>): u64 {
    state.total_staked
}

public fun is_whitelisted<CoinType>(state: &HaedalState<CoinType>, user_addr: address): bool {
    if (!table::contains(&state.whitelist, user_addr)) {
        return true // Open to all by default
    };
    *table::borrow(&state.whitelist, user_addr)
}

public fun add_to_whitelist<CoinType>(
    state: &mut HaedalState<CoinType>,
    user_addr: address,
    _ctx: &mut TxContext,
) {
    if (!table::contains(&state.whitelist, user_addr)) {
        table::add(&mut state.whitelist, user_addr, true);
    } else {
        let whitelisted = table::borrow_mut(&mut state.whitelist, user_addr);
        *whitelisted = true;
    };
}

public fun update_apy<CoinType>(
    state: &mut HaedalState<CoinType>,
    new_apy: u64,
    ctx: &mut TxContext,
) {
    state.current_apy = new_apy;
    state.last_update = tx_context::epoch(ctx);
}

public fun get_validator_count<CoinType>(state: &HaedalState<CoinType>): u64 {
    state.validator_count
}
