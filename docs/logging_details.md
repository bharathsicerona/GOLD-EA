# 🧠 1. Logging System Overview

The GoldEA logging system is designed to provide comprehensive, structured data for strategy debugging, performance auditing, and quantitative trade analysis. It bridges the gap between the MetaTrader 5 (MT5) execution environment and high-level Python analysis by ensuring every internal decision—from signal evaluation to final trade exit—is recorded in a machine-readable format.

### Purpose
*   **Auditability:** Every trade can be traced back to the exact market conditions (RSI, ATR, Spread) that triggered it.
*   **Optimization:** Rejection logs reveal why "good" signals were filtered, allowing for fine-tuning of entry criteria.
*   **Analysis:** Standardized keywords allow the Python analyzer to calculate win rates per session, R-distribution, and strategy efficiency.

### System Components
| Component | Storage Location | Content |
| :--- | :--- | :--- |
| **MT5 Console Logs** | `logs/M1_Scalper_logs.log`, etc. | Human-readable but structured `[CHECK]`, `[EXECUTION]`, and `[RESULT]` lines. |
| **CSV Logs** | `MQL5/Files/GoldEA_Log_*.csv` | Tabular data for easy access in Excel. Includes entry price, indicators, and session. |
| **Analyzer Output** | `log_analysis_output/data.json` | Reconstructed trade lifecycles, performance summaries, and event streams. |

### EA Differences
*   **M1 Scalper:** Uses `[M1_SCALPER][GoldEA]` prefix. Focuses on high-frequency signals and aggressive trailing management.
*   **M5 Adaptive:** Uses `[M5][GoldEA]` prefix. Now uses a **Market Mode Engine** (TREND/BREAKOUT) to filter signals before evaluation. Focuses on capital stabilization and strategy isolation (only one strategy runs per mode).

---

# ⚙️ 2. Log Generation Flow

The system follows a strict sequential flow during every trading cycle (`OnTick` or `OnNewBar`):

1.  **Market Awareness (`EvaluateTickAndDashboard`):** Indicators are calculated and the visual dashboard is updated.
2.  **Strategy Evaluation (`ValidateEntry` / `SelectAndRunStrategy`):**
    *   Multiple strategies are checked in parallel.
    *   **CHECK** logs are emitted for each valid signal detected.
3.  **Decision Interaction (`ProcessStrategySignals` / `PickBestDecision`):**
    *   The system analyzes signal confluence or conflicts.
    *   If no action is taken, a **REJECTION** log is emitted with a standardized reason.
4.  **Trade Execution (`ExecuteHighRiskTrade` / `ExecuteTrade`):**
    *   The `CTrade` class is invoked.
    *   An **EXECUTION** log is emitted, including a unique `tradeId`.
5.  **Lifecycle Management (`OnTradeTransaction`):**
    *   MT5 triggers callbacks for order fills, stop-loss hits, or profit targets.
    *   A **RESULT** log is emitted, closing the loop for that `tradeId`.

**Actual Flow Example (M1 Scalper):**
`OnTick()` → `isNewBar?` → `ValidateEntry()` → `LogTyped("CHECK", ...)`  
→ `ProcessStrategySignals()` → `ExecuteHighRiskTrade()` → `LogTyped("EXECUTION", ...)`  
→ `OnTradeTransaction()` → `LogTyped("RESULT", ...)`

---

# 📂 3. Source Files for Logging

The logging logic is decoupled into specific headers to maintain a clean main EA structure:

### M1 Scalper
*   **`XAUUSD_M1_Scalper_EA.mq5`**: Contains the main `LogTyped` wrapper and `NormalizeRejectReason` mapping.
*   **`XAUUSD_M1_Scalper_Logging.mqh`**: Handles the physical CSV file writing (`LogToCSV`) and Dashboard rendering.
*   **`XAUUSD_M1_Scalper_Entry.mqh`**: Defines the `StrategySignal` struct and performs indicator snapshots for logging.

