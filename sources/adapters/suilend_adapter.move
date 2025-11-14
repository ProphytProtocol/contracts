#[allow(duplicate_alias)]
module prophyt::suilend_adapter;

use std::string::{Self, String};
use sui::coin::{Self, Coin};
use sui::object::{Self, UID};
use sui::table::{Self, Table};
use sui::transfer;
use sui::tx_context::TxContext;

const E_INSUFFICIENT_BALANCE: u64 = 1;
const E_INVALID_AMOUNT: u64 = 2;

public struct SuilendState<phantom CoinType> has key {
    id: UID,
    total_deposits: u64,
    total_supplied: u64,
    user_balances: Table<address, u64>,
    current_apy: u64,
    exchange_rate: u64,
    last_update: u64,
}

#[allow(unused_field)]
public struct SuilendReceipt<phantom CoinType> has key, store {
    id: UID,
    _amount: u64,
    _deposited_at: u64,
}

public fun initialize<CoinType>(initial_apy: u64, ctx: &mut TxContext) {
    let state = SuilendState<CoinType> {
        id: object::new(ctx),
        total_deposits: 0,
        total_supplied: 0,
        user_balances: table::new(ctx),
        current_apy: initial_apy,
        exchange_rate: 10000,
        last_update: tx_context::epoch(ctx),
    };
    transfer::share_object(state);
}

public fun deposit<CoinType>(
    state: &mut SuilendState<CoinType>,
    deposit_coin: Coin<CoinType>,
    ctx: &mut TxContext,
): bool {
    let amount = coin::value(&deposit_coin);
    assert!(amount > 0, E_INVALID_AMOUNT);

    let sender = tx_context::sender(ctx);

    if (!table::contains(&state.user_balances, sender)) {
        table::add(&mut state.user_balances, sender, 0);
    };

    let user_balance = table::borrow_mut(&mut state.user_balances, sender);
    *user_balance = *user_balance + amount;

    state.total_deposits = state.total_deposits + amount;
    state.total_supplied = state.total_supplied + amount;

    transfer::public_transfer(deposit_coin, @0x0);

    true
}

public fun withdraw<CoinType>(
    state: &mut SuilendState<CoinType>,
    user_addr: address,
    amount: u64,
    ctx: &mut TxContext,
): Coin<CoinType> {
    assert!(table::contains(&state.user_balances, user_addr), E_INSUFFICIENT_BALANCE);

    let user_balance = table::borrow_mut(&mut state.user_balances, user_addr);
    assert!(*user_balance >= amount, E_INSUFFICIENT_BALANCE);

    *user_balance = *user_balance - amount;
    state.total_supplied = state.total_supplied - amount;

    coin::zero<CoinType>(ctx)
}

public fun get_balance<CoinType>(state: &SuilendState<CoinType>, user_addr: address): u64 {
    if (!table::contains(&state.user_balances, user_addr)) {
        return 0
    };
    *table::borrow(&state.user_balances, user_addr)
}

public fun get_current_apy<CoinType>(state: &SuilendState<CoinType>): u64 {
    state.current_apy
}

public fun get_protocol_name(): String {
    string::utf8(b"Suilend")
}

public fun get_total_tvl<CoinType>(state: &SuilendState<CoinType>): u64 {
    state.total_supplied
}

public fun get_exchange_rate<CoinType>(state: &SuilendState<CoinType>): u64 {
    state.exchange_rate
}

public fun update_apy<CoinType>(
    state: &mut SuilendState<CoinType>,
    new_apy: u64,
    ctx: &mut TxContext,
) {
    state.current_apy = new_apy;
    state.last_update = tx_context::epoch(ctx);
}
