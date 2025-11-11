/// Suilend Adapter
/// Adapter for integrating with Suilend lending protocol on Sui
#[allow(duplicate_alias)]
module prophyt::suilend_adapter {
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::transfer;

    /// Error codes
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_INVALID_AMOUNT: u64 = 2;

    /// Mock Suilend state for testing (simulates actual Suilend integration)
    public struct SuilendState<phantom CoinType> has key {
        id: UID,
        total_deposits: u64,
        total_supplied: u64,
        user_balances: Table<address, u64>,
        current_apy: u64,
        exchange_rate: u64, // in basis points
        last_update: u64,
    }

    /// Receipt token representing deposited funds
    #[allow(unused_field)]
    public struct SuilendReceipt<phantom CoinType> has key, store {
        id: UID,
        _amount: u64,
        _deposited_at: u64,
    }

    /// Initialize Suilend adapter state
    public fun initialize<CoinType>(
        initial_apy: u64,
        ctx: &mut TxContext
    ) {
        let state = SuilendState<CoinType> {
            id: object::new(ctx),
            total_deposits: 0,
            total_supplied: 0,
            user_balances: table::new(ctx),
            current_apy: initial_apy,
            exchange_rate: 10000, // 1:1 initially
            last_update: tx_context::epoch(ctx),
        };
        transfer::share_object(state);
    }

    /// Deposit coins into Suilend
    public fun deposit<CoinType>(
        state: &mut SuilendState<CoinType>,
        deposit_coin: Coin<CoinType>,
        ctx: &mut TxContext
    ): bool {
        let amount = coin::value(&deposit_coin);
        assert!(amount > 0, E_INVALID_AMOUNT);

        let sender = tx_context::sender(ctx);
        
        // Update user balance
        if (!table::contains(&state.user_balances, sender)) {
            table::add(&mut state.user_balances, sender, 0);
        };
        
        let user_balance = table::borrow_mut(&mut state.user_balances, sender);
        *user_balance = *user_balance + amount;

        // Update totals
        state.total_deposits = state.total_deposits + amount;
        state.total_supplied = state.total_supplied + amount;

        // Burn the deposited coin (in real integration, transfer to Suilend)
        transfer::public_transfer(deposit_coin, @0x0);

        true
    }

    /// Withdraw coins from Suilend
    public fun withdraw<CoinType>(
        state: &mut SuilendState<CoinType>,
        user_addr: address,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<CoinType> {
        assert!(table::contains(&state.user_balances, user_addr), E_INSUFFICIENT_BALANCE);
        
        let user_balance = table::borrow_mut(&mut state.user_balances, user_addr);
        assert!(*user_balance >= amount, E_INSUFFICIENT_BALANCE);

        *user_balance = *user_balance - amount;
        state.total_supplied = state.total_supplied - amount;

        // In real integration, withdraw from Suilend
        // For now, mint new coins (simulation)
        coin::zero<CoinType>(ctx)
    }

    /// Get user balance in Suilend
    public fun get_balance<CoinType>(
        state: &SuilendState<CoinType>,
        user_addr: address
    ): u64 {
        if (!table::contains(&state.user_balances, user_addr)) {
            return 0
        };
        *table::borrow(&state.user_balances, user_addr)
    }

    /// Get current APY
    public fun get_current_apy<CoinType>(state: &SuilendState<CoinType>): u64 {
        state.current_apy
    }

    /// Get protocol name
    public fun get_protocol_name(): String {
        string::utf8(b"Suilend")
    }

    /// Get total value locked
    public fun get_total_tvl<CoinType>(state: &SuilendState<CoinType>): u64 {
        state.total_supplied
    }

    /// Get exchange rate
    public fun get_exchange_rate<CoinType>(state: &SuilendState<CoinType>): u64 {
        state.exchange_rate
    }

    /// Update APY (admin function)
    public fun update_apy<CoinType>(
        state: &mut SuilendState<CoinType>,
        new_apy: u64,
        ctx: &mut TxContext
    ) {
        state.current_apy = new_apy;
        state.last_update = tx_context::epoch(ctx);
    }
}
