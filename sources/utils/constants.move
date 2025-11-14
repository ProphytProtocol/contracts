module prophyt::constants;

const PROTOCOL_SUILEND: u8 = 1;
const PROTOCOL_HAEDAL: u8 = 2;
const PROTOCOL_VOLO: u8 = 3;

const MAX_PROTOCOL_FEE: u64 = 2000;
const MAX_TRANSACTION_FEE: u64 = 1000;
const BASIS_POINTS: u64 = 10000;
const DEFAULT_YIELD_FEE: u64 = 2000;
const DEFAULT_TRANSACTION_FEE: u64 = 100;

const RISK_LEVEL_LOW: u8 = 1;
const RISK_LEVEL_MEDIUM: u8 = 5;
const RISK_LEVEL_HIGH: u8 = 10;

const MIN_REBALANCE_THRESHOLD: u64 = 200;
const MIN_REBALANCE_AMOUNT: u64 = 1000000;

const APY_WEIGHT: u64 = 60;
const TVL_WEIGHT: u64 = 20;
const RISK_WEIGHT: u64 = 20;

public fun protocol_suilend(): u8 { PROTOCOL_SUILEND }

public fun protocol_haedal(): u8 { PROTOCOL_HAEDAL }

public fun protocol_volo(): u8 { PROTOCOL_VOLO }

public fun max_protocol_fee(): u64 { MAX_PROTOCOL_FEE }

public fun max_transaction_fee(): u64 { MAX_TRANSACTION_FEE }

public fun basis_points(): u64 { BASIS_POINTS }

public fun default_yield_fee(): u64 { DEFAULT_YIELD_FEE }

public fun default_transaction_fee(): u64 { DEFAULT_TRANSACTION_FEE }

public fun risk_level_low(): u8 { RISK_LEVEL_LOW }

public fun risk_level_medium(): u8 { RISK_LEVEL_MEDIUM }

public fun risk_level_high(): u8 { RISK_LEVEL_HIGH }

public fun min_rebalance_threshold(): u64 { MIN_REBALANCE_THRESHOLD }

public fun min_rebalance_amount(): u64 { MIN_REBALANCE_AMOUNT }

public fun apy_weight(): u64 { APY_WEIGHT }

public fun tvl_weight(): u64 { TVL_WEIGHT }

public fun risk_weight(): u64 { RISK_WEIGHT }
