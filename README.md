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

### 1. M5 Adaptive Multi-Factor EA

-   **Folder:** `EAs/Adaptive/`
-   **Strategy:** A sophisticated multi-factor model that adapts to changing market conditions on the M5 timeframe. It dynamically selects from multiple sub-strategies (e.g., Trend, Range, Breakout) based on a scoring system.
-   **Risk Model:** Fixed monetary stop-loss model shared with M1:
    - 0.01 lot -> SL risk = $3
    - 0.02 lot -> SL risk = $6
    - 0.03+ lots -> SL risk = 1% of account balance
    TP remains RR-based from the computed SL distance.
-   **More Info:** See the `EAs/Adaptive/README.md` for a full breakdown of the strategy and its parameters.

### 2. M1 High-Risk Scalper EA

-   **Folder:** `EAs/M1_Scalper/`
-   **Strategy:** An aggressive, high-frequency scalping strategy designed for the M1 timeframe. It aims to capture small, rapid price movements.
-   **Entry Quality Update:** M1 now uses a final price-action pullback model:
    - Pullback is price-based: close near `EMA20` (stateful detection)
    - Entry confirmation is candle-structure based (body direction + close near candle extreme)
    - Wick rejection required (lower wick for BUY, upper wick for SELL)
    - Trend gate uses price vs EMA20 (`Price > EMA20` for BUY, `Price < EMA20` for SELL)
    - RSI is secondary support only (`RSI > 50` for BUY, `RSI < 50` for SELL), with no RSI momentum dependency
    - Strong-candle boost: extra quality score when current candle body > previous candle body
    - Hard rejects: `RSI_OVERBOUGHT` (BUY, RSI>75), `RSI_OVERSOLD` (SELL, RSI<25)
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
- Automatic rejection-reason extraction (`LOW_SCORE`, `HIGH_SPREAD`, `INSUFFICIENT_MARGIN`, `COOLDOWN_ACTIVE`, `SESSION_BLOCK`).
- Mixed-file EA separation (M1 and M5 split safely in a single run).
- Improved trade linking using `tradeId` first, then timestamp+direction fallback when IDs are missing.

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
  - M5 SL-changing management blocks are gated off in fixed-SL mode

## Risk Model Update

- Fixed SL:
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

## M1 Entry Logic (Refined)

- M1 entry now uses delayed structure-break confirmation after pullback.
- Core required conditions:
  - BUY: `Price > EMA20` + pullback near `EMA20`
  - SELL: `Price < EMA20` + pullback near `EMA20`
- Entry confirmation:
  - BUY requires break above previous candle high after pullback
  - SELL requires break below previous candle low after pullback
- Delay rule:
  - Wait at least 1 candle after pullback detection before entry confirmation.
- Boost score model (trade if score `>= 2`):
  - `+1` RSI aligned (BUY `RSI>50`, SELL `RSI<50`)
  - `+1` wick rejection
  - `+1` strong candle body (current > previous)
  - `+1` strong EMA alignment
  - `+1` optional micro-structure quality (higher-low/lower-high)
- Hard blocks kept minimal:
  - Spread too high
  - RSI extremes (BUY `>80`, SELL `<20`)
  - Cooldown/frequency controls in EA runtime
- Signal checks are evaluated on new M1 candles only (not every tick).

## M1 Strategy Simplification

- Removed excessive multi-layer hard filtering from M1 entry.
- Converted non-core conditions into score boosts instead of absolute blockers.
- Reduced dependency on strict indicator gating for more realistic execution.

## M1 Entry Upgrade - Structure Break

- Entries are no longer taken directly at EMA pullback touch.
- Pullback is tracked first, then confirmation requires a micro-structure break.
- This delayed trigger improves timing by entering on continuation, not during retracement.

## M1 Entry Final Model

- Pullback is now defined using EMA20 proximity instead of RSI pullback bands.
- Entry is confirmed by candle structure and wick rejection before execution.
- RSI remains a secondary directional support filter only (no momentum/slope checks).
- Final trigger quality is price-action-led, with optional strong-candle boost.
