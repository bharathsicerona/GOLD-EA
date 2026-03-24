# XAUUSD M1 Scalper EA

Version: `M1 Version 1`

This is a dedicated high-frequency Expert Advisor engineered strictly for the `M1` timeframe on XAUUSD. It leverages short-term momentum with high-risk, strict reward-to-risk execution for rapid testing and account growth experiments.

## Core Mechanics

### 1. The Strategy (EMA + RSI Momentum Pullbacks)
Unlike the multi-factor EA, this system relies on fast momentum and deep pullbacks:
- Trend confirmation: price must be on the correct side of the `EMA 50`
- Momentum burst: `EMA 20` must be on the correct side of the `EMA 50`
- RSI velocity: RSI(14) must stay in a strong but non-exhausted zone (`50-70` for buys, `30-50` for sells)
- Trigger: price sharply pulls back toward the `EMA 20`

### 2. Risk Engine & SL Shrinking
Trading small accounts can conflict with Gold's standard minimum lot sizes.

To stay near the configured risk:
- The EA calculates expected loss at the planned stop distance
- If the expected loss exceeds the configured cap, it shrinks the physical stop loss distance
- The take-profit distance is then recalculated to preserve the configured reward-to-risk ratio

### 3. Trade Management
- Account profit lock triggers once floating profit reaches the configured percentage of balance
- ATR-based trailing activates after profit is locked
- Cooldown prevents immediate rapid-fire re-entry

### 4. Additional Filters
- Session filter: trades only during London (`08:00-13:00`) and New York (`13:00-22:00`) sessions
- Dynamic spread filter: maximum spread is clamped against both `InpMaxSpreadPoints` and ATR
- Volatility filter: ATR must stay above the configured minimum threshold

## Inputs & Customization
- `InpMaxRiskPercent`: aggressive risk cap for each trade
- `InpStopAtrMultiplier`: base ATR stop-loss distance
- `InpRewardRiskRatio`: fixed reward-to-risk target
- `InpMinAtrPoints`: minimum ATR needed to allow trading
- `InpMinEmaGapPoints`: minimum EMA separation needed to avoid flat conditions
- `InpCooldownSeconds`: delay before the next entry can be taken

## MT5 Tester Guidelines
- Use the `M1` timeframe
- Use `Every tick based on real ticks`
- Test during London and New York session windows because the EA blocks off-session entries

## Visuals & Logging
- The EA uses the same dashboard style as the main Gold EA project
- It generates a `0-100` pseudo-score for visual decision tracking
- It writes to its own daily CSV log file: `GoldEA_M1_Log_YYYYMMDD.csv`
- Keep the split `.mqh` support files in the same folder as `XAUUSD_M1_Scalper_EA.mq5` when compiling