### M5 Adaptive
*   **`XAUUSD_Adaptive_Management.mqh`**: Centrally manages `LogTyped`, `NormalizeRejectReason`, and the trade execution/result logging.
*   **`XAUUSD_Adaptive_Logging.mqh`**: Handles CSV logging and visual arrow placement on charts.

### Shared
*   **`GoldEA_Common_Core.mqh`**: Provides `DebugPrint()`, `CurrentTimeText()`, and the **Trade Context Engine** (`g_tradeContextMap`) which persists strategy identity through the trade lifecycle.



---

# 🔑 4. Log Format & Keywords

All logs follow a rigid contract to ensure the Python parser can distinguish between different EA instances and event types.

### Standard Format
`[EA_TYPE][GoldEA][LOG_TYPE] [STRATEGY] [SIDE] [ACTION]: [KEY=VALUE PAIRS]`
*   **Note:** `[STRATEGY]` is now a mandatory bracketed prefix for all `CHECK`, `EXECUTION`, and `RESULT` logs.


### Prefixes
*   **EA type:** `M1_SCALPER` or `M5`
*   **System Tag:** `GoldEA` (Always constant)

### Log Types (LOG_TYPE)
*   **`CHECK`**: Emitted when a strategy finds a potential entry.
*   **`EXECUTION`**: Emitted when an order is successfully sent to the broker.
*   **`REJECTION`**: Emitted when a signal fails a hard filter (e.g., Spread) or soft filter (e.g., Score).
*   **`RESULT`**: Emitted when a trade is closed via SL, TP, or manual/breakeven modification.
*   **`MGMT`**: (M1) Emitted for active trade intelligence, such as automated SL tightening or TP extension.
*   **`STATS`**: Periodic internal counters (Signal count, Win/Loss count).

### Key Fields
*   `tradeId`: Unique integer linking the full lifecycle from Execution to Result.
*   `score`: Integer representing the directional strength of M1 signals.
*   `atr`: The volatility snapshot at the moment of the event.
*   `spread`: Real-time spread in points.
*   `reason`: A normalized keyword explaining why a trade was skipped or closed.

---

# 🚫 5. Rejection System

The rejection system uses `NormalizeRejectReason()` to convert messy internal logic flags into clean, searchable keywords.

### Standard Rejection Keywords
*   **`LOW_ATR` / `LOW_ATR_DYNAMIC`**: Market is too quiet for the strategy's expected edge.
*   **`HIGH_SPREAD`**: Spread exceeded the dynamic or hard-coded cap.
*   **`COOLDOWN_ACTIVE`**: A recent trade or loss triggered a mandatory pause.
*   **`INSUFFICIENT_MARGIN`**: Account balance cannot support the lot size.
*   **`SESSION_BLOCK`**: Current server time is outside the allowed session.
*   **`NO_MARKET_MODE`**: (M5) Market is neither trending nor breaking out.
*   **`WEAK_TREND`**: ADX is below the entry threshold (<20).
*   **`LOW_VOLATILITY`**: ATR is lower than the recent average (0.8x multiplier).
*   **`WEAK_CANDLE`**: Candle body/range ratio is below 60%.
*   **`LOW_SCORE`**: (M1) Signal confidence level is below the required threshold.

### Design Decision: Rejection Suppression
To prevent "log bloat," the M1 Scalper **only logs one rejection reason per bar** in its summary decision logic, rather than logging a rejection for every individual strategy check that fails. Tick-level rejection logging is strictly disabled by design.

---

### Trade Context Engine (NEW)
To ensure 100% reliable strategy attribution, the system uses a global `CHashMap<ulong, TradeContext*>` called `g_tradeContextMap`.

1.  **EXECUTION:** Strategy name is stored in the map using the `tradeId` as the key.
2.  **RESULT:** The `OnTradeTransaction` handler looks up the `tradeId` in the map to retrieve the original strategy name for the result log, then cleans up the memory.
3.  **ANALYZER:** Directly parses the strategy from the log line without needing to guess via lookback.

---


