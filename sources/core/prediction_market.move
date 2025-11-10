/// Prophyt Prediction Market Module
/// Prediction market with idle funds automatically staked in yield protocols
#[allow(duplicate_alias)]
module prophyt::prediction_market {
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::tx_context::TxContext;
    use sui::object::UID;
    use sui::table::{Self, Table};
    use sui::event;
    use sui::clock::{Self, Clock};
    
    use prophyt::constants;
    use prophyt::access_control::{Self, OwnerCap, PausableCap};
    use prophyt::protocol_selector;
    use prophyt::suilend_adapter;
    use prophyt::haedal_adapter;
    use prophyt::volo_adapter;

    /// Error codes
    const E_MARKET_NOT_FOUND: u64 = 1;
    const E_MARKET_ENDED: u64 = 2;
    const E_MARKET_NOT_ENDED: u64 = 3;
    const E_MARKET_ALREADY_RESOLVED: u64 = 4;
    const E_INVALID_AMOUNT: u64 = 5;
    const E_INVALID_DURATION: u64 = 6;
    const E_BET_NOT_FOUND: u64 = 7;
    const E_BET_ALREADY_CLAIMED: u64 = 8;
    const E_NOT_BET_OWNER: u64 = 9;
    const E_MARKET_NOT_RESOLVED: u64 = 10;
    const E_MARKET_NOT_ACTIVE: u64 = 11;
    const E_FEE_TOO_HIGH: u64 = 12;
    const E_INSUFFICIENT_AMOUNT: u64 = 13;

    /// Market data structure
    public struct Market has store, copy, drop {
        id: u64,
        question: String,
        description: String,
        end_time: u64,
        resolution_time: u64,
        resolved: bool,
        outcome: bool,
        total_yes_amount: u64,
        total_no_amount: u64,
        total_yield_earned: u64,
        active: bool,
        creator: address,
    }

    /// Bet data structure
    public struct Bet has store {
        id: u64,
        user: address,
        market_id: u64,
        position: bool,
        amount: u64,
        net_amount: u64,
        transaction_fee_paid: u64,
        timestamp: u64,
        claimed: bool,
        yield_share: u64,
    }

    /// Global prediction market state
    public struct PredictionMarketState<phantom CoinType> has key {
        id: UID,
        markets: Table<u64, Market>,
        market_bets: Table<u64, vector<Bet>>,
        user_bets: Table<address, vector<u64>>,
        next_market_id: u64,
        next_bet_id: u64,
        protocol_fee_percentage: u64,
        transaction_fee_percentage: u64,
        fee_recipient: address,
        total_protocol_fees: u64,
        total_transaction_fees: u64,
        pausable_cap: PausableCap,
    }

    /// Events
    public struct MarketCreated has copy, drop {
        market_id: u64,
        question: String,
        end_time: u64,
        creator: address,
    }

    public struct BetPlaced has copy, drop {
        bet_id: u64,
        market_id: u64,
        user: address,
        position: bool,
        amount: u64,
    }

    public struct MarketResolved has copy, drop {
        market_id: u64,
        outcome: bool,
        total_yield_earned: u64,
    }

    public struct WinningsClaimed has copy, drop {
        bet_id: u64,
        user: address,
        winning_amount: u64,
        yield_share: u64,
    }

    public struct YieldDeposited has copy, drop {
        market_id: u64,
        amount: u64,
    }

    /// Initialize the prediction market
    public fun initialize<CoinType>(
        _owner_cap: &OwnerCap,
        fee_recipient: address,
        protocol_fee_percentage: u64,
        transaction_fee_percentage: u64,
        ctx: &mut TxContext
    ) {
        assert!(protocol_fee_percentage <= constants::max_protocol_fee(), E_FEE_TOO_HIGH);
        assert!(transaction_fee_percentage <= constants::max_transaction_fee(), E_FEE_TOO_HIGH);

        let pausable_cap = access_control::create_pausable_cap(ctx);

        let state = PredictionMarketState<CoinType> {
            id: object::new(ctx),
            markets: table::new(ctx),
            market_bets: table::new(ctx),
            user_bets: table::new(ctx),
            next_market_id: 0,
            next_bet_id: 0,
            protocol_fee_percentage,
            transaction_fee_percentage,
            fee_recipient,
            total_protocol_fees: 0,
            total_transaction_fees: 0,
            pausable_cap,
        };
        
        transfer::share_object(state);
    }

    /// Create a new prediction market
    public fun create_market<CoinType>(
        state: &mut PredictionMarketState<CoinType>,
        _owner_cap: &OwnerCap,
        question: String,
        description: String,
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(duration > 0, E_INVALID_DURATION);

        let market_id = state.next_market_id;
        state.next_market_id = market_id + 1;

        let current_time = clock::timestamp_ms(clock) / 1000;
        let end_time = current_time + duration;

        let market = Market {
            id: market_id,
            question,
            description,
            end_time,
            resolution_time: 0,
            resolved: false,
            outcome: false,
            total_yes_amount: 0,
            total_no_amount: 0,
            total_yield_earned: 0,
            active: true,
            creator: tx_context::sender(ctx),
        };

        table::add(&mut state.markets, market_id, market);
        table::add(&mut state.market_bets, market_id, vector::empty<Bet>());

        event::emit(MarketCreated {
            market_id,
            question: market.question,
            end_time,
            creator: market.creator,
        });
    }

