# XAUUSD EA Optimization Checklist

Use this checklist when optimizing the EA in the MT5 Strategy Tester.

---

### ✅ 1. Pre-Optimization Setup

- [ ] Confirm the EA compiles **without errors** in MetaEditor.
- [ ] Confirm the symbol name (`InpTradeSymbol`) matches your broker *exactly*.
- [ ] Confirm the chart timeframe matches your test plan (e.g., M1, M5).
- [ ] Use account settings (leverage, deposit) that reflect your real trading conditions.
- [ ] Start with a conservative risk setting (e.g., 1%) during optimization runs.

---

### ✅ 2. Base Test Configuration

-   **Symbol**: `XAUUSDm` (or your broker's equivalent)
-   **Timeframe**: Start with the EA's intended timeframe (e.g., `M5` for the Adaptive EA, `M1` for the Scalper).
-   **Model**: `Every tick based on real ticks` for the highest accuracy.
-   **Test Period**: At least **6-12 months** to cover different market conditions.
-   **Initial Deposit**: Close to your intended account size.
-   **Risk Per Trade**: Keep fixed at **1%** during initial parameter optimization.

---

### ✅ 3. Optimization Phases (In Order)

#### Phase 1: Market Structure & Trend
*Goal: Achieve clean trend-following entries and reduce counter-trend noise.*
- [ ] `InpFastEmaPeriod`
- [ ] `InpSlowEmaPeriod`
- [ ] `InpPullbackAtrFactor`
- [ ] Session hours (e.g., `InpLondonStartHour`)

#### Phase 2: Momentum & Volatility
*Goal: Avoid weak/late signals and filter for energetic market conditions.*
- [ ] `InpRsiBuyMin` / `InpRsiBuyMax`
- [ ] `InpRsiSellMin` / `InpRsiSellMax`
- [ ] `InpMinAtrPoints` (for M1 Scalper)
- [ ] `InpSpikeCandleAtrFactor` (for M1 Scalper)

#### Phase 3: Risk & Trade Management
*Goal: Improve drawdown, survival rate, and profit capture.*
- [ ] `InpStopAtrMultiplier`
- [ ] `InpRewardRiskRatio`
- [ ] For the M1 Scalper, observe the behavior of the dynamic trailing stop and TP.

#### Phase 4: Execution Filters
*Goal: Remove low-quality trades caused by external factors.*
- [ ] `InpMaxSpreadPoints`
- [ ] For the M5 EA, `InpMinimumScore` and strategy weights.

---

### ✅ 4. Evaluating Results

A good optimization result is about **balance**, not just maximum profit.

**Look for:**
- [ ] A stable, consistently rising equity curve.
- [ ] Reasonable maximum drawdown (relative to the strategy's risk profile).
- [ ] A profit factor ideally above **1.2**.
- [ ] A sufficient number of trades to ensure statistical significance.
- [ ] Similar performance across different months (robustness).

**Avoid optimizing solely for:**
- [ ] The absolute highest total profit.
- [ ] The highest win rate (a low win rate can be very profitable with high R:R).
- [ ] A single, perfect historical period (curve-fitting).

---

### ✅ 5. Final Pre-Live Checklist

- [ ] Run at least one full backtest on the final settings.
- [ ] Run a forward test on a **demo account** for at least one week.
- [ ] Check the broker's real spread behavior during the London and New York sessions.
- [ ] Confirm lot sizes are being calculated as expected with your live account balance.
- [ ] Manually watch a trade open and see the SL/TP placed correctly on a demo chart.
- [ ] Save your final, tested inputs as a `.set` file for your specific broker and strategy.
