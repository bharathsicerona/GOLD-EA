# Gold EA Project - Changelog

This document summarizes the major changes, bug fixes, and strategic overhauls made to the Expert Advisors in this project.

---
## M1 Scalper EA - Version 4.1 (Intelligence Upgrade)

*   **[ENHANCEMENT] Upgraded Strategy Signal Structure:** The `StrategySignal` struct now includes `isStrong` and `isWeak` flags to better classify the quality of a signal.
*   **[ENHANCEMENT] Improved Breakout Logic:** The breakout strategy now includes a candle quality check (body > 60% of range) to filter for higher quality breakouts.
*   **[ENHANCEMENT] Improved Strategy Interaction Engine:** The `ProcessStrategySignals` function has been updated with a more sophisticated, priority-based rule set to improve trade selection.
*   **[ENHANCEMENT] Improved Feedback Manager:** The `StrategyFeedbackManager` has been improved with more nuanced logic for handling in-trade signals, including a critical rule for immediate exit on an opposing liquidity sweep.
*   **[LOGGING] Maintained Logging Compatibility:** All changes were made while preserving the existing logging structure to ensure compatibility with the log analyzer.

---
## M1 Scalper EA - Version 4.0 (Multi-Strategy Collaboration Model)

*   **[REFACTOR] Multi-Strategy Execution Model:** The M1 Scalper has been upgraded from a single-strategy execution model to a multi-strategy collaboration model.
*   **[FEATURE] New Strategy: M1_LIQUIDITY_SWEEP:** A new strategy has been added to detect and trade liquidity sweeps.
*   **[FEATURE] Signal Interaction Engine:** A new `ProcessStrategySignals` function has been added to process signals from all strategies and make a final trading decision based on a set of rules.
*   **[FEATURE] Strategy Feedback Manager:** A new `StrategyFeedbackManager` function has been added to manage open trades by reacting to new signals, allowing for dynamic trade management.
*   **[REFACTOR] `ValidateEntry` Refactoring:** The `ValidateEntry` function has been refactored to evaluate all strategies and return an array of signals, instead of a single decision.
*   **[ENHANCEMENT] Upgraded Breakout Strategy:** The breakout strategy has been enhanced to include a configurable lookback period and a stronger body check.
*   **[LOGGING] New Log Types:** New log types have been added to provide more detailed information about the new multi-strategy system.

---
## M1 Scalper EA - Version 3.7 (Log System Parity)

*   **[CRITICAL FIX] Corrected Strategy Name in Logs:** Fixed a critical logging error where M1 `CHECK` logs would hardcode `[M1_PA]` as the strategy. The logs now dynamically insert the correct strategy name (e.g., `[M1_BREAKOUT]`, `[M1_REVERSAL]`).
*   **[IMPACT] Resolved Python Analyzer Mismatch:** This change resolves the long-standing "Regex Mismatch" issue, allowing the Python log analyzer to correctly parse and attribute signals to the specific M1 strategy that generated them. This unlocks accurate, strategy-level performance analysis for the M1 EA.
*   **[COMPATIBILITY] Parser Alignment:** The M1 `CHECK` log format is now fully aligned with the Python parser's expectations and matches the logging convention used by the M5 EA.

---
## M1 Scalper EA - Version 3.6 (M1-M5 System Alignment)

*   **[SYSTEM ALIGNMENT] Added M5 trend filter to M1 `ValidateEntry()`:**
    *   BUY allowed only when M5 `EMA20 > EMA50`
    *   SELL allowed only when M5 `EMA20 < EMA50`
    *   Rejection reason: `M5_TREND_BLOCK`
*   **[SYSTEM ALIGNMENT] SELL temporarily disabled (debug phase):**
    *   SELL path returns `SELL_DISABLED_DEBUG`
*   **[SYSTEM ALIGNMENT] Entry quality tightened:** score threshold increased from `>=4` to `>=6` with `SCORE_TOO_LOW` on failure.
*   **[COMPATIBILITY] Logging contract preserved:** `CHECK/REJECTION/EXECUTION` structure unchanged.

---
## M1 Scalper EA - Version 3.5 (Balanced Cohesive Entry/Exit System)

*   **[NEW SYSTEM] Balanced entry model in `ValidateEntry()`:**
    *   Core trend kept: BUY `EMA20 > EMA50`, SELL `EMA20 < EMA50`
    *   Pullback primary condition widened to ATR band (`EMA20 +/- ATR*0.20`)
    *   Required momentum with stronger threshold (`ATR*0.10`) and explicit `MOMENTUM_WEAK` rejection
    *   Breakout softened to booster-only with ATR tolerance:
        *   BUY: `mid > prevHigh - ATR*0.02`
        *   SELL: `mid < prevLow + ATR*0.02`
