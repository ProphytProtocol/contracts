/// Access Control Module
/// Provides owner capabilities and pausable functionality for protocol contracts
#[allow(duplicate_alias)]
module prophyt::access_control {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;

    /// Error codes
    const E_NOT_OWNER: u64 = 1;
    const E_CONTRACT_PAUSED: u64 = 4;

    /// Owner capability - proof of ownership
    public struct OwnerCap has key, store {
        id: UID,
        for_contract: address, // Address of the contract this capability controls
    }

    /// Pausable capability - allows pausing contract operations
    public struct PausableCap has key, store {
        id: UID,
        is_paused: bool,
    }

    /// Initialize owner capability
    public fun create_owner_cap(for_contract: address, ctx: &mut TxContext): OwnerCap {
        OwnerCap {
            id: object::new(ctx),
            for_contract,
        }
    }

    /// Initialize and transfer owner capability to caller
    public fun init_owner_cap(for_contract: address, ctx: &mut TxContext) {
        let cap = OwnerCap {
            id: object::new(ctx),
            for_contract,
        };
        transfer::public_transfer(cap, tx_context::sender(ctx));
    }

    /// Initialize pausable capability
    public fun create_pausable_cap(ctx: &mut TxContext): PausableCap {
        PausableCap {
            id: object::new(ctx),
            is_paused: false,
        }
    }

    /// Check if caller is owner
    public fun is_owner(cap: &OwnerCap, contract_addr: address): bool {
        cap.for_contract == contract_addr
    }

    /// Assert that the capability is for the given contract
    public fun assert_owner(cap: &OwnerCap, contract_addr: address) {
        assert!(is_owner(cap, contract_addr), E_NOT_OWNER);
    }

    /// Pause the contract
    public fun pause(pausable: &mut PausableCap) {
        pausable.is_paused = true;
    }

    /// Unpause the contract
    public fun unpause(pausable: &mut PausableCap) {
        pausable.is_paused = false;
    }

    /// Check if contract is paused
    public fun is_paused(pausable: &PausableCap): bool {
        pausable.is_paused
    }

    /// Assert that the contract is not paused
    public fun assert_not_paused(pausable: &PausableCap) {
        assert!(!is_paused(pausable), E_CONTRACT_PAUSED);
    }

    /// Transfer owner capability to a new address
    public fun transfer_ownership(cap: OwnerCap, recipient: address) {
        transfer::public_transfer(cap, recipient);
    }

    /// Get the contract address this capability controls
    public fun get_contract_address(cap: &OwnerCap): address {
        cap.for_contract
    }
}
