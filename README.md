# Gold Trading EAs for MetaTrader 5

This project contains a collection of Expert Advisors (EAs) for automated trading of Gold (XAUUSD) on the MetaTrader 5 platform. It includes multiple strategies, shared libraries, and a Python script for advanced log analysis.

## Project Structure

The project is organized into a clean and modular structure to ensure clarity and maintainability.

```
.
├── EAs/
│   ├── Adaptive/         # M5 Adaptive Multi-Factor EA
│   ├── M1_Scalper/       # M1 High-Risk Scalper EA
│   ├── Beginner/         # Beginner-friendly Trend Pullback EA
│   └── Include/          # Shared MQL5 library files
├── scripts/
│   └── analyze_ea_logs.py  # Python script for log analysis
├── logs/
│   └── (EA log files are generated here)
├── log_analysis_output/
│   └── (Output from the analysis script)
├── presets/
│   └── (EA input preset files)
├── docs/
│   └── (Supporting documentation)
├── .gitignore
└── README.md             # This file
```

## Expert Advisors

This project includes three distinct Expert Advisors. Each has its own dedicated folder within the `EAs/` directory, containing the main `.mq5` file, any specific `.mqh` include files, and a detailed `README.md`.

### 1. M5 Adaptive (Capital Stabilizer) EA

-   **Folder:** `EAs/Adaptive/`
-   **Role:** Capital Stabilizer (lower-frequency, higher-quality trades on M5).
-   **Strategy:** Trend Pullback only (multi-strategy routing and score/penalty gating removed from live decision path):
    - BUY: `EMA20 > EMA50` + pullback to `EMA20` + bullish candle
    - SELL: `EMA20 < EMA50` + pullback to `EMA20` + bearish candle
    - Session scope: Asian session only
    - Minimum score gate: `InpMinimumScore = 80`
-   **Risk Model:** Fixed monetary stop-loss model shared with M1:
    - 0.01 lot -> SL risk = $10 (M5 structured high-impact mode)
    - 0.02 lot -> SL risk = $6
    - 0.03+ lots -> SL risk = 1% of account balance
    TP remains RR-based from the computed SL distance (default 3R).
    Trailing uses R-based locks: `1R -> +0.1R`, `1.5R -> +0.5R`, `2R -> +1R`, `2.5R -> +1.5R`.
-   **More Info:** See the `EAs/Adaptive/README.md` for a full breakdown of the strategy and its parameters.

### 2. M1 High-Risk Scalper (Capital Booster) EA

-   **Folder:** `EAs/M1_Scalper/`
-   **Role:** Capital Booster (higher-frequency scalping on M1).
-   **Strategy:** Ultra-simple price-action pullback model:
    - BUY: `Price > EMA20` + near/touch `EMA20` + current candle bullish
    - SELL: `Price < EMA20` + near/touch `EMA20` + current candle bearish
    - Trend-strength filter: `abs(EMA20-EMA50)` must exceed configured threshold
    - Momentum filter: current candle body must exceed previous candle body
    - Volatility filter: ATR must be above minimum threshold (`InpMinAtrValue`)
    - Loss-cluster control: after 2 consecutive losses, skip next 2 entry signals
    - Session scope: London + New York only (Asian disabled)
    - Entry cooldown: 5 candles
    - Removed from M1 entry: breakout logic, RSI gating, scoring, and complex momentum filters.
-   **Risk Model:** Fixed monetary stop-loss model:
    - 0.01 lot -> SL risk = $3
    - 0.02 lot -> SL risk = $6
    - 0.03+ lots -> SL risk = 1% of account balance
    In fixed-SL mode, post-entry SL rewrites are disabled.
-   **More Info:** See the `EAs/M1_Scalper/README.md` for a detailed explanation of its aggressive profit-taking mechanisms.

### 3. Beginner Trend Pullback EA

-   **Folder:** `EAs/Beginner/`
-   **Strategy:** A simple, easy-to-understand trend-following strategy that enters on pullbacks to a moving average.
-   **Risk Model:** Basic, percentage-based risk.
-   **More Info:** This EA is self-contained in a single file for simplicity and is a great starting point for learning EA development.

## Installation and Setup

1.  **Clone the Repository:** Clone this repository to your local machine.
2.  **Locate MT5 Data Folder:** Open MetaTrader 5, go to `File -> Open Data Folder`. This will open the terminal's data directory.
3.  **Copy EA Files:**
    -   Copy the entire `EAs` folder from this project into the `MQL5/Experts/` directory inside your MT5 Data Folder.
4.  **Compile EAs:**
    -   In MetaTrader 5, open the **MetaEditor** (or press `F4`).
    -   In the MetaEditor's "Navigator" panel, find the `Experts/EAs` folder.
    -   Right-click on each of the EA folders (`Adaptive`, `M1_Scalper`, `Beginner`) and click **"Compile"**. This will compile all the necessary `.mq5` and `.mqh` files. Check for any errors in the "Errors" tab.
