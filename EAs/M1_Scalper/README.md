# XAUUSD M1 Scalper EA (Fast Trend Mode)

The M1 Scalper EA has been optimized for **Fast Trend Continuation** using a relaxed trend model and professional-grade momentum filtering. It focuses exclusively on the `M1_TREND_RSI_CONTINUATION` strategy.

## 🎯 Core Strategy: RELAXED TREND MODEL

- **Timeframe:** `PERIOD_M1`
- **Directional Bias:** **EMA100** acts as a hard filter:
    - **Long Only** if Price > EMA100
    - **Short Only** if Price < EMA100
- **Fast Trend Alignment:** 
    - EMA20 > EMA50 (Buy) / EMA20 < EMA50 (Sell)
    - EMA20 Slope matching trade direction
- **Momentum Entry Trigger:**
    - Previous candle close above/below EMA20
    - RSI Momentum (RSI[1] > RSI[2] for Buy)
    - Trend Strength: Separation between EMA20 and EMA50 must exceed `0.1 * ATR`.

## 🚫 Advanced Filters & Safety

In addition to the standard Adaptive Filter Layer, the EA uses **Pro Version** candle quality checks:
- **WEAK_CANDLE_DYNAMIC (Pro):** Rejects trades if the bodies of the last TWO closed candles are smaller than `0.2 * ATR`. This prevents entries in choppy, low-conviction consolidation zones.
- **Low Volatility:** Rejects if current ATR is < 80% of the 20-period average.
- **RSI Extremes:** Extra guard rejecting `RSI >= 60` for BUY or `RSI <= 30` for SELL.
- **Spread & Cooldown:** Mandatory points-based spread limit and 3-candle execution cooldown.

## 📊 Real-Time Dashboard (Visual Matrix)

The EA features a dynamic, tick-sync dashboard for transparent system monitoring:
- **Trend State:** Real-time direction, strength value, and category (WEAK/MEDIUM/STRONG).
- **Chop Detector:** Visual validation of market structure using range-to-ATR ratios.
- **Filter Dashboard:** BIAS status, ATR quality, Candle Strength (PRO), and System Cooldown.
- **Decision Status:** Aggregated readiness indicator (`READY`, `WAIT`, or specific `BLOCKED` reasons).
- **Trade Monitoring:** Floating Profit ($), Locked Profit ($), and current trailing phase (`NO_LOCK`, `EARLY_LOCK`, `N-1_TRAILING`).

## 🧠 Trade Management
- **Phase 1:** At `1R`, stop moves to lock roughly `0.2R`.
- **Phase 2:** At `2R`, stop moves to lock roughly `1.0R`.
- **Targeting:** Default TP remains `3R`, so the live management path is simpler than older multi-step ladder versions.

## 💰 Risk Model
- **Shared Risk Engine:** `GoldEA_Unified_Risk.mqh`
- **Fixed Path:** `0.01 lot -> $4`, `0.02 lot -> $8`, `>=0.03 lot -> 1% of balance`
- **Active M1 Overlay:** the execution path passes ATR distance into the shared engine, so the final stop remains ATR-aware.
- **Primary Target:** Runners targeted for a **3R** reward-to-risk ratio.
- **Execution:** strictly Candle-Close only.

Primary documentation:
- Project overview: [README](../../README.md)
- Detailed runtime map: [PROJECT_INDEX](../../PROJECT_INDEX.md)