*   **[NEW SYSTEM] Entry timing anti-noise gate:** Added `EARLY_NOISE` rejection when `abs(mid-open0) < ATR*0.03`.
*   **[UPDATED] Scoring model:** Core `+2`, Pullback `+1`, Momentum `+2`, Breakout `+1`, EMA separation booster `+1` (directional), min score `4`, and directional dominance requirement.
*   **[NEW SYSTEM] SL/TP model in execution:** Replaced fixed-$ SL with ATR-based structure:
    *   `slDistance = clamp(ATR*0.8, 2.0, 5.0)`
    *   `tpDistance = slDistance * 1.5`
*   **[NEW SYSTEM] Runner management aligned to R-multiples:**
    *   `>1R`: move SL to breakeven
    *   `>1.5R`: lock `+0.5R`
    *   `>2R`: trail by `1R`
*   **[LOGGING] CHECK payload extended:** Added `slDistance` and `tpDistance` fields while preserving `CHECK/REJECTION/EXECUTION` format contract.
*   **[COMPATIBILITY] Analyzer mapping updated:** Added `EARLY_NOISE` normalization in rejection reason mapping.

---
## M1 Scalper EA - Version 3.4 (Breakout Mandatory + Stricter Quality Gate)

*   **[CRITICAL] Breakout now mandatory:** Breakout is no longer optional scoring only. `ValidateEntry()` now rejects entries with `NO_BREAKOUT` if:
    *   BUY: `mid <= prevHigh`
    *   SELL: `mid >= prevLow`
    This check is applied after core condition validation and before score threshold checks.
*   **[ENHANCEMENT] Momentum threshold strengthened:** Momentum confirmation increased from `ATR * 0.05` to `ATR * 0.10` for both directions.
*   **[ENHANCEMENT] Score quality threshold raised:** Minimum entry score increased from `3` to `4` (`SCORE_TOO_LOW` on failure).
*   **[ENHANCEMENT] Breakout score weight increased:** Breakout score contribution raised from `+1` to `+2` per direction (while remaining mandatory).
*   **[COMPATIBILITY] Structured reason mapping expanded:** Added `NO_BREAKOUT` mapping in `NormalizeRejectReason()` without removing existing reason code mappings.
*   **[LOGGING] CHECK field continuity preserved:** M1 CHECK logs continue to include appended `momentum`, `breakoutBuy`, and `breakoutSell` fields with unchanged log type structure.

---
## M1 Scalper EA - Version 3.3 (Quality Filters and Score Clarity)

*   **[CRITICAL] Momentum logic hardened:** Replaced weak momentum checks (`mid > open0` / `mid < open0`) with ATR-thresholded momentum:
    *   Buy: `(mid - open0) > atr * 0.05`
    *   Sell: `(open0 - mid) > atr * 0.05`
*   **[FEATURE] Micro-breakout edge filter:** Added previous-candle breakout booster:
    *   Buy breakout: `mid > prevHigh`
    *   Sell breakout: `mid < prevLow`
    *   Each breakout adds `+1` score to its side.
*   **[FIX] Directional EMA-separation scoring:** EMA separation score no longer benefits both sides simultaneously; it is now awarded only to the trend-aligned side.
*   **[ENHANCEMENT] Structured rejection reasons:** Introduced clearer scoring conflict reasons in `ValidateEntry()`:
    *   `SCORE_TOO_LOW`
    *   `DIRECTION_CONFLICT`
    while keeping `CORE_CONDITION_FAIL` unchanged.
*   **[LOGGING] CHECK payload extension:** Appended `momentum`, `breakoutBuy`, and `breakoutSell` fields to M1 CHECK logs without changing `CHECK/REJECTION/EXECUTION` structure.

---
## M1 Scalper EA - Version 3.2 (Scoring Entry Refactor)

*   **[REFACTOR] ValidateEntry scoring model:** Replaced strict binary entry acceptance in `ValidateEntry()` with a lightweight score model while keeping the same function signature and EA call flow.
*   **[KEEP] Hard safety filters preserved:** ATR minimum and dynamic spread filter remain mandatory pre-entry gates.
*   **[FEATURE] Directional scoring added:**
    *   Core trend condition = `+2`
    *   Pullback touch/reclaim (candle0) = `+1`
    *   EMA separation booster = `+1`
    *   Momentum booster = `+1`