5.  **Refresh Experts List:** Back in the main MT5 terminal, right-click on "Expert Advisors" in the "Navigator" panel and select **"Refresh"**. The EAs should now appear.

## Running the EAs

1.  **Open a Chart:** Open a chart for the desired symbol and timeframe (e.g., `XAUUSD`, `M1` for the Scalper).
2.  **Attach the EA:** Drag the desired EA from the Navigator onto the chart.
3.  **Configure Inputs:** In the "Inputs" tab of the EA's properties window, load a preset file or configure the parameters manually.
4.  **Enable Algo Trading:** In the "Common" tab, ensure that **"Allow Algo Trading"** is checked.
5.  **Confirmation:** Click `OK`. A smiley face icon next to the EA's name on the chart confirms it is running correctly.

## Log Analysis with Python

The project includes a powerful Python script to analyze the standardized log files produced by the EAs.

Analyzer capabilities now include:
- Support for mixed legacy and new log formats (`[M1]`, `[M1_SCALPER]`, `[M5]` prefixes).
- Automatic rejection-reason extraction (e.g., `CORE_CONDITION_FAIL`, `HIGH_SPREAD`, `INSUFFICIENT_MARGIN`, `COOLDOWN_ACTIVE`, `COOLDOWN_2CANDLE`, `SESSION_BLOCK`).
- Mixed-file EA separation (M1 and M5 split safely in a single run).
- Improved trade linking using `tradeId` first, then timestamp+direction fallback when IDs are missing.
- Lifecycle-based resolved trade tracking (entry/exit link required before counting as resolved).
- Trailing SL classification fix: `STOP_LOSS_HIT` with positive profit is classified as `WIN`.
- R-multiple computation standardized per lifecycle: `risk = abs(entry_price - initial_SL)`, `R = profit / risk`.
- Unknown/`OTHER` rejection labels now normalize to `UNCLASSIFIED_REJECTION` for cleaner diagnostics.

### Requirements

-   Python 3.9+

### How to Use

1.  **Run the EAs:** Let the EAs run in the Strategy Tester or on a live/demo account to generate log files. These will typically be found in the `MQL5/Logs` or `MQL5/Profiles/Tester` directory.
2.  **Copy Logs:** Copy the relevant `.log` files into the `logs/` directory of this project.
3.  **Run the Script:** Open a terminal or command prompt, navigate to the `scripts/` directory, and run the script:

    ```bash
    cd scripts
    python analyze_ea_logs.py ../logs/*.log
    ```

4.  **View Results:**
    -   A detailed summary will be printed to the console.
    -   Structured output files (`events.csv`, `summary.csv`, `data.json`) will be automatically saved to the `log_analysis_output/` directory for further analysis in tools like Excel or Pandas.

## Recent Risk System Update

The project now uses one shared fixed monetary stop-loss model across M1 and M5.

- Central function: `CalculateFixedSLDistance(lotSize, balance)` in `EAs/Include/GoldEA_Unified_Risk.mqh`
- M1 integration: `ExecuteHighRiskTrade()` in `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`
- M5 integration: `ExecuteTrade()` in `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`
- SL override behavior:
  - M1 `ManageTrailingStop()` is no-op in fixed-SL mode
  - M5 uses active R-based trailing in management mode

## Risk Model Update

- Base fixed SL model (shared engine):
  - 0.01 lot -> $3
  - 0.02 lot -> $6
  - >=0.03 lot -> 1% account risk

- M1 Scalper:
  - Accounts <= $200 are forced to 0.01 lot (margin-safe mode)
  - No aggressive lot scaling for low-balance mode

- M5 Adaptive:
  - Dynamic lot sizing based on capital is retained
  - Minimum lot = 0.01
  - No upper cap (can scale to 0.02, 0.03, and above)
  - Structured override for high-impact mode:
    - 0.01 lot -> SL risk = $10
    - TP default = 3R
    - Trailing locks: 1R/+0.1R, 1.5R/+0.5R, 2R/+1R, 2.5R/+1.5R

## Logging System

- Structured logging format is implemented for both EAs:
  - `[M1_SCALPER][GoldEA][TYPE] ...`
  - `[M5][GoldEA][TYPE] ...`
- Standard log types:
  - `CHECK` for signal evaluation
  - `EXECUTION` for order placement
  - `REJECTION` for skipped/blocked trades with explicit reason
  - `RESULT` for SL/TP/BE lifecycle events
  - `STATS` for periodic internal counter snapshots
- Trade lifecycle is fully logged with `tradeId`, `score`, `atr`, `spread`, and `reason` fields.
- Logs are aligned with `scripts/analyze_ea_logs.py` expectations (`M1_SCALPER` / `M5` prefixes and `BUY|SELL check:` + `BUY|SELL executed:` patterns).
- M1 check log format is explicitly analyzer-friendly:
  - `[M1_SCALPER][GoldEA][CHECK] [M1_PA] BUY check: rsi=... ema20=... ema50=... score=... atr=... spread=... decision=... reason=...`
  - Same structure for `SELL check`.
