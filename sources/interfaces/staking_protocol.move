module prophyt::staking_protocol;

use std::string::String;

public struct ProtocolInfo has copy, drop, store {
    protocol_type: u8,
    protocol_address: address,
    current_apy: u64,
    name: String,
    tvl: u64,
    risk_level: u8,
    active: bool,
    total_deposits: u64,
    last_updated: u64,
}

public struct ProtocolMetrics has copy, drop, store {
    apy: u64,
    tvl: u64,
    risk_score: u64,
    uptime_score: u64,
    liquidity_score: u64,
}

// Constructor for ProtocolInfo
public fun new_protocol_info(
    protocol_type: u8,
    protocol_address: address,
    current_apy: u64,
    name: String,
    tvl: u64,
    risk_level: u8,
    total_deposits: u64,
    last_updated: u64,
): ProtocolInfo {
    ProtocolInfo {
        protocol_type,
        protocol_address,
        current_apy,
        name,
        tvl,
        risk_level,
        active: true,
        total_deposits,
        last_updated,
    }
}

// Getters for ProtocolInfo
public fun protocol_type(info: &ProtocolInfo): u8 { info.protocol_type }

public fun protocol_address(info: &ProtocolInfo): address { info.protocol_address }

public fun current_apy(info: &ProtocolInfo): u64 { info.current_apy }

public fun name(info: &ProtocolInfo): String { info.name }

public fun tvl(info: &ProtocolInfo): u64 { info.tvl }

public fun risk_level(info: &ProtocolInfo): u8 { info.risk_level }

public fun is_active(info: &ProtocolInfo): bool { info.active }

public fun total_deposits(info: &ProtocolInfo): u64 { info.total_deposits }

public fun last_updated(info: &ProtocolInfo): u64 { info.last_updated }

// Setters for ProtocolInfo (mutable references)
public fun set_active(info: &mut ProtocolInfo, active: bool) {
    info.active = active;
}

public fun update_apy(info: &mut ProtocolInfo, apy: u64) {
    info.current_apy = apy;
}

public fun update_tvl(info: &mut ProtocolInfo, new_tvl: u64) {
    info.tvl = new_tvl;
}

public fun update_deposits(info: &mut ProtocolInfo, deposits: u64) {
    info.total_deposits = deposits;
}

public fun update_timestamp(info: &mut ProtocolInfo, timestamp: u64) {
    info.last_updated = timestamp;
}

// Constructor for ProtocolMetrics
public fun new_protocol_metrics(
    apy: u64,
    tvl: u64,
    risk_score: u64,
    uptime_score: u64,
    liquidity_score: u64,
): ProtocolMetrics {
    ProtocolMetrics {
        apy,
        tvl,
        risk_score,
        uptime_score,
        liquidity_score,
    }
}

// Getters for ProtocolMetrics
public fun apy(metrics: &ProtocolMetrics): u64 { metrics.apy }

public fun tvl_metric(metrics: &ProtocolMetrics): u64 { metrics.tvl }

public fun risk_score(metrics: &ProtocolMetrics): u64 { metrics.risk_score }

public fun uptime_score(metrics: &ProtocolMetrics): u64 { metrics.uptime_score }

public fun liquidity_score(metrics: &ProtocolMetrics): u64 { metrics.liquidity_score }
