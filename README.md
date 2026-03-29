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

### 1. M5 Adaptive Multi-Factor EA (Capital Stabilizer)

-   **Folder:** `EAs/Adaptive/`
-   **Role:** Capital Stabilizer (lower-frequency, higher-quality trades on M5).
-   **Strategy:** A sophisticated multi-factor model that adapts to changing market conditions by selecting from several independent strategies based on the active trading session:
    -   **`M5_RANGE` (Asian Session):** Buys on RSI < 35 with bullish candle, sells on RSI > 65 with bearish candle.
    -   **`M5_BREAKOUT` (London Session):** Places pending orders to capture breakouts of the Asian session high/low.
    -   **`M5_TREND_PULLBACK`:** Enters on pullbacks to the fast EMA in a confirmed trend.
    -   **`M5_ATR_BREAKOUT` (London/NY):** Enters on high-momentum breakouts confirmed by ADX and ATR expansion.
-   **Risk & Trade Management:**
    -   Uses the shared `GoldEA_Unified_Risk.mqh` engine, with a special override for `0.01` lot trades to use a `$10` stop loss.
    -   Features an advanced R-Multiple based trailing stop system to lock in profits at key thresholds (`1R`, `1.5R`, `2R`, `2.5R`).
-   **More Info:** See the `EAs/Adaptive/README.md` for a full breakdown of the strategy and its parameters.

### 2. M1 High-Risk Scalper EA (Capital Booster)

-   **Folder:** `EAs/M1_Scalper/`
-   **Role:** Capital Booster (higher-frequency scalping on M1).
-   **Strategy:** An aggressive, high-frequency scalping strategy that evaluates four independent entry models (EMA Pullback, Breakout, Reversal, and Liquidity Sweep) on each new bar. It uses a signal interaction engine to process the signals and decide on a final trade action based on a set of rules, including intelligent filtering of weak signals.
    -   **`M1_EMA_PULLBACK`:** Enters on a price pullback to the EMA20 in a confirmed trend.
    -   **`M1_BREAKOUT`:** A tick-level strategy that enters on price breaking recent highs/lows with ATR expansion and strong candle quality. Weak breakouts are filtered out.
    -   **`M1_REVERSAL`:** Enters on extreme RSI levels combined with a strong engulfing candle pattern. Only considered if aligned with a liquidity sweep.
    -   **`M1_LIQUIDITY_SWEEP`:** A new strategy that enters after a liquidity sweep, where the price takes out a previous high/low and then reverses. This signal has override priority.
-   **Key Filters:**
    -   Session restricted to London & New York.
    -   Hard filters for minimum ATR and maximum spread.
    -   Controls for trade frequency, including a 5-candle cooldown and a loss-cluster guard.
-   **Risk & Trade Management:**
    -   Uses the shared `GoldEA_Unified_Risk.mqh` engine: risk is capped at `$3` for `0.01` lot, `$6` for `0.02` lot, and `1%` of balance for larger trades.
    -   Employs an aggressive R-based trailing stop to lock in profits and let runners continue (`1R -> BE`, `1.5R -> +0.5R`, `2R -> trail by 1R`).
    -   Includes an in-trade `StrategyFeedbackManager` to dynamically manage open positions based on new signals.
-   **More Info:** See the `EAs/M1_Scalper/README.md` for a detailed explanation of its aggressive profit-taking mechanisms.

### M1 Adaptive Filter Layer

The M1 Scalper now includes an Adaptive Filter Layer that runs before any strategies are evaluated. This layer analyzes the current market conditions and prevents trades when the environment is unfavorable, which improves win rates and reduces overtrading. The filters include checks for dynamic ATR, trend strength, chop, candle quality, and session-specific conditions. For more details, see the [M1 Filter Layer Documentation](docs/M1_FILTER_LAYER.md).

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

The project includes a powerful Python script (`scripts/analyze_ea_logs.py`) to parse and analyze the standardized log files produced by the EAs. It provides deep insights into EA performance beyond what the MT5 tester offers.

### Key Features

-   **Performance Summary:** Generates a detailed console report with key metrics like win rate, total trades, and profitability for each EA.
-   **Advanced Analytics:** Calculates R-multiples, win rates per session (Asian, London, New York), and performance for BUY vs. SELL trades.
-   **Rejection Analysis:** Identifies and counts the top reasons trades were skipped (e.g., `HIGH_SPREAD`, `COOLDOWN_ACTIVE`).
-   **Trade Lifecycle Tracking:** Reconstructs the full lifecycle of each trade from entry to exit, ensuring accurate accounting.
-   **Automated Exports:** Automatically saves structured data (`events.csv`, `summary.csv`, `data.json`) to the `log_analysis_output/` directory for further analysis in tools like Excel or Pandas.

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
- M1 check log format now dynamically includes the strategy name:
  - `[M1_SCALPER][GoldEA][CHECK] [M1_BREAKOUT] BUY check: rsi=... ema20=... ema50=... score=... atr=... spread=... decision=... reason=...`
  - Same structure for `SELL check`.
- M1 execution/result log formats:
  - `[M1_SCALPER][GoldEA][EXECUTION] BUY executed: tradeId=... lot=... entry=... sl=... tp=...`
  - `[M1_SCALPER][GoldEA][RESULT] STOP_LOSS_HIT tradeId=... profit=...`
  - `[M1_SCALPER][GoldEA][RESULT] TAKE_PROFIT_HIT tradeId=... profit=...`
