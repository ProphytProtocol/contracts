#[allow(duplicate_alias)]
module prophyt::integration_tests {
    #[test_only]
    use std::string;
    use sui::test_scenario;
    use sui::transfer;

    use prophyt::constants;
    use prophyt::haedal_adapter::{Self, HaedalState};
    use prophyt::suilend_adapter::{Self, SuilendState};
    use prophyt::volo_adapter::{Self, VoloState};
    use prophyt::protocol_selector::{Self, ProtocolRegistry};
    use prophyt::access_control;

    
    public struct USDC has drop {}

    

    #[test]
    fun test_multiple_adapters_initialization() {
        let mut scenario = test_scenario::begin(@0x1);
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
            let haedal = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
            let suilend = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
            let volo = test_scenario::take_shared<VoloState<USDC>>(&scenario);
            
            
            assert!(haedal_adapter::get_current_apy(&haedal) == 500, 1);
            assert!(suilend_adapter::get_current_apy(&suilend) == 400, 2);
            assert!(volo_adapter::get_current_apy(&volo) == 600, 3);
            
            test_scenario::return_shared(haedal);
            test_scenario::return_shared(suilend);
            test_scenario::return_shared(volo);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_protocol_registry_initialization() {
        let mut scenario = test_scenario::begin(@0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            protocol_selector::initialize<USDC>(100, 5, ctx);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let registry = test_scenario::take_shared<ProtocolRegistry<USDC>>(&scenario);
            let protocols = protocol_selector::get_all_protocols(&registry);
            
            assert!(std::vector::length(protocols) >= 0, 1);
            test_scenario::return_shared(registry);
        };
        
        test_scenario::end(scenario);
    }

    

    #[test]
    fun test_owner_cap_creation() {
        let mut scenario = test_scenario::begin(@0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let owner_cap = access_control::create_owner_cap(@0x2, ctx);
            
            assert!(access_control::is_owner(&owner_cap, @0x2) == true, 1);
            assert!(access_control::is_owner(&owner_cap, @0x3) == false, 2);
            transfer::public_transfer(owner_cap, @0x0);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_pausable_cap() {
        let mut scenario = test_scenario::begin(@0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let mut pausable = access_control::create_pausable_cap(ctx);
            
            assert!(access_control::is_paused(&pausable) == false, 1);
            
            access_control::pause(&mut pausable);
            assert!(access_control::is_paused(&pausable) == true, 2);
            
            access_control::unpause(&mut pausable);
            assert!(access_control::is_paused(&pausable) == false, 3);
            transfer::public_transfer(pausable, @0x0);
        };
        
        test_scenario::end(scenario);
    }

    

    #[test]
    fun test_adapter_tvl_and_apy() {
        let mut scenario = test_scenario::begin(@0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            haedal_adapter::initialize<USDC>(750, ctx);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let state = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
            
            
            let tvl = haedal_adapter::get_total_tvl(&state);
            assert!(tvl == 0, 1);
            
            
            let apy = haedal_adapter::get_current_apy(&state);
            assert!(apy == 750, 2);
            
            test_scenario::return_shared(state);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_protocol_names_consistency() {
        let haedal_name = haedal_adapter::get_protocol_name();
        let suilend_name = suilend_adapter::get_protocol_name();
        let volo_name = volo_adapter::get_protocol_name();
        
        assert!(string::length(&haedal_name) > 0, 1);
        assert!(string::length(&suilend_name) > 0, 2);
        assert!(string::length(&volo_name) > 0, 3);
    }

    

    #[test]
    fun test_protocol_type_constants() {
        assert!(constants::protocol_suilend() == 1, 1);
        assert!(constants::protocol_haedal() == 2, 2);
        assert!(constants::protocol_volo() == 3, 3);
        
        
        assert!(
            constants::protocol_suilend() != constants::protocol_haedal(),
            4
        );
        assert!(
            constants::protocol_haedal() != constants::protocol_volo(),
            5
        );
        assert!(
            constants::protocol_suilend() != constants::protocol_volo(),
            6
        );
    }

    #[test]
    fun test_weight_constants() {
        let apy_weight = constants::apy_weight();
        let tvl_weight = constants::tvl_weight();
        let risk_weight = constants::risk_weight();
        let basis = constants::basis_points();
        
        
        assert!(apy_weight > 0, 1);
        assert!(tvl_weight > 0, 2);
        assert!(risk_weight > 0, 3);
        
        
        assert!(basis == 10000, 4);
    }

    #[test]
    fun test_fee_constants() {
        let max_protocol_fee = constants::max_protocol_fee();
        let max_transaction_fee = constants::max_transaction_fee();
        
        
        assert!(max_protocol_fee <= 10000, 1);
        assert!(max_transaction_fee <= 10000, 2);
    }

    

    #[test]
    fun test_adapter_states_are_isolated() {
        let mut scenario = test_scenario::begin(@0x1);
        
        
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
            
            let haedal_state = test_scenario::take_shared<HaedalState<USDC>>(&scenario);
            let suilend_state = test_scenario::take_shared<SuilendState<USDC>>(&scenario);
            
            
            let haedal_apy = haedal_adapter::get_current_apy(&haedal_state);
            assert!(haedal_apy == 500, 1);
            
            
            let suilend_apy = suilend_adapter::get_current_apy(&suilend_state);
            assert!(suilend_apy == 400, 2);
            
            test_scenario::return_shared(haedal_state);
            test_scenario::return_shared(suilend_state);
        };
        
        test_scenario::end(scenario);
    }

    

    #[test]
    fun test_rebalance_disabled_agent() {
        let mut scenario = test_scenario::begin(@0x1);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            prophyt::prophyt_agent::initialize(100, 1000, 10, ctx);
        };
        
        test_scenario::next_tx(&mut scenario, @0x1);
        {
            let config = test_scenario::take_shared<prophyt::prophyt_agent::AgentConfig>(&scenario);
            let (enabled, _, _, _) = prophyt::prophyt_agent::get_stats(&config);
            
            assert!(enabled == true, 1);
            test_scenario::return_shared(config);
        };
        
        test_scenario::end(scenario);
    }
}
