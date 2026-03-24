# XAUUSD M1 Scalper EA

Version: `M1 Version 1`

This is a dedicated high-frequency Expert Advisor engineered strictly for the **M1 timeframe** on XAUUSD. It leverages explosive short-term momentum using high-risk (up to 10%), high-reward (1:3 RR) principles to rapidly scale small account balances.

## Core Mechanics

### 1. The Strategy (EMA + RSI Momentum Pullbacks)
Unlike the multi-factor EA, this system relies purely on split-second momentum and deep pullbacks:
- **Trend Confirmation:** Price must be on the correct side of the `EMA 50`.
- **Momentum Burst:** `EMA 20` must have crossed the `EMA 50` aggressively.
- **RSI Velocity:** RSI(14) must reside in a strong but non-exhausted zone (`50-70` for Buys, `30-50` for Sells).
- **The Trigger:** The actual entry is sparked when price sharply pulls back toward the `EMA 20`, entering at a mathematical discount while the trend holds.

### 2. Risk Engine & SL Shrinking
Trading small accounts ($100) mathematically conflicts with Gold's standard contract limits (`0.01` min lot). This usually results in small accounts assuming 20%+ risk.

To achieve exactly 10% risk without missing setups:
- The EA calculates expected loss at `0.01` lots.
- If the expected loss exceeds your defined 10% cash equivalent, the EA **DOES NOT reject the trade**.
- Instead, it recalculates and **shrinks the physical Stop Loss** closer to the entry price until the maximum loss guarantees exactly 10% risk.

### 3. The 1:3 RR Mandate
This EA forces a strict `1:3 Reward-to-Risk` target on every trade. 
If the Stop Loss is dynamically shrunk to protect the account, the Take Profit distance is simultaneously derived from the newly shrunk SL size to preserve exactly 1:3 RR.

### 4. Trade Management
Profits on the M1 timeframe evaporate in seconds. To prevent profitable strikes from reversing:
- **The 5% Account Trigger:** The EA monitors the live monetary profit of the trade.
- **The 1% Lock:** The absolute millisecond profit hits 5% of the total account balance, the SL is dragged deep into profit to permanently secure 1% of the account.
- **ATR Trailing:** Once the 1% buffer is locked, the EA activates a trailing stop using an ATR Multiplier to squeeze every last drop out of runaway momentum spikes.

### 5. Additional Filters
- **Session Filter:** Only trades during London (08:00–13:00) and New York (13:00–22:00) sessions, avoiding Asian session spread spikes.
- **Dynamic Spread Filter:** Maximum spread is dynamically clamped to `0.5 x ATR` (capped by `InpMaxSpreadPoints`), ensuring trades only execute when the spread is a tiny fraction of the expected movement.

### Inputs & Customization
- `InpMaxRiskPercent`: Set this to `10.0` for aggressive growth, or lower it for standard risk modeling.
- `InpProfitLockTriggerPct` & `InpProfitLockTargetPct`: Defaulted to lock `1.0%` at `5.0%`.
- `InpCooldownSeconds`: Prevents rapid "machine-gun" firing by enforcing a 60-second cooldown period after executing an order.

### MT5 Tester Guidelines
- Must be tested on `M1` timeframe.
- Must use `Every tick based on real ticks` modeling. (The Profit Lock evaluates on a per-tick basis to capture lightning-fast spikes).

### Visuals & Logging
- The EA perfectly inherits the **Visual Dashboard** and **CSV Logging Engine** from the M5 Adaptive EA.
- It generates a 0–100 pseudo-score based on its M1 internal conditions (Trend + Momentum + RSI + Pullback + Gap + Candle) for seamless visual parity.
- Uses identical `[GoldEA]` prefix formatting and `DecisionContext` logic so your log files remain consistently readable.