- M1 execution/result log formats:
  - `[M1_SCALPER][GoldEA][EXECUTION] BUY executed: tradeId=... lot=... entry=... sl=... tp=...`
  - `[M1_SCALPER][GoldEA][RESULT] STOP_LOSS_HIT tradeId=... profit=...`
  - `[M1_SCALPER][GoldEA][RESULT] TAKE_PROFIT_HIT tradeId=... profit=...`

## Build Notes

- Fixed MQL5 string-uppercase compile issue in rejection-reason normalization.
- Correct pattern used:
  - `string u = rawReason;`
  - `StringToUpper(u);`
- Applied in:
  - `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`
  - `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`
- Fixed M1 entry control-flow compile issue in `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh`:
  - Resolved `illegal 'else' without matching 'if'`
  - Resolved `not all control paths return a value`
  - Root cause was misplaced context assignments between `if` and `else`; assignments are now before branch evaluation.
- Fixed M5 compile scope issue in `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`:
  - Resolved `undeclared identifier 'balance'`
  - Root cause was `balance` referenced before declaration in `ExecuteTrade()`

## M1 Entry Logic (Refined)

- M1 entry is now ultra-simple for high-frequency EMA pullback scalping.
- Core required conditions:
  - BUY: `Price > EMA20` + `Price near/touch EMA20` + current candle bullish
  - SELL: `Price < EMA20` + `Price near/touch EMA20` + current candle bearish
- Removed from M1 entry:
  - RSI filters
  - score threshold gating
  - previous-candle dependency
  - structure-break confirmation
  - momentum gating layers
- Hard runtime safety retained:
  - spread filter
  - EMA flat-market skip
  - trend-strength filter (`EMA20-EMA50` gap threshold)
  - London/New York session-only filter
  - cooldown controls (5-candle cooldown)
- Signal checks are evaluated on new M1 candles only (not every tick).

## M1 Strategy Simplification

- Removed excessive multi-layer hard filtering from M1 entry.
- Removed score-gate dependencies and indicator-heavy gating.
- Kept only fast core entry pattern + runtime safety filters.

## M1 Entry Upgrade - Structure Break

_Historical note: this mode has been superseded by the simplified scalping model below._

- Entries are no longer taken directly at EMA pullback touch.
- Pullback is tracked first, then confirmation requires a micro-structure break.
- This delayed trigger improves timing by entering on continuation, not during retracement.

## M1 Simplified Scalping Strategy

- Pure price-action entry on EMA20 pullback + candle direction.
- No RSI/score/structure-break dependency in entry trigger.
- Exit profile for scalping/profit-lock:
  - SL target set to `$2.0`
  - Dynamic trailing model:
    Profit `< +1.5` -> no SL move
    `+1.5` -> lock `+$0.5`
    `+2` -> lock `+$1`
    `+3` to `+10` -> lock `profit - 1` (integer levels only)
    `+12+` -> lock `profit - 2` (integer levels only)
  - No fixed TP cap (runner-friendly with lock protection)

## M1 Entry Refinement - Pullback Reversal

_Historical note: this mode has been superseded by the ultra-simple final strategy below._

- Entry now requires a candle-color reversal at pullback (previous opposite, current directional).
- This aims to reach early `+$1` faster for BE/trailing activation in scalping mode.

## M1 Active Rejection Reasons

- `CORE_CONDITION_FAIL`
- `HIGH_SPREAD`
- `COOLDOWN_ACTIVE`
- `COOLDOWN_5CANDLE`
- `COOLDOWN_3CANDLE`
- `TREND_WEAK`
- `MOMENTUM_WEAK`
- `LOW_ATR`
- `LOSS_CLUSTER_COOLDOWN`
- `MAX_TRADES_REACHED`
- `INSUFFICIENT_MARGIN`
- `ORDER_FAILED`
- `RISK_ENGINE_BLOCK`
- `INVALID_TICKVALUE`

## M1 Final Strategy

- Ultra-simple EMA20-based entry for high-frequency scalping.
- No RSI, scoring, structure-break, or multi-layer entry filters.
- Profit-lock exit model:
  - initial SL = `$2.0`
  - dynamic SL lock with runner mode:
    `+1.5 -> +0.5`, `+2 -> +1`, `3..10 -> profit-1`, `12+ -> profit-2`

## M1 Final Profit Engine

- Aggressive trailing ladder tuned for positive expectancy.
- Optimized initial SL (`$2.0`) for improved risk efficiency.
- Controlled trade frequency via 5-candle cooldown.

## Complementary Two-EA Model

- M1 is the **Capital Booster**:
  - Higher trade frequency
  - Fast pullback entries around EMA20
  - Profit-lock ladder for compounding
- M5 is the **Capital Stabilizer**:
  - Lower-frequency trend pullback entries
  - EMA20/EMA50 direction alignment + Asian-only session focus
  - Slightly higher minimum score gating (`80`) for entry stability
  - Unified risk SL with 2R/3R TP targeting
