#[allow(duplicate_alias)]
module prophyt::access_control;

use sui::object::{Self, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};

const E_NOT_OWNER: u64 = 1;
const E_CONTRACT_PAUSED: u64 = 4;

public struct OwnerCap has key, store {
    id: UID,
    for_contract: address,
}

public struct PausableCap has key, store {
    id: UID,
    is_paused: bool,
}

public fun create_owner_cap(for_contract: address, ctx: &mut TxContext): OwnerCap {
    OwnerCap {
        id: object::new(ctx),
        for_contract,
    }
}

#[allow(lint(self_transfer))]
public fun init_owner_cap(for_contract: address, ctx: &mut TxContext) {
    let cap = OwnerCap {
        id: object::new(ctx),
        for_contract,
    };
    transfer::public_transfer(cap, tx_context::sender(ctx));
}

public fun create_pausable_cap(ctx: &mut TxContext): PausableCap {
    PausableCap {
        id: object::new(ctx),
        is_paused: false,
    }
}

public fun is_owner(cap: &OwnerCap, contract_addr: address): bool {
    cap.for_contract == contract_addr
}

public fun assert_owner(cap: &OwnerCap, contract_addr: address) {
    assert!(is_owner(cap, contract_addr), E_NOT_OWNER);
}

public fun pause(pausable: &mut PausableCap) {
    pausable.is_paused = true;
}

public fun unpause(pausable: &mut PausableCap) {
    pausable.is_paused = false;
}

public fun is_paused(pausable: &PausableCap): bool {
    pausable.is_paused
}

public fun assert_not_paused(pausable: &PausableCap) {
    assert!(!is_paused(pausable), E_CONTRACT_PAUSED);
}

public fun transfer_ownership(cap: OwnerCap, recipient: address) {
    transfer::public_transfer(cap, recipient);
}

public fun get_contract_address(cap: &OwnerCap): address {
    cap.for_contract
}