*   **[FEATURE] Directional strength guard:** Trade is valid only when side score is `>= 3` and strictly greater than opposite side score.
*   **[ENHANCEMENT] Earlier signal detection:** Pullback confirmation now uses current candle (`candle0`) touch/reclaim checks for faster entry context.
*   **[LOGGING] CHECK payload updated:** M1 CHECK lines now include `buyScore` and `sellScore` fields while preserving existing `CHECK/REJECTION/EXECUTION` contract.
*   **[COMPATIBILITY] Reason code mapping preserved:** New outcomes reuse existing rejection reason taxonomy (`CORE_CONDITION_FAIL`, `MOMENTUM_WEAK`, `TREND_WEAK`, `LOW_ATR`, `HIGH_SPREAD`, etc.).

---
## M1 Scalper EA - Version 3.1 (Entry Logic Tuning)

*   **[ENHANCEMENT] Dynamic EMA Gap Filter:** The trend strength filter, which checks the gap between the fast and slow EMAs, was updated. It now uses a dynamic, ATR-based threshold (`ATR * 0.6`) instead of a fixed point value. This allows the filter to adapt to changing market volatility, requiring a wider EMA separation in volatile markets and a smaller one in quiet markets.
*   **[ENHANCEMENT] Hybrid Pullback Logic:** The condition for identifying a pullback to the EMA20 has been significantly improved. The new hybrid logic now validates a pullback if either the price is within a certain ATR-based distance (`ATR * 0.4`) of the EMA, OR if the candle body explicitly crosses over the EMA, providing a much more reliable entry signal.
*   **[FEATURE] Minimum Volatility Filter:** A new hard filter was added to prevent the EA from trading in extremely flat or non-volatile market conditions. Trades are now rejected if the current ATR value is below a minimum threshold (e.g., 1.0 for XAUUSD). This helps avoid low-probability "chop" entries.
*   **[DOCS] Updated Entry Logic Documentation:** The header comments in `XAUUSD_M1_Scalper_Entry.mqh` have been updated to reflect the new, more sophisticated entry conditions.

---
## Dashboard & UI Enhancements - Version 4.4

*   **[FEATURE] Added Dashboard to M1 Scalper EA:** Implemented a new dashboard for the M1 Scalper EA, reusing the existing dashboard code from the M5 Adaptive EA. This provides a consistent user interface across both EAs.
*   **[FEATURE] Standardized Dashboard Titles:** The dashboard titles for both EAs have been updated to be dynamic and clearly identify the running EA. The new titles are "GOLD EA M1 Dashboard" and "GOLD EA M5 Dashboard".
*   **[ENHANCEMENT] Consistent UI:** Ensured that the layout, UI behavior, and overall look and feel of the dashboards are consistent for both EAs.
*   **[REFACTOR] Modular Dashboard Code:** The dashboard logic for the M1 EA has been encapsulated in `XAUUSD_M1_Scalper_Logging.mqh` and `XAUUSD_M1_Scalper_Management.mqh` to mirror the structure of the M5 EA.

---
## Unified Logging System - Version 1.0

*   **[REFACTOR] Standardized Logging System:** Implemented a new, unified logging system across both the M1 Scalper and M5 Adaptive EAs to ensure all log outputs are clearly identifiable and consistently formatted.
*   **[FEATURE] Added `EA_TYPE` Identifier:**
    *   Introduced a global `EA_TYPE` variable in each main EA file.
    *   Set to `"M1_SCALPER"` for the M1 EA.
    *   Set to `"M5"` for the M5 EA.
*   **[FEATURE] Created `Log()` Wrapper Function:** A new `Log(string message)` function was created to automatically prepend every log message with the `[EA_TYPE][GoldEA]` prefix, providing a standardized output format.
*   **[REFACTOR] Replaced All `Print` Statements:** All instances of `Print()`, `PrintFormat()`, and the custom `DebugPrint()` across all relevant EA and management files were replaced with the new `Log()` function.
*   **[DOCS] Added Logging Refactor Documentation:** Created a new document `doc/LOGGING_REFACTOR.md` to explain the changes, rationale, and provide before/after examples of the log outputs.

---

## M5 Adaptive EA - Version 4.30 (R-Multiple Trailing Stop)

*   **[FEATURE] Implemented R-Multiple Trailing Stop:** Added a new, sophisticated trailing stop system to the M5 strategy's `ManageTrade` function. This system moves the Stop Loss based on profit measured in multiples of the initial risk (R).
*   **[FEATURE] Defined Multi-Stage Profit Locking:** The new trailing logic locks in profit at key thresholds:
    *   `+0.1R` SL when profit exceeds `0.5R`
    *   `+0.5R` SL when profit exceeds `1.0R`
    *   `+1.0R` SL when profit exceeds `2.0R`
    *   `+1.5R` SL when profit exceeds `2.5R`
