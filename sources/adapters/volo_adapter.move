#[allow(duplicate_alias)]
module prophyt::volo_adapter;

use std::string::{Self, String};
use sui::coin::{Self, Coin};
use sui::object::{Self, UID};
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::TxContext;
use sui::vec_map::{Self, VecMap};

const E_INSUFFICIENT_BALANCE: u64 = 1;
const E_INVALID_AMOUNT: u64 = 2;
const E_STRATEGY_NOT_FOUND: u64 = 3;

public struct YieldStrategy has copy, drop, store {
    id: u64,
    name: String,
    target_apy: u64,
    allocated_amount: u64,
    active: bool,
}

public struct VoloState<phantom CoinType> has key {
    id: UID,
    total_deposits: u64,
    user_shares: Table<address, u64>,
    total_shares: u64,
    current_apy: u64,
    strategies: VecMap<u64, YieldStrategy>,
    next_strategy_id: u64,
    performance_fee: u64,
    last_compound: u64,
    last_update: u64,
}

public fun initialize<CoinType>(initial_apy: u64, performance_fee: u64, ctx: &mut TxContext) {
    let state = VoloState<CoinType> {
        id: object::new(ctx),
        total_deposits: 0,
        user_shares: table::new(ctx),
        total_shares: 0,
        current_apy: initial_apy,
        strategies: vec_map::empty(),
        next_strategy_id: 0,
        performance_fee,
        last_compound: tx_context::epoch(ctx),
        last_update: tx_context::epoch(ctx),
    };
    transfer::share_object(state);
}

public fun deposit<CoinType>(
    state: &mut VoloState<CoinType>,
    deposit_coin: Coin<CoinType>,
    ctx: &mut TxContext,
): bool {
    let amount = coin::value(&deposit_coin);
    assert!(amount > 0, E_INVALID_AMOUNT);

    let sender = tx_context::sender(ctx);

    let shares_to_mint = if (state.total_shares == 0) {
        amount
    } else {
        (amount * state.total_shares) / state.total_deposits
    };

    if (!table::contains(&state.user_shares, sender)) {
        table::add(&mut state.user_shares, sender, 0);
    };

    let user_shares = table::borrow_mut(&mut state.user_shares, sender);
    *user_shares = *user_shares + shares_to_mint;

    state.total_shares = state.total_shares + shares_to_mint;
    state.total_deposits = state.total_deposits + amount;

    transfer::public_transfer(deposit_coin, @0x0);

    true
}

public fun withdraw<CoinType>(
    state: &mut VoloState<CoinType>,
    user_addr: address,
    shares: u64,
    _ctx: &mut TxContext,
): Coin<CoinType> {
    assert!(table::contains(&state.user_shares, user_addr), E_INSUFFICIENT_BALANCE);

    let user_shares = table::borrow_mut(&mut state.user_shares, user_addr);
    assert!(*user_shares >= shares, E_INSUFFICIENT_BALANCE);

    let amount = (shares * state.total_deposits) / state.total_shares;

    *user_shares = *user_shares - shares;
    state.total_shares = state.total_shares - shares;
    state.total_deposits = state.total_deposits - amount;

    coin::zero<CoinType>(_ctx)
}

public fun get_balance<CoinType>(state: &VoloState<CoinType>, user_addr: address): u64 {
    if (!table::contains(&state.user_shares, user_addr)) {
        return 0
    };

    let user_shares = *table::borrow(&state.user_shares, user_addr);
    if (state.total_shares == 0) {
        return 0
    };

    (user_shares * state.total_deposits) / state.total_shares
}

public fun get_current_apy<CoinType>(state: &VoloState<CoinType>): u64 {
    state.current_apy
}

public fun get_protocol_name(): String {
    string::utf8(b"Volo")
}

public fun get_total_tvl<CoinType>(state: &VoloState<CoinType>): u64 {
    state.total_deposits
}

public fun add_strategy<CoinType>(
    state: &mut VoloState<CoinType>,
    name: String,
    target_apy: u64,
    _ctx: &mut TxContext,
) {
    let strategy = YieldStrategy {
        id: state.next_strategy_id,
        name,
        target_apy,
        allocated_amount: 0,
        active: true,
    };

    vec_map::insert(&mut state.strategies, state.next_strategy_id, strategy);
    state.next_strategy_id = state.next_strategy_id + 1;
}

public fun update_strategy_apy<CoinType>(
    state: &mut VoloState<CoinType>,
    strategy_id: u64,
    new_apy: u64,
    _ctx: &mut TxContext,
) {
    assert!(vec_map::contains(&state.strategies, &strategy_id), E_STRATEGY_NOT_FOUND);

    let strategy = vec_map::get_mut(&mut state.strategies, &strategy_id);
    strategy.target_apy = new_apy;
}

public fun get_all_strategies<CoinType>(state: &VoloState<CoinType>): &VecMap<u64, YieldStrategy> {
    &state.strategies
}

public fun update_apy<CoinType>(
    state: &mut VoloState<CoinType>,
    new_apy: u64,
    ctx: &mut TxContext,
) {
    state.current_apy = new_apy;
    state.last_update = tx_context::epoch(ctx);
}

public fun get_performance_fee<CoinType>(state: &VoloState<CoinType>): u64 {
    state.performance_fee
}
