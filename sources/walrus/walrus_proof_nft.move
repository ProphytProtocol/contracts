#[allow(duplicate_alias)]
module prophyt::walrus_proof_nft;

use std::string::String;
use sui::event;
use sui::object::{Self, UID};
use sui::transfer;
use sui::tx_context::TxContext;
use walrus::blob::Blob;

public struct BetProofNFT has key, store {
    id: UID,
    market_id: u64,
    market_question: String,
    bet_id: u64,
    position: bool,
    bet_amount: u64,
    net_amount: u64,
    transaction_fee: u64,
    bet_timestamp: u64,
    bet_proof_blob_address: address,
    image_url: String,
    image_blob_id: String,
    url: String,
    minted_at: u64,
}

public struct WinningProofNFT has key, store {
    id: UID,
    market_id: u64,
    market_question: String,
    bet_id: u64,
    position: bool,
    original_bet_amount: u64,
    winning_amount: u64,
    yield_share: u64,
    profit_percentage: u64,
    resolution_timestamp: u64,
    claimed_timestamp: u64,
    winning_proof_blob_address: address,
    image_url: String,
    image_blob_id: String,
    url: String,
    minted_at: u64,
}

public struct MarketProofNFT has key, store {
    id: UID,
    market_id: u64,
    market_question: String,
    outcome: bool,
    winning_side: bool,
    profit_percentage: u64,
    winning_amount: u64,
    yield_earned: u64,
    proof_blob_address: address,
    resolution_timestamp: u64,
    minted_at: u64,
}

public struct WrappedProofBlob has key {
    id: UID,
    market_id: u64,
    blob: Blob,
    created_at: u64,
}

public struct BetProofNFTMinted has copy, drop {
    market_id: u64,
    bet_id: u64,
    nft_id: address,
    owner: address,
    position: bool,
    bet_amount: u64,
    blob_address: address,
    image_url: String,
    image_blob_id: String,
}

public struct WinningProofNFTMinted has copy, drop {
    market_id: u64,
    bet_id: u64,
    nft_id: address,
    owner: address,
    winning_amount: u64,
    profit_percentage: u64,
    blob_address: address,
    image_url: String,
    image_blob_id: String,
}

public struct ProofNFTMinted has copy, drop {
    market_id: u64,
    nft_id: address,
    owner: address,
    profit_percentage: u64,
    blob_address: address,
}

public struct ProofBlobWrapped has copy, drop {
    market_id: u64,
    blob_object_id: address,
    created_at: u64,
}

public struct ProofNFTBurned has copy, drop {
    nft_id: address,
    market_id: u64,
    owner: address,
}

public fun wrap_proof_blob(
    market_id: u64,
    blob: Blob,
    created_at: u64,
    ctx: &mut TxContext,
): address {
    let wrapped = WrappedProofBlob {
        id: object::new(ctx),
        market_id,
        blob,
        created_at,
    };

    let blob_address = object::id_address(&wrapped);

    transfer::share_object(wrapped);

    event::emit(ProofBlobWrapped {
        market_id,
        blob_object_id: blob_address,
        created_at,
    });

    blob_address
}

public fun mint_bet_proof_nft(
    market_id: u64,
    market_question: String,
    bet_id: u64,
    position: bool,
    bet_amount: u64,
    net_amount: u64,
    transaction_fee: u64,
    bet_timestamp: u64,
    bet_proof_blob_address: address,
    image_url: String,
    image_blob_id: String,
    minted_at: u64,
    recipient: address,
    ctx: &mut TxContext,
): address {
    let nft = BetProofNFT {
        id: object::new(ctx),
        market_id,
        market_question,
        bet_id,
        position,
        bet_amount,
        net_amount,
        transaction_fee,
        bet_timestamp,
        bet_proof_blob_address,
        image_url,
        image_blob_id,
        url: image_url,
        minted_at,
    };

    let nft_id = object::id_address(&nft);

    transfer::public_transfer(nft, recipient);

    event::emit(BetProofNFTMinted {
        market_id,
        bet_id,
        nft_id,
        owner: recipient,
        position,
        bet_amount,
        blob_address: bet_proof_blob_address,
        image_url,
        image_blob_id,
    });

    nft_id
}

public fun mint_winning_proof_nft(
    market_id: u64,
    market_question: String,
    bet_id: u64,
    position: bool,
    original_bet_amount: u64,
    winning_amount: u64,
    yield_share: u64,
    profit_percentage: u64,
    resolution_timestamp: u64,
    claimed_timestamp: u64,
    winning_proof_blob_address: address,
    image_url: String,
    image_blob_id: String,
    minted_at: u64,
    recipient: address,
    ctx: &mut TxContext,
): address {
    let nft = WinningProofNFT {
        id: object::new(ctx),
        market_id,
        market_question,
        bet_id,
        position,
        original_bet_amount,
        winning_amount,
        yield_share,
        profit_percentage,
        resolution_timestamp,
        claimed_timestamp,
        winning_proof_blob_address,
        image_url,
        image_blob_id,
        url: image_url,
        minted_at,
    };

    let nft_id = object::id_address(&nft);

    transfer::public_transfer(nft, recipient);

    event::emit(WinningProofNFTMinted {
        market_id,
        bet_id,
        nft_id,
        owner: recipient,
        winning_amount,
        profit_percentage,
        blob_address: winning_proof_blob_address,
        image_url,
        image_blob_id,
    });

    nft_id
}

