/// Market Creation and Betting Test
/// This test demonstrates how to create a market and place a bet
module prophyt::market_creation_test {
    #[test_only]
    use std::string;
    use sui::coin;
    use sui::test_scenario;
    use sui::clock;

    use prophyt::haedal_adapter::{Self, HaedalState};
    use prophyt::suilend_adapter::{Self, SuilendState};
    use prophyt::volo_adapter::{Self, VoloState};
    use prophyt::protocol_selector::{Self, ProtocolRegistry};
    use prophyt::prediction_market::{Self, PredictionMarketState};
    use prophyt::access_control;

    /// Test coin type
    public struct USDC has drop {}

    /// Create market and place bet test
    #[test]
    fun test_create_market_and_place_bet() {
        let mut scenario = test_scenario::begin(@0x1);
        
        // Step 1: Initialize all adapters
        {
            let ctx = test_scenario::ctx(&mut scenario);
            haedal_adapter::initialize<USDC>(500, ctx);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            suilend_adapter::initialize<USDC>(400, ctx);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            volo_adapter::initialize<USDC>(600, 100, ctx);
        };
        
        // Step 2: Initialize protocol registry
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            protocol_selector::initialize<USDC>(100, 5, ctx);
        };
        
        // Step 2b: Register protocols in the registry
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let mut registry = test_scenario::take_shared<ProtocolRegistry<USDC>>(&scenario);
            let suilend = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
            let haedal = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
            let volo = test_scenario::take_shared<VoloState<USDC>>(&scenario);
            
            let suilend_id = sui::object::id(&suilend);
            let haedal_id = sui::object::id(&haedal);
            let volo_id = sui::object::id(&volo);
            
            let ctx = test_scenario::ctx(&mut scenario);
            
            // Register suilend
            protocol_selector::register_protocol<USDC>(
                &mut registry,
                1, // suilend
                @0x1,
                suilend_id,
                1,
                ctx
            );
            
            // Register haedal
            protocol_selector::register_protocol<USDC>(
                &mut registry,
                2, // haedal
                @0x1,
                haedal_id,
                1,
                ctx
            );
            
            // Register volo
            protocol_selector::register_protocol<USDC>(
                &mut registry,
                3, // volo
                @0x1,
                volo_id,
                1,
                ctx
            );
            