# 🐍 7. Python Analyzer Integration

The `scripts/analyze_ea_logs.py` script is the "final destination" for all log data.

### Parsing Logic
*   **`EA_PREFIX_RE`**: Routes lines to the correct EA performance bucket.
*   **`CHECK_RE` / `EXEC_RE` / `RESULT_RE`**: Now explicitly extract the bracketed `[STRATEGY]` prefix.
*   **Reliable Attribution**: The analyzer no longer relies on "lookback" heuristics to guess the strategy; it uses the direct strategy tag provided in every lifecycle event.

### Output Artifacts

*   **`events.csv`**: A flattened list of every valid signal and execution for deep-dive auditing.
*   **`summary.csv`**: Aggregated metrics (Profit Factor, Win Rate, Expectancy) per EA and per Session.
*   **`data.json`**: A structured nesting of every trade lifecycle, used for custom plotting or dashboarding.

### Linking Strategy
The parser uses a "lookback" mechanism: when an `EXECUTION` is found, it finds the most recent `CHECK` on the same side to attribute the trade to a specific strategy and market state.

---

# ⚠️ 8. Known Issues & Design Decisions

*   **Regex Mismatch (Fixed):** Previous versions had a mismatch between M1 Scalper prefixes and the Python parser. The project now strictly uses `M1_SCALPER` in both locations.
*   **Strategy Attribution:** M1 signals now correctly log the specific strategy name (e.g., `[M1_BREAKOUT]`) instead of a generic tag.
*   **M1 Tick Suppression:** Rejections are only logged at the bar level in M1 to keep log files under 10MB during multi-year backtests.
*   **Parser Limit:** If a trade is opened and MT5 is restarted, the `tradeId` linkage might break if global variables are lost. The analyzer uses timestamp proximity as a secondary fallback.

---

# 📊 9. Example Logs

### CHECK (Signal Evaluation)
`[M1_SCALPER][GoldEA][CHECK] [M1_EMA_PULLBACK] BUY check: atr=2.50 spread=200 reason=VALID strategy=M1_EMA_PULLBACK`

### EXECUTION (Order Placed)
`[M5][GoldEA][EXECUTION] [M5_TREND_PULLBACK] BUY executed: tradeId=42 lot=0.01 entry=2150.25 sl=2140.25 tp=2180.25 strategy=M5_TREND_PULLBACK`

### RESULT (Outcome)
` [M1_EMA_PULLBACK] STOP_LOSS_HIT tradeId=1024 profit=-3.00`
`[M5][GoldEA][RESULT] [M5_TREND_PULLBACK] TAKE_PROFIT_HIT tradeId=42 profit=30.00`
`[M1_SCALPER][GoldEA][RESULT] EARLY_EXIT_REVERSAL tradeId=1024 profit=5.00 strength=2.50`

### MGMT (Management Actions)
`[M1_SCALPER][GoldEA][MGMT] SL_TIGHTENED_REVERSAL tradeId=1024 newSL=2160.00 strength=1.50`
`[M1_SCALPER][GoldEA][MGMT] TP_EXTENDED_REVERSAL tradeId=1024 newTP=2200.00 strength=3.00`

---


---

# 🛠️ 11. Core Helpers (`GoldEA_Common_Core.mqh`)

- **`BuildGlobalKey` / `BuildStateKey`**: Shared key naming for `GlobalVariables`.
- **`SetDashboardLabelLine`**: Unified chart labeling for on-screen dashboards.
- **`CleanupLogsByPattern`**: Core file maintenance for rotated daily CSV logs.
- **`GetIndicatorValue`**: Unified error-checked buffer access for all indicators.
- **`NormalizeVolume`**: Unified LOT size normalization for Gold symbols.

# 🎯 12. Summary

The GoldEA logging system transforms a "black box" trading algorithm into an **open, auditable system**. By combining structured MQL5 prints with a sophisticated Python parser, it allows quant traders to verify edge, identify session-based weaknesses, and iterate on strategy logic with data-driven confidence.
