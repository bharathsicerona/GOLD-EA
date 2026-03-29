# M1 Scalper Strategy Analysis (MT5 EA) - Updated

Scope analyzed:
- `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`
- `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh`
- `EAs/M1_Scalper/XAUUSD_M1_Scalper_Indicators.mqh`
- `EAs/M1_Scalper/XAUUSD_M1_Scalper_Management.mqh`
- `EAs/M1_Scalper/XAUUSD_M1_Scalper_Risk.mqh`

## Important wiring note

The active EA runtime path is primarily driven by `XAUUSD_M1_Scalper_EA.mq5` + `XAUUSD_M1_Scalper_Entry.mqh`, while the EA include list points to `XAUUSD_M1_Scalper_HighRisk_Management.mqh` and unified risk include, not the standalone `Management.mqh`/`Risk.mqh` files listed above.

---

## 1) Full execution flow (OnTick -> Entry -> Validation -> Execution -> Management -> Exit)

Text flow diagram:

`OnTick`
-> `EvaluateTickAndDashboard()`
-> if open position:
   - `ManageTrailingStop(ticket, profit)`
   - `UpdateDynamicTP(ticket, profit, initialRisk)`
   - `ExtendTakeProfit(ticket, initialRisk)`
   - return
-> else evaluate entries only on new M1 candle
-> global pre-entry gates:
   - loss-cluster skip counter (`g_skipSignalsRemaining`)
   - cooldown after loss (`IsCooldownActive`)
   - 20-second cooldown after any close (`g_lastCloseTime`)
   - candle-based cooldown (`InpEntryCooldownCandles`)
   - trade frequency cap (max 3 closed deals in last 5 minutes)
-> `ValidateEntry(BUY)`
   - if valid: `ExecuteHighRiskTrade(BUY)` and return
   - else log rejection
-> `ValidateEntry(SELL)`
   - if valid: `ExecuteHighRiskTrade(SELL)` and return
   - else log rejection

Exit/result handling:
- `OnTradeTransaction` tracks closed deals for this magic number
- Updates consecutive loss state, cooldown anchors, win/loss counters
- Removes stored initial-risk map entry for closed position

---

## 2) Entry conditions: hard filters vs scoring logic

### Hard filters (must pass)

From `ValidateEntry()`:

1. Data/indicator availability:
   - needs 2 bars (`CopyRates`)
   - needs EMA20, EMA50, ATR values

2. ATR minimum volatility:
   - reject if `ATR < 1.0`

3. Spread filter:
   - `dynamicSpreadMax = ATR * 0.25 / point`
   - `maxAllowedSpread = max(InpMaxSpreadPoints, dynamicSpreadMax, 500)`
   - reject if current spread exceeds max allowed

4. No EMA-flat hard rejection in active entry model.

### Directional core trigger + scoring (active)

Scoring constants:
- Core trend = `+2`
- Pullback = `+1`
- Momentum (required) = `+2`
- Breakout booster = `+1`
- EMA separation booster = `+1` (directional)

BUY scoring components:
- Core: `EMA20 > EMA50` and `mid >= EMA20 - ATR*0.20`
- Pullback (primary): `mid >= EMA20 - ATR*0.20`
- Momentum (required): `(mid - open0) > ATR*0.10`
- Breakout booster: `mid > prevHigh - ATR*0.02`
- EMA separation booster (directional): `abs(EMA20-EMA50) >= ATR*0.30`

SELL scoring components:
- Core: `EMA20 < EMA50` and `mid <= EMA20 + ATR*0.20`
- Pullback (primary): `mid <= EMA20 + ATR*0.20`
- Momentum (required): `(open0 - mid) > ATR*0.10`
- Breakout booster: `mid < prevLow + ATR*0.02`
- EMA separation booster (directional): same as BUY logic, mapped to trend side

Timing/noise gate:
- Reject as `EARLY_NOISE` when `abs(mid-open0) < ATR*0.03`

Decision per direction:
- Core for that direction must be true
- M5 trend alignment must pass (`M5_TREND_BLOCK` on mismatch) // [SYSTEM ALIGNMENT]
- SELL is temporarily blocked for debug (`SELL_DISABLED_DEBUG`) // [SYSTEM ALIGNMENT]
- Momentum for that direction must be true (`MOMENTUM_WEAK` if false)
- Direction score must be `>= 6` // [SYSTEM ALIGNMENT]
- Direction score must beat opposite side by at least 1 (`DIRECTION_CONFLICT` otherwise)

---

## 3) Logic in simple terms

### What triggers a BUY?

A buy is placed only if:
- no position is open,
- all cooldown/frequency gates pass,
- market has enough volatility and acceptable spread,
- buy core trend condition is true,
- buy score reaches threshold and beats sell score.

### What triggers a SELL?

Mirror of buy using sell core + sell pullback + sell momentum scoring.

### Why are trades skipped?

Common skip paths:
- cooldowns active (loss/time/bar-based),
- too many recent trades,
- low ATR,
- spread too high,
- core directional condition fails,
- score too weak (`SCORE_TOO_LOW`),
- opposite side stronger/conflicting (`DIRECTION_CONFLICT`),
- early candle noise (`EARLY_NOISE`),
- core directional condition fails,
- margin insufficient,
- order placement failure or invalid tick-value context.

---

## 4) Weaknesses in current design (analysis only)

1. Layered gate density can over-filter M1 opportunities:
   - multiple cooldowns + frequency cap + hard entry filters can severely reduce valid signals.

2. Entry timing can still be constrained:
   - entry now uses current candle (`rates[0]`) internally, but overall EA evaluates signals on new M1 bar only.

3. Relative scoring thresholds can still suppress entries in mixed/sideways micro-regimes:
   - strict requirement that a direction must beat the opposite side can reject borderline continuation setups.

4. Spread cap floor behavior is potentially mis-scaled by symbol point convention:
   - forced minimum `500` points may be overly permissive depending on broker digits.

5. Module coherence risk:
   - analyzed `Management.mqh`/`Risk.mqh` overlap conceptually with runtime logic but are not clearly active in the EA include path, increasing maintenance confusion.

6. Coarse graded confidence:
   - lightweight scoring improves flexibility, but still uses a small feature set and hard score cutoff.

---

## 5) Trade rejection reason codes observed

- `LOW_ATR`
- `HIGH_SPREAD`
- `TREND_WEAK`
- `MOMENTUM_WEAK`
- `SCORE_TOO_LOW`
- `DIRECTION_CONFLICT`
- `EARLY_NOISE`
- `M5_TREND_BLOCK`
- `SELL_DISABLED_DEBUG`
- `CORE_CONDITION_FAIL`
- `LOSS_CLUSTER_COOLDOWN`
- `COOLDOWN_ACTIVE`
- `COOLDOWN_5CANDLE`
- `MAX_TRADES_REACHED`
- `INSUFFICIENT_MARGIN`
- `ORDER_FAILED`
- `INVALID_TICKVALUE`
- `OTHER` fallback