    /// Place a bet on a market
    public fun place_bet<CoinType>(
        state: &mut PredictionMarketState<CoinType>,
        registry: &mut protocol_selector::ProtocolRegistry<CoinType>,
        suilend_state: &mut suilend_adapter::SuilendState<CoinType>,
        haedal_state: &mut haedal_adapter::HaedalState<CoinType>,
        volo_state: &mut volo_adapter::VoloState<CoinType>,
        market_id: u64,
        position: bool,
        bet_coin: Coin<CoinType>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        access_control::assert_not_paused(&state.pausable_cap);

        let amount = coin::value(&bet_coin);
        assert!(amount > 0, E_INVALID_AMOUNT);

        let user_addr = tx_context::sender(ctx);
        assert!(table::contains(&state.markets, market_id), E_MARKET_NOT_FOUND);
        
        let market = table::borrow_mut(&mut state.markets, market_id);
        assert!(market.active, E_MARKET_NOT_ACTIVE);
        
        let current_time = clock::timestamp_ms(clock) / 1000;
        assert!(current_time < market.end_time, E_MARKET_ENDED);

        // Calculate fees
        let transaction_fee = (amount * state.transaction_fee_percentage) / constants::basis_points();
        let net_amount = amount - transaction_fee;
        assert!(net_amount > 0, E_INSUFFICIENT_AMOUNT);

        state.total_transaction_fees = state.total_transaction_fees + transaction_fee;

        // Update market totals
        if (position) {
            market.total_yes_amount = market.total_yes_amount + net_amount;
        } else {
            market.total_no_amount = market.total_no_amount + net_amount;
        };

        // Create bet record
        let bet_id = state.next_bet_id;
        state.next_bet_id = bet_id + 1;

        let bet = Bet {
            id: bet_id,
            user: user_addr,
            market_id,
            position,
            amount,
            net_amount,
            transaction_fee_paid: transaction_fee,
            timestamp: current_time,
            claimed: false,
            yield_share: 0,
        };

        // Add bet to market and user records
        let market_bets = table::borrow_mut(&mut state.market_bets, market_id);
        vector::push_back(market_bets, bet);

        if (!table::contains(&state.user_bets, user_addr)) {
            table::add(&mut state.user_bets, user_addr, vector::empty<u64>());
        };
        let user_bet_list = table::borrow_mut(&mut state.user_bets, user_addr);
        vector::push_back(user_bet_list, bet_id);

        // Auto-deposit to yield protocol
        let success = protocol_selector::auto_deposit(
            registry,
            suilend_state,
            haedal_state,
            volo_state,
            bet_coin,
            ctx
        );
        
        assert!(success, E_INVALID_AMOUNT);

        event::emit(BetPlaced {
            bet_id,
            market_id,
            user: user_addr,
            position,
            amount,
        });

        event::emit(YieldDeposited {
            market_id,
            amount: net_amount,
        });
    }