*   **[ENHANCEMENT] State Management & Logging:** The system uses `GlobalVariables` to track the current trailing stop level for each trade, preventing redundant server requests. All SL movements are now logged with the corresponding R-multiple trigger.
*   **[DOCS] Created M5 EA Documentation:** Added a new file `doc/XAUUSD_Adaptive_M5_README.md` to document the specific logic and features of the M5 strategy, including the new trailing stop system.

---
## M1 Scalper EA - Version 3.0 (Risk Management System Upgrade)

*   **[CRITICAL] Implemented Unified Risk Engine:** Created a new, centralized module (`GoldEA_Unified_Risk.mqh`) to manage all trade risk calculations. This system is now used by the M1 Scalper and is ready for the M5 EA.
*   **[FEATURE] Added Fixed $10 SL Cap:** For all minimum lot (`0.01`) trades, the system now automatically adjusts the Stop Loss to ensure the maximum risk per trade does not exceed $10. This significantly improves capital preservation on small accounts.
*   **[FEATURE] Implemented 1% Dynamic Risk Model:** For all trades larger than the minimum lot, the lot size is now dynamically calculated to represent 1% of the total account balance, ensuring risk scales with account equity.
*   **[ENHANCEMENT] Improved Logging:** Added detailed log messages for every trade, specifying which risk rule was applied ("Fixed $10 cap" or "1% dynamic risk"), the calculated risk in dollars, and the final lot size and SL used.
*   **[REFACTOR] Decoupled Risk from Entry:** The main EA file (`XAUUSD_M1_Scalper_EA.mq5`) was refactored to call the new risk engine, cleanly separating entry signal generation from risk and position sizing.

---

### Version 2.1 (High-Risk Refactor & Bug Fixes)

This version represents a complete architectural and strategic overhaul of the EA, transforming it into an aggressive, high-risk, high-reward scalping system.

#### Core Logic & Entry System
*   **Replaced Scoring with Hard Filters:** The original `RunScalperStrategy` function, which used a cumulative score, was completely replaced by a new `ValidateEntry` function in `XAUUSD_M1_Scalper_Entry.mqh`. The new system uses a sequence of mandatory "hard" filters. A trade is only considered if it passes every single check, leading to more decisive entry logic.
*   **New Entry Filters:**
    *   **RSI Momentum:** The EA now checks that the RSI is actively sloping in the direction of the trade, providing stronger momentum confirmation.
    *   **Spike Candle Avoidance:** A new filter was added to reject entries on abnormally large "spike" candles, which often indicate volatility without clear direction.
*   **High-Risk Mode:** Introduced a global `InpEnableHighRiskMode` to switch between standard and aggressive settings.

#### Trade & Risk Management
*   **Aggressive Trailing Stop:** A new module, `XAUUSD_M1_Scalper_HighRisk_Management.mqh`, was created. It contains the `ManageTrailingStop()` function, which implements the critical dollar-based profit locking:
    *   At $1 profit, SL moves to lock +$0.2.
    *   At $2 profit, SL moves to lock +$1.
    *   The pattern continues, aggressively protecting capital and locking in gains.
*   **Dynamic Take Profit:** The `UpdateDynamicTP()` function was implemented to extend the Take Profit target as a trade moves into profit (e.g., at 1R profit, TP extends to 4R), allowing winning trades to run further.
*   **High-Risk Lot Sizing:** The `CalculateHighRiskLotSize()` function in `XAUUSD_M1_Scalper_Risk.mqh` now:
    *   Uses the new `InpHighRiskPercent` input (defaulting to 3%, adjustable up to 50%+).
    *   Removes the old, conservative logic that would reduce risk after losses.
    *   Defaults to **forcing the broker's minimum lot size** for low-capital accounts, ensuring the EA always takes valid trades.

#### Bug Fixes & Compilation
*   Resolved dozens of compiler errors that arose from the refactoring.
*   Fixed all `sgroup` syntax errors in the input file.
*   Corrected all `CHashMap` method calls (`Init`, `Shutdown`, `Contains`) to use the correct MQL5 Standard Library syntax (`ContainsKey`, etc.).
*   Eliminated all "variable already defined" errors by centralizing indicator handle declarations.
*   Removed or commented out legacy logging and dashboard features that were incompatible with the new architecture, ensuring the core EA compiles successfully.

---

### Version 1.0 (Initial Bug Fixes)

*   **Hard Session Block:** Fixed a bug where trades could still execute during the Asian session when disabled. A hard block was implemented.
*   **Improved Entry Quality:** Added several mandatory entry filters to reduce bad trades, including minimum ATR, momentum candle confirmation, and a micro-trend filter.
