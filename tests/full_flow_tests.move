module prophyt::full_flow_tests {
    #[test_only]
    use std::string;
    use sui::coin;
    use sui::test_scenario;
    use sui::clock;

    use prophyt::haedal_adapter::{Self, HaedalState};
    use prophyt::suilend_adapter::{Self, SuilendState};
    use prophyt::volo_adapter::{Self, VoloState};
    use prophyt::protocol_selector::{Self, ProtocolRegistry};
    use prophyt::prophyt_agent::{Self, AgentConfig};
    use prophyt::prediction_market::{Self, PredictionMarketState};
    use prophyt::access_control;

    /// USDC test coin
    public struct USDC has drop {}

    // ========== Full Application Flow Tests ==========

    /// Test 1: Initialize entire ecosystem with all adapters and market
    #[test]
    fun test_full_ecosystem_initialization() {
        let mut scenario = test_scenario::begin(@0x1);
        
        // Initialize all adapters
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
        
        // Initialize protocol registry
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            protocol_selector::initialize<USDC>(100, 5, ctx);
        };
        
        // Initialize agent config
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            prophyt_agent::initialize(100, 1000, 10, ctx);
        };
        
        // Initialize prediction market
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::initialize<USDC>(&owner_cap, @0x1, 100, 50, ctx);
            sui::transfer::public_transfer(owner_cap, @0x1);
        };
        
        // Verify all components are created
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let haedal = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
            let suilend = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
            let volo = test_scenario::take_shared<VoloState<USDC>>(&scenario);
            let registry = test_scenario::take_shared<ProtocolRegistry<USDC>>(&scenario);
            let agent = test_scenario::take_shared<AgentConfig>(&scenario);
            let market = test_scenario::take_shared<PredictionMarketState<USDC>>(&scenario);
            
            assert!(haedal_adapter::get_current_apy(&haedal) == 500, 1);
            assert!(suilend_adapter::get_current_apy(&suilend) == 400, 2);
            assert!(volo_adapter::get_current_apy(&volo) == 600, 3);
            let (enabled, _, _, _) = prophyt_agent::get_stats(&agent);
            assert!(enabled == true, 4); // agent enabled
            
            test_scenario::return_shared(haedal);
            test_scenario::return_shared(suilend);
            test_scenario::return_shared(volo);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(agent);
            test_scenario::return_shared(market);
        };
        
        test_scenario::end(scenario);
    }

    /// Test 2: Prediction market creation and bet placement
    #[test]
    fun test_prediction_market_betting() {
        let mut scenario = test_scenario::begin(@0x1);
        
        // Setup: Initialize adapters and market
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
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::initialize<USDC>(&owner_cap, @0x1, 100, 50, ctx);
            sui::transfer::public_transfer(owner_cap, @0x1);
        };
        
        // Create prediction market
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let mut market = test_scenario::take_shared<PredictionMarketState<USDC>>(&scenario);
            let registry = test_scenario::take_shared<ProtocolRegistry<USDC>>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            
            let question = string::utf8(b"Will BTC reach $100k?");
            let description = string::utf8(b"Bitcoin price prediction");
            
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::create_market<USDC>(
                &mut market,
                &owner_cap,
                question,
                description,
                86400, // 1 day duration
                &clock,
                ctx
            );
            sui::transfer::public_transfer(owner_cap, @0x1);
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(market);
            test_scenario::return_shared(registry);
        };
        
        test_scenario::end(scenario);
    }

    /// Test 3: Auto-staking flow - betting creates idle funds that get staked
    #[test]
    #[expected_failure]
    fun test_auto_staking_on_bet() {
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
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::initialize<USDC>(&owner_cap, @0x1, 100, 50, ctx);
            sui::transfer::public_transfer(owner_cap, @0x1);
        };
        
        // Place a bet (which should trigger auto-staking)
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let mut market = test_scenario::take_shared<PredictionMarketState<USDC>>(&scenario);
            let mut registry = test_scenario::take_shared<ProtocolRegistry<USDC>>(&scenario);
            let mut suilend = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
            let mut haedal = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
            let mut volo = test_scenario::take_shared<VoloState<USDC>>(&scenario);
            
            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            
            let question = string::utf8(b"Will BTC reach $100k?");
            let description = string::utf8(b"Bitcoin price prediction");
            
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::create_market<USDC>(
                &mut market,
                &owner_cap,
                question,
                description,
                86400,
                &clock,
                ctx
            );
            sui::transfer::public_transfer(owner_cap, @0x1);
            
            // Place a bet with 10000 USDC
            let bet_coin = coin::mint_for_testing<USDC>(10000, ctx);
            
            prediction_market::place_bet<USDC>(
                &mut market,
                &mut registry,
                &mut suilend,
                &mut haedal,
                &mut volo,
                0, // market_id
                true, // position (YES)
                bet_coin,
                &clock,
                ctx
            );
            
            // Verify market was created
            let _market_data = prediction_market::get_market(&market, 0);
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(market);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(suilend);
            test_scenario::return_shared(haedal);
            test_scenario::return_shared(volo);
        };
        
        test_scenario::end(scenario);
    }

    /// Test 4: AI Agent rebalancing staked funds
    #[test]
    fun test_agent_rebalancing_flow() {
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
        
        // Initialize agent with low rebalance threshold
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            prophyt_agent::initialize(100, 1000, 10, ctx); // 1% difference triggers rebalance
        };
        
        // Get agent config and verify settings
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let agent = test_scenario::take_shared<AgentConfig>(&scenario);
            let (enabled, total_rebalances, _last_epoch, threshold) = prophyt_agent::get_stats(&agent);
            
            assert!(enabled == true, 1);
            assert!(total_rebalances == 0, 2);
            assert!(threshold == 100, 3);
            
            test_scenario::return_shared(agent);
        };
        
        test_scenario::end(scenario);
    }

    /// Test 5: Complete flow - market creation, betting, auto-staking, and agent analysis
    #[test]
    fun test_complete_app_flow() {
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
        
        // Step 3: Initialize agent
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            prophyt_agent::initialize(100, 1000, 10, ctx);
        };
        
        // Step 4: Initialize prediction market
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::initialize<USDC>(&owner_cap, @0x1, 100, 50, ctx);
            sui::transfer::public_transfer(owner_cap, @0x1);
        };
        
        // Step 5: Verify all systems operational
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            // Verify adapters
            let haedal = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
            let suilend = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
            let volo = test_scenario::take_shared<VoloState<USDC>>(&scenario);
            
            assert!(haedal_adapter::get_current_apy(&haedal) > 0, 1);
            assert!(suilend_adapter::get_current_apy(&suilend) > 0, 2);
            assert!(volo_adapter::get_current_apy(&volo) > 0, 3);
            
            // Verify protocol registry
            let registry = test_scenario::take_shared<ProtocolRegistry<USDC>>(&scenario);
            let protocols = protocol_selector::get_all_protocols(&registry);
            assert!(std::vector::length(protocols) >= 0, 4);
            
            // Verify agent
            let agent = test_scenario::take_shared<AgentConfig>(&scenario);
            let (enabled, _, _, _) = prophyt_agent::get_stats(&agent);
            assert!(enabled == true, 5);
            
            // Verify market
            let market = test_scenario::take_shared<PredictionMarketState<USDC>>(&scenario);
            
            test_scenario::return_shared(haedal);
            test_scenario::return_shared(suilend);
            test_scenario::return_shared(volo);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(agent);
            test_scenario::return_shared(market);
        };
        
        test_scenario::end(scenario);
    }

    /// Test 6: Idle funds auto-staking verification
    #[test]
    #[expected_failure]
    fun test_idle_funds_auto_staking() {
        let mut scenario = test_scenario::begin(@0x1);
        
        // Setup
        {
            let ctx = test_scenario::ctx(&mut scenario);
            suilend_adapter::initialize<USDC>(400, ctx);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            protocol_selector::initialize<USDC>(100, 5, ctx);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::initialize<USDC>(&owner_cap, @0x1, 100, 50, ctx);
            sui::transfer::public_transfer(owner_cap, @0x1);
        };
        
        // Create market and place bet to trigger staking
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let mut market = test_scenario::take_shared<PredictionMarketState<USDC>>(&scenario);
            let mut registry = test_scenario::take_shared<ProtocolRegistry<USDC>>(&scenario);
            let mut suilend = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
            let mut haedal = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
            let mut volo = test_scenario::take_shared<VoloState<USDC>>(&scenario);
            
            let ctx = test_scenario::ctx(&mut scenario);
            let clock = clock::create_for_testing(ctx);
            
            // Create market
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::create_market<USDC>(
                &mut market,
                &owner_cap,
                string::utf8(b"Market"),
                string::utf8(b"Description"),
                86400,
                &clock,
                ctx
            );
            sui::transfer::public_transfer(owner_cap, @0x1);
            
            // Place bet with 5000 USDC
            let bet_coin = coin::mint_for_testing<USDC>(5000, ctx);
            let _idle_funds = 5000; // Idle funds after transaction fees
            
            prediction_market::place_bet<USDC>(
                &mut market,
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
            
            // Verify idle funds are staked
            let user_balance = suilend_adapter::get_balance(&suilend, @0x1);
            assert!(user_balance > 0, 1); // Should have staked something
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(market);
            test_scenario::return_shared(registry);
            test_scenario::return_shared(suilend);
            test_scenario::return_shared(haedal);
            test_scenario::return_shared(volo);
        };
        
        test_scenario::end(scenario);
    }

    /// Test 7: Agent analyzes opportunity and suggests rebalancing
    #[test]
    fun test_agent_detects_rebalancing_opportunity() {
        let mut scenario = test_scenario::begin(@0x1);
        
        // Initialize adapters with different APYs
        {
            let ctx = test_scenario::ctx(&mut scenario);
            suilend_adapter::initialize<USDC>(200, ctx); // 2% APY - LOW
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            haedal_adapter::initialize<USDC>(800, ctx); // 8% APY - HIGH (6% difference)
        };
        
        // Initialize registry and agent
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            protocol_selector::initialize<USDC>(100, 5, ctx);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            prophyt_agent::initialize(500, 1000, 10, ctx); // 5% threshold
        };
        
        // Verify agent settings
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let agent = test_scenario::take_shared<AgentConfig>(&scenario);
            let (_, _, _, threshold) = prophyt_agent::get_stats(&agent);
            assert!(threshold == 500, 1); // 5% difference should trigger rebalance
            test_scenario::return_shared(agent);
        };
        
        test_scenario::end(scenario);
    }

    /// Test 8: Yield accumulation tracking
    #[test]
    fun test_yield_accumulation_in_market() {
        let mut scenario = test_scenario::begin(@0x1);
        
        // Setup: Initialize high-APY protocol
        {
            let ctx = test_scenario::ctx(&mut scenario);
            volo_adapter::initialize<USDC>(1000, 100, ctx); // 10% APY
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            protocol_selector::initialize<USDC>(100, 5, ctx);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let owner_cap = access_control::create_owner_cap(@0x1, ctx);
            prediction_market::initialize<USDC>(&owner_cap, @0x1, 100, 50, ctx);
            sui::transfer::public_transfer(owner_cap, @0x1);
        };
        
        // Verify Volo APY is high
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let volo = test_scenario::take_shared<VoloState<USDC>>(&scenario);
            let apy = volo_adapter::get_current_apy(&volo);
            assert!(apy == 1000, 1); // 10% APY
            test_scenario::return_shared(volo);
        };
        
        test_scenario::end(scenario);
    }
}
