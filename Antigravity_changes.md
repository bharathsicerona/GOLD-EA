# Antigravity Changes Log

This file documents all coding updates and changes made by the Antigravity assistant. This is used alongside `README.md` and `PROJECT_INDEX.md` to maintain clear documentation and project progression.

## Log Entries

### 2026-03-28 - M1 & M5 Multi-Strategy Refactor

- **M1 Scalper EA**: Refactored `ValidateEntry()` in `XAUUSD_M1_Scalper_Entry.mqh` to replace the scoring system with three independent strategies: `M1_EMA_PULLBACK`, `M1_BREAKOUT`, and `M1_REVERSAL`. If any strategy is valid, a trade is taken.
- **M5 Adaptive EA**: Replaced scoring/selection logic in `XAUUSD_Adaptive_Entry.mqh` to evaluate three independent strategies: `M5_TREND_PULLBACK`, `M5_RANGE` (Asian), and `M5_BREAKOUT` (London).
- **Execution & Logging**: Enforced a fixed lot size of `0.01` for all entries in both EAs. Updated CHECK and EXECUTION logs to track the specific `strategy` responsible for the trigger, enabling independent backtesting of each setup.

### 2026-03-29 - Strategy Augmentation

- **M5 Adaptive EA**: Added a fourth strategy `M5_ATR_BREAKOUT` in `XAUUSD_Adaptive_Entry.mqh` that triggers during London/NY sessions when ADX > 28, current ATR exceeds the 20-period average by 30%, and price closes outside the fast EMA.
- **M1 Scalper EA**: Tightened the `M1_BREAKOUT` condition in `XAUUSD_M1_Scalper_Entry.mqh` to require an ATR expansion logic (current ATR > 20-period average * 1.2) to prevent false breakouts during flat markets.

### 2026-03-29 - Critical Fixes

- **2026-03-29 `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` & `XAUUSD_M1_Scalper_EA.mq5`**: (Fix 1A & 1B) Changed `GetIndicatorValue` and `CopyBuffer` fetching logic from index 0 to index 1 inside `ValidateEntry()` to prevent reading tiny unformed variables at bar open from blocking trades. (Fix 1C) Decoupled `M1_BREAKOUT` from the `IsNewBar()` lock, granting it a tick-by-tick evaluation independent of bar opens to properly execute intra-candle momentum breakouts.
- **2026-03-29 `EAs/Adaptive`**: (Fix 2A) Applied `snapshot.shift` instead of `0` in `CopyBuffer` for `M5_ATR_BREAKOUT` in `XAUUSD_Adaptive_Entry.mqh` to prevent zero index inflation. (Fix 2B) Modified `ExecuteTrade` in `XAUUSD_Adaptive_Management.mqh` to trigger pending Stop orders rather than Market orders for London `M5_BREAKOUT` trades, preventing late slippage. (Fix 2C) Formally suppressed obsolete dynamic lot logic inside `ExecuteTrade`, adding the `InpUseDynamicLotSizing` to Input Parameters and documenting the default bypassed state properly.