    /// Resolve a market
    public fun resolve_market<CoinType>(
        state: &mut PredictionMarketState<CoinType>,
        _owner_cap: &OwnerCap,
        registry: &protocol_selector::ProtocolRegistry<CoinType>,
        suilend_state: &suilend_adapter::SuilendState<CoinType>,
        haedal_state: &haedal_adapter::HaedalState<CoinType>,
        volo_state: &volo_adapter::VoloState<CoinType>,
        market_id: u64,
        outcome: bool,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&state.markets, market_id), E_MARKET_NOT_FOUND);

        // Calculate yield in a separate scope to end borrows
        let (total_bet_amount, final_yield) = {
            let market = table::borrow_mut(&mut state.markets, market_id);
            assert!(market.active, E_MARKET_NOT_ACTIVE);
            
            let current_time = clock::timestamp_ms(clock) / 1000;
            assert!(current_time >= market.end_time, E_MARKET_NOT_ENDED);
            assert!(!market.resolved, E_MARKET_ALREADY_RESOLVED);

            // Store market data
            let total_yes_amount = market.total_yes_amount;
            let total_no_amount = market.total_no_amount;
            
            market.resolved = true;
            market.outcome = outcome;
            market.resolution_time = current_time;

            // Calculate yield earned
            let total_bet_amount = total_yes_amount + total_no_amount;
            let sender = tx_context::sender(ctx);
            let total_balance = protocol_selector::get_total_balance(
                registry,
                sender,
                suilend_state,
                haedal_state,
                volo_state
            );

            let mut total_yield_earned = if (total_balance > total_bet_amount) {
                total_balance - total_bet_amount
            } else {
                0
            };
            
            market.total_yield_earned = total_yield_earned;

            // Deduct protocol fee from yield
            let protocol_fee = (total_yield_earned * state.protocol_fee_percentage) / constants::basis_points();
            if (protocol_fee > 0) {
                state.total_protocol_fees = state.total_protocol_fees + protocol_fee;
                total_yield_earned = total_yield_earned - protocol_fee;
                market.total_yield_earned = total_yield_earned;
            };

            (total_bet_amount, total_yield_earned)
            // market borrow ends here at end of scope
        };
        
        // Calculate yield shares for all bets
        calculate_yield_shares(state, market_id, final_yield, total_bet_amount);

        event::emit(MarketResolved {
            market_id,
            outcome,
            total_yield_earned: final_yield,
        });
    }

    /// Calculate yield shares for all bets
    fun calculate_yield_shares<CoinType>(
        state: &mut PredictionMarketState<CoinType>,
        market_id: u64,
        total_yield: u64,
        total_bet_amount: u64
    ) {
        if (total_yield == 0 || total_bet_amount == 0) {
            return
        };

        let market_bets = table::borrow_mut(&mut state.market_bets, market_id);
        let num_bets = vector::length(market_bets);
        let mut i = 0;

        while (i < num_bets) {
            let bet = vector::borrow_mut(market_bets, i);
            bet.yield_share = (bet.net_amount * total_yield) / total_bet_amount;
            i = i + 1;
        };
    }

    /// Claim winnings from a resolved market
    #[allow(lint(self_transfer))]
    public fun claim_winnings<CoinType>(
        state: &mut PredictionMarketState<CoinType>,
        registry: &protocol_selector::ProtocolRegistry<CoinType>,
        suilend_state: &mut suilend_adapter::SuilendState<CoinType>,
        haedal_state: &mut haedal_adapter::HaedalState<CoinType>,
        volo_state: &mut volo_adapter::VoloState<CoinType>,
        market_id: u64,
        bet_index: u64,
        ctx: &mut TxContext
    ) {
        let user_addr = tx_context::sender(ctx);
        assert!(table::contains(&state.markets, market_id), E_MARKET_NOT_FOUND);
        
        let market = table::borrow(&state.markets, market_id);
        assert!(market.resolved, E_MARKET_NOT_RESOLVED);

        let market_bets = table::borrow_mut(&mut state.market_bets, market_id);
        assert!(bet_index < vector::length(market_bets), E_BET_NOT_FOUND);

        let bet = vector::borrow_mut(market_bets, bet_index);
        assert!(bet.user == user_addr, E_NOT_BET_OWNER);
        assert!(!bet.claimed, E_BET_ALREADY_CLAIMED);

        // Calculate winnings
        let winning_amount = if (bet.position == market.outcome) {
            let winning_pool = if (bet.position) {
                market.total_yes_amount
            } else {
                market.total_no_amount
            };

            let losing_pool = if (bet.position) {
                market.total_no_amount
            } else {
                market.total_yes_amount
            };

            if (winning_pool > 0) {
                let share = (bet.net_amount * losing_pool) / winning_pool;
                bet.net_amount + share
            } else {
                bet.net_amount
            }
        } else {
            0
        };

        let claim_amount = winning_amount + bet.yield_share;
        bet.claimed = true;

        if (claim_amount > 0) {
            // Withdraw from yield protocols
            let claimed_coin = protocol_selector::auto_withdraw(
                registry,
                suilend_state,
                haedal_state,
                volo_state,
                claim_amount,
                ctx
            );
            transfer::public_transfer(claimed_coin, user_addr);
        };

        event::emit(WinningsClaimed {
            bet_id: bet.id,
            user: user_addr,
            winning_amount: claim_amount,
            yield_share: bet.yield_share,
        });
    }

    /// Get market details
    public fun get_market<CoinType>(
        state: &PredictionMarketState<CoinType>,
        market_id: u64
    ): &Market {
        assert!(table::contains(&state.markets, market_id), E_MARKET_NOT_FOUND);
        table::borrow(&state.markets, market_id)
    }

    /// Get market odds
    public fun get_odds<CoinType>(
        state: &PredictionMarketState<CoinType>,
        market_id: u64
    ): (u64, u64) {
        let market = get_market(state, market_id);
        
        if (market.total_yes_amount == 0 && market.total_no_amount == 0) {
            return (50, 50)
        };

        let total = market.total_yes_amount + market.total_no_amount;
        let yes_odds = (market.total_yes_amount * 100) / total;
        let no_odds = (market.total_no_amount * 100) / total;

        (yes_odds, no_odds)
    }

    /// Pause the market
    public fun pause<CoinType>(
        state: &mut PredictionMarketState<CoinType>,
        _owner_cap: &OwnerCap,
        _ctx: &mut TxContext
    ) {
        access_control::pause(&mut state.pausable_cap);
    }

    /// Unpause the market
    public fun unpause<CoinType>(
        state: &mut PredictionMarketState<CoinType>,
        _owner_cap: &OwnerCap,
        _ctx: &mut TxContext
    ) {
        access_control::unpause(&mut state.pausable_cap);
    }
}