            test_scenario::return_shared(registry);
            test_scenario::return_shared(suilend);
            test_scenario::return_shared(haedal);
            test_scenario::return_shared(volo);
        };
        
        // Step 3: Initialize prediction market
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::initialize<USDC>(&owner_cap, @0x1, 100, 50, ctx);
            sui::transfer::public_transfer(owner_cap, @0x1);
        };
        
        // Step 4: Create market
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let mut market_state = test_scenario::take_shared<PredictionMarketState<USDC>>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            
            let question = string::utf8(b"Will Sui reach $10 by end of 2025?");
            let description = string::utf8(b"Sui price prediction market");
            
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::create_market<USDC>(
                &mut market_state,
                &owner_cap,
                question,
                description,
                86400, // 1 day
                &clock,
                ctx
            );
            sui::transfer::public_transfer(owner_cap, @0x1);
            
            // Verify market was created
            let market_data = prediction_market::get_market(&market_state, 0);
            assert!(prediction_market::market_id(market_data) == 0, 1);
            assert!(prediction_market::market_active(market_data) == true, 2);
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(market_state);
        };
        
        // Step 5: Place a bet
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let mut market_state = test_scenario::take_shared<PredictionMarketState<USDC>>(&scenario);
            let mut registry = test_scenario::take_shared<ProtocolRegistry<USDC>>(&scenario);
            let mut suilend = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
            let mut haedal = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
            let mut volo = test_scenario::take_shared<VoloState<USDC>>(&scenario);
            
            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            
            // Create bet coin (10000 USDC)
            let bet_coin = coin::mint_for_testing<USDC>(10000, ctx);
            
            // Place bet
            prediction_market::place_bet<USDC>(
                &mut market_state,
                &mut registry,
                &mut suilend,
                &mut haedal,
                &mut volo,
                0, // market_id
                true, // YES position
                bet_coin,
                &clock,
                ctx
            );
            
            // Verify market has bets
            let market_data = prediction_market::get_market(&market_state, 0);
            assert!(prediction_market::market_total_yes_amount(market_data) > 0, 3);
            
            // Get odds
            let (yes_odds, no_odds) = prediction_market::get_odds(&market_state, 0);
            assert!(yes_odds > 0, 4);
            assert!(no_odds >= 0, 5);
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(market_state);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(suilend);
            test_scenario::return_shared(haedal);
            test_scenario::return_shared(volo);
        };
        
        test_scenario::end(scenario);
    }
    
    /// Test multiple bets on same market
    #[test]
    fun test_multiple_bets_on_market() {
        let mut scenario = test_scenario::begin(@0x1);
        
        // Initialize ecosystem
        {
            let ctx = test_scenario::ctx(&mut scenario);
            haedal_adapter::initialize<USDC>(500, ctx);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            suilend_adapter::initialize<USDC>(400, ctx);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            volo_adapter::initialize<USDC>(600, 100, ctx);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            protocol_selector::initialize<USDC>(100, 5, ctx);
        };
        
        // Register protocols
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let mut registry = test_scenario::take_shared<ProtocolRegistry<USDC>>(&scenario);
            let suilend = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
            let haedal = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
            let volo = test_scenario::take_shared<VoloState<USDC>>(&scenario);
            
            let suilend_id = sui::object::id(&suilend);
            let haedal_id = sui::object::id(&haedal);
            let volo_id = sui::object::id(&volo);
            
            let ctx = test_scenario::ctx(&mut scenario);
            
            protocol_selector::register_protocol<USDC>(&mut registry, 1, @0x1, suilend_id, 1, ctx);
            protocol_selector::register_protocol<USDC>(&mut registry, 2, @0x1, haedal_id, 1, ctx);
            protocol_selector::register_protocol<USDC>(&mut registry, 3, @0x1, volo_id, 1, ctx);
            
            test_scenario::return_shared(registry);
            test_scenario::return_shared(suilend);
            test_scenario::return_shared(haedal);
            test_scenario::return_shared(volo);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::initialize<USDC>(&owner_cap, @0x1, 100, 50, ctx);
            sui::transfer::public_transfer(owner_cap, @0x1);
        };
        
        // Create market
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let mut market_state = test_scenario::take_shared<PredictionMarketState<USDC>>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::create_market<USDC>(
                &mut market_state,
                &owner_cap,
                string::utf8(b"Will BTC reach $100k?"),
                string::utf8(b"Bitcoin price"),
                86400,
                &clock,
                ctx
            );
            sui::transfer::public_transfer(owner_cap, @0x1);
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(market_state);
        };
        
        // Place first bet (YES)
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let mut market_state = test_scenario::take_shared<PredictionMarketState<USDC>>(&scenario);
            let mut registry = test_scenario::take_shared<ProtocolRegistry<USDC>>(&scenario);
            let mut suilend = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
            let mut haedal = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
            let mut volo = test_scenario::take_shared<VoloState<USDC>>(&scenario);
            
            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            
            let bet_coin = coin::mint_for_testing<USDC>(5000, ctx);
            
            prediction_market::place_bet<USDC>(
                &mut market_state,
                &mut registry,
                &mut suilend,
                &mut haedal,
                &mut volo,
                0,
                true,
                bet_coin,
                &clock,
                ctx
            );
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(market_state);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(suilend);
            test_scenario::return_shared(haedal);
            test_scenario::return_shared(volo);
        };
        
        // Place second bet (NO)
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let mut market_state = test_scenario::take_shared<PredictionMarketState<USDC>>(&scenario);
            let mut registry = test_scenario::take_shared<ProtocolRegistry<USDC>>(&scenario);
            let mut suilend = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
            let mut haedal = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
            let mut volo = test_scenario::take_shared<VoloState<USDC>>(&scenario);
            
            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            
            let bet_coin = coin::mint_for_testing<USDC>(3000, ctx);
            
            prediction_market::place_bet<USDC>(
                &mut market_state,
                &mut registry,
                &mut suilend,
                &mut haedal,
                &mut volo,
                0,
                false,
                bet_coin,
                &clock,
                ctx
            );
            
            // Verify both sides have bets
            let market_data = prediction_market::get_market(&market_state, 0);
            assert!(prediction_market::market_total_yes_amount(market_data) > 0, 1);
            assert!(prediction_market::market_total_no_amount(market_data) > 0, 2);
            
            // Get odds - should be around 62.5% YES, 37.5% NO (5000:3000)
            let (yes_odds, no_odds) = prediction_market::get_odds(&market_state, 0);
            assert!(yes_odds > 60, 3);
            assert!(no_odds > 30, 4);
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(market_state);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(suilend);
            test_scenario::return_shared(haedal);
            test_scenario::return_shared(volo);
        };
        
        test_scenario::end(scenario);
    }
}