public fun mint_proof_nft(
    market_id: u64,
    market_question: String,
    outcome: bool,
    winning_side: bool,
    profit_percentage: u64,
    winning_amount: u64,
    yield_earned: u64,
    proof_blob_address: address,
    resolution_timestamp: u64,
    minted_at: u64,
    recipient: address,
    ctx: &mut TxContext,
): address {
    let nft = MarketProofNFT {
        id: object::new(ctx),
        market_id,
        market_question,
        outcome,
        winning_side,
        profit_percentage,
        winning_amount,
        yield_earned,
        proof_blob_address,
        resolution_timestamp,
        minted_at,
    };

    let nft_id = object::id_address(&nft);

    transfer::public_transfer(nft, recipient);

    event::emit(ProofNFTMinted {
        market_id,
        nft_id,
        owner: recipient,
        profit_percentage,
        blob_address: proof_blob_address,
    });

    nft_id
}

public fun burn_proof_nft(nft: MarketProofNFT, _ctx: &mut TxContext) {
    let market_id = nft.market_id;
    let nft_id = object::id_address(&nft);

    event::emit(ProofNFTBurned {
        nft_id,
        market_id,
        owner: tx_context::sender(_ctx),
    });

    let MarketProofNFT {
        id,
        market_id: _,
        market_question: _,
        outcome: _,
        winning_side: _,
        profit_percentage: _,
        winning_amount: _,
        yield_earned: _,
        proof_blob_address: _,
        resolution_timestamp: _,
        minted_at: _,
    } = nft;

    object::delete(id);
}

public fun market_id(nft: &MarketProofNFT): u64 {
    nft.market_id
}

public fun market_question(nft: &MarketProofNFT): String {
    nft.market_question
}

public fun outcome(nft: &MarketProofNFT): bool {
    nft.outcome
}

public fun winning_side(nft: &MarketProofNFT): bool {
    nft.winning_side
}

public fun profit_percentage(nft: &MarketProofNFT): u64 {
    nft.profit_percentage
}

public fun winning_amount(nft: &MarketProofNFT): u64 {
    nft.winning_amount
}

public fun yield_earned(nft: &MarketProofNFT): u64 {
    nft.yield_earned
}

public fun proof_blob_address(nft: &MarketProofNFT): address {
    nft.proof_blob_address
}

public fun resolution_timestamp(nft: &MarketProofNFT): u64 {
    nft.resolution_timestamp
}

public fun minted_at(nft: &MarketProofNFT): u64 {
    nft.minted_at
}

public fun bet_market_id(nft: &BetProofNFT): u64 {
    nft.market_id
}

public fun bet_market_question(nft: &BetProofNFT): String {
    nft.market_question
}

public fun bet_id(nft: &BetProofNFT): u64 {
    nft.bet_id
}

public fun bet_position(nft: &BetProofNFT): bool {
    nft.position
}

public fun bet_amount(nft: &BetProofNFT): u64 {
    nft.bet_amount
}

public fun bet_net_amount(nft: &BetProofNFT): u64 {
    nft.net_amount
}

public fun bet_transaction_fee(nft: &BetProofNFT): u64 {
    nft.transaction_fee
}

public fun bet_timestamp(nft: &BetProofNFT): u64 {
    nft.bet_timestamp
}

public fun bet_proof_blob_address(nft: &BetProofNFT): address {
    nft.bet_proof_blob_address
}

public fun bet_minted_at(nft: &BetProofNFT): u64 {
    nft.minted_at
}

public fun bet_image_url(nft: &BetProofNFT): String {
    nft.image_url
}

public fun bet_image_blob_id(nft: &BetProofNFT): String {
    nft.image_blob_id
}

public fun bet_url(nft: &BetProofNFT): String {
    nft.url
}

public fun winning_market_id(nft: &WinningProofNFT): u64 {
    nft.market_id
}

public fun winning_market_question(nft: &WinningProofNFT): String {
    nft.market_question
}

public fun winning_bet_id(nft: &WinningProofNFT): u64 {
    nft.bet_id
}

public fun winning_position(nft: &WinningProofNFT): bool {
    nft.position
}

public fun winning_original_bet_amount(nft: &WinningProofNFT): u64 {
    nft.original_bet_amount
}

public fun winning_total_amount(nft: &WinningProofNFT): u64 {
    nft.winning_amount
}

public fun winning_yield_share(nft: &WinningProofNFT): u64 {
    nft.yield_share
}

public fun winning_profit_percentage(nft: &WinningProofNFT): u64 {
    nft.profit_percentage
}

public fun winning_resolution_timestamp(nft: &WinningProofNFT): u64 {
    nft.resolution_timestamp
}

public fun winning_claimed_timestamp(nft: &WinningProofNFT): u64 {
    nft.claimed_timestamp
}

public fun winning_proof_blob_address(nft: &WinningProofNFT): address {
    nft.winning_proof_blob_address
}

public fun winning_minted_at(nft: &WinningProofNFT): u64 {
    nft.minted_at
}

public fun winning_image_url(nft: &WinningProofNFT): String {
    nft.image_url
}

public fun winning_image_blob_id(nft: &WinningProofNFT): String {
    nft.image_blob_id
}

public fun winning_url(nft: &WinningProofNFT): String {
    nft.url
}

public fun blob_market_id(wrapped: &WrappedProofBlob): u64 {
    wrapped.market_id
}

public fun blob(wrapped: &WrappedProofBlob): &Blob {
    &wrapped.blob
}

public fun blob_created_at(wrapped: &WrappedProofBlob): u64 {
    wrapped.created_at
}
