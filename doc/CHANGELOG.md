# Gold EA Project - Changelog

This document summarizes the major changes, bug fixes, and strategic overhauls made to the Expert Advisors in this project.

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
