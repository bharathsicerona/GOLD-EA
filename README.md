# Gold Trading EAs for MetaTrader 5

This project contains a collection of Expert Advisors (EAs) for automated trading of Gold (XAUUSD) on the MetaTrader 5 platform. It includes multiple strategies, shared libraries, and a Python script for advanced log analysis.

## Limit Execution Update

-   M1 QuickHands, M1 Scalper, M5 Adaptive, and HLTEM now place **limit orders** instead of entering at market.
-   Existing entry validation and SL/TP calculations are preserved; only the execution method changed.
-   Pending orders expire after **2 candles** if unfilled.
-   Limit entries are now normalized against broker stop-distance rules, and SL is recalculated after any entry-price shift.
-   Cross-EA safety now blocks new entries if **any** pending order already exists on the same symbol.
-   Logging flow is now:
    *   `ORDER` for `LIMIT_PLACED`
    *   `EXECUTION` only when the limit order is actually filled

## Project Structure

The project is organized into a clean and modular structure to ensure clarity and maintainability.

```
.
├── EAs/
│   ├── Adaptive/         # M5 Adaptive Multi-Factor EA
│   ├── M1_Scalper/       # M1 High-Risk Scalper EA
│   ├── HLTEM/            # M15->M1 Multitimeframe Liquidity EA
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

This project includes five active Expert Advisors. Each has its own dedicated folder within the `EAs/` directory, containing the main `.mq5` file, any specific `.mqh` include files, and a detailed `README.md`.

### 1. M5 Adaptive Multi-Factor EA (Capital Stabilizer)

-   **Folder:** `EAs/Adaptive/`
-   **Role:** Capital Stabilizer (lower-frequency, higher-quality trades on M5).
-   **Architecture:** Uses a **Market Mode Engine** to detect the regime (TREND or BREAKOUT) before executing a signal.
-   **Strategies:**
    -   **`M5_TREND_PULLBACK`:** Enters on pullbacks to the fast EMA during a detected trend mode.
    -   **`M5_ATR_BREAKOUT`:** Captures high-momentum breakout events confirmed by ADX and ATR expansion.
-   **Key Features:**
    -   **Market Awareness:** Detects market mode first; skips trading if conditions are weak.
    -   **Hard Pre-filters:** Strict ADX and ATR-based filtering to reduce signal noise.
    -   **Session Limits:** Enforces a maximum of 2 trend trades and 1 breakout trade per session.
-   **Risk & Trade Management:**
    -   **Strategy-Specific Risk:** Custom SL/TP ratios per strategy (e.g., 1:2.5 for Trend, 1:4.0 for Breakout).
    -   **Advanced Trailing:** R-Multiple based trailing stop system optimized for each strategy.
-   **More Info:** See the [M5 Strategy Documentation](docs/M5_STRATEGY.md) and `EAs/Adaptive/README.md`.


### 2. M1 High-Risk Scalper EA (Capital Booster)

-   **Folder:** `EAs/M1_Scalper/`
-   **Role:** Capital Booster (higher-frequency scalping on M1).
-   **Active Strategy:** The current production path is a single-strategy trend continuation model: `M1_TREND_RSI_CONTINUATION`.
    -   **Trend Structure:** EMA20 vs EMA50 for fast trend direction.
    -   **Higher-Timeframe Bias:** EMA100 acts as a directional filter.
    -   **Momentum Confirmation:** RSI must support the trade direction and remain out of exhausted zones.
    -   **Execution Style:** new-bar only, candle-close driven.
-   **Key Filters:**
    -   Adaptive ATR filter, trend-strength filter, chop filter, and two-candle weakness filter.
    -   Hard spread filter and cooldown gating.
    -   Session-awareness is available through inputs and filter logic.
    -   Elite upgrade adds auto mode switching (`SAFE` / `NORMAL` / `AGGRESSIVE`), pullback distance checks, explosive-mode validation, and pro spread filtering.
-   **Risk & Trade Management:**
    -   Uses `GoldEA_Unified_Risk.mqh` through `CalculateTradeRisk()`.
    -   Shared fixed monetary path currently uses `$4` risk for `0.01` lot, `$8` for `0.02` lot, and `1%` of balance for larger trades.
    -   M1 also uses the ATR-clamped dynamic stop path when ATR distance is passed into the risk engine.
    -   Active in-trade management is the simplified `ManageTrendRSIContinuation()` lock-and-trail flow.
    -   Recent patch fixes R-multiple calculation, broker-safe stop validation, and duplicate SL-update prevention.
-   **More Info:** See the `EAs/M1_Scalper/README.md` for a detailed explanation of its aggressive profit-taking mechanisms.

### M1 Adaptive Filter Layer

The M1 Scalper includes an Adaptive Filter Layer that runs before the single active strategy is evaluated. This layer analyzes volatility, trend strength, chop, candle quality, and session context to reduce low-quality entries. For more details, see the [M1 Filter Layer Documentation](docs/M1_FILTER_LAYER.md).

### 3. M1 QuickHands EA (Capital Accelerator)

-   **Folder:** `EAs/M1_QuickHands/`
*   **Role:** Capital Accelerator (pattern-based scalping on M1).
*   **Strategy:** Liquidity Sweep + Momentum Confirmation (**LSMC**) on bar close. BUY uses `RRG` sweep-low continuation, SELL uses `GGR` sweep-high continuation, with Candle 1 EMA50 bias and mandatory structure break.
*   **Dashboard:** Shows sweep / rejection / confirmation state, ATR, spread, blocked reason, live profit, current dollar lock level, and SL in USD.
*   **Active Filters:** High spread, low ATR versus ATR average, no-liquidity-sweep, weak rejection, weak confirmation, weak C1 body, weak context body, EMA bias, and optional micro-trend filtering.
*   **Key Pipeline Filters:**
    *   **GGR/RRG Pattern:** Enters on a specific 3-candle sequence (Closed shifts 1, 2, 3).
    *   **Shallow Pullback Rule:** Rejects trades if the trigger candle's range is >= 60% of the initial impulse.
    *   **Mandatory Candle Quality:** ALL 3 candles must be "Strong" (Body >= 50% of range).
    *   **EMA Confirmation:** Enforces trend alignment (Fast > Slow for BUY, Fast < Slow for SELL).
    *   **Elite fast-trend layer:** adds EMA100 bias, EMA20 slope check, RSI momentum filter, auto mode switch, pullback distance filter, and explosive-mode option.
*   **Risk & Trade Management:**
    *   QuickHands now opens with a fixed initial stop loss of **$5** and **no take profit**.
    *   QuickHands-only aggressive dollar lock now follows `+$1 -> lock $0.5`, and from `+$2` onward locks `(profit - 1)$` dynamically.
    *   Recent patch keeps stop-level validation and trailing-state persistence isolated to QuickHands.
-   **More Info:** See the [M1 QuickHands Strategy Documentation](docs/M1_QUICKHANDS_STRATEGY.md) and `EAs/M1_QuickHands/README.md`.

### 4. Beginner Trend Pullback EA

-   **Folder:** `EAs/Beginner/`
-   **Strategy:** A simple, easy-to-understand trend-following strategy that enters on pullbacks to a moving average.
-   **Risk Model:** Basic, percentage-based risk.
-   **More Info:** This EA is self-contained in a single file for simplicity and is a great starting point for learning EA development.

### 4. HLTEM (HTF Liquidity to LTF Execution) EA

-   **Folder:** `EAs/HLTEM/`
-   **Role:** Institutional Liquidity Model (bi-timeframe).
-   **Architecture:** Uses a **dual-timeframe pipeline** (M15 Context -> M1 Execution).
-   **Strategy:**
    -   **HTF Bias (M15):** Detects liquidity sweeps of previous 20-candle highs/lows and confirms via close-based Break of Structure (BOS).
    -   **LTF Tactics (M1):** Once bias is set, price must enter the HTF Order Block, trigger a swing-based Market Structure Shift (MSS), and confirm via Fair Value Gaps (FVG).
-   **Key Features:**
    -   **Institutional Precision:** Synchronizes HTF liquidity raids with LTF tactical entries.
    -   **Visual Debugging:** Advanced on-chart visualization for Order Blocks (Blue), MSS levels (Green/Red), and FVG zones (Yellow).
    -   **Rules:** v2 Relaxed mode enables FVG touches for higher trade frequency during testing.
-   **Risk & Trade Management:**
    -   **Fixed R-Risk:** Fixed 0.01 lot entries with 2.5R Take Profit targets.
    -   **Structure-based SL:** Stops are placed behind the FVG edge with a 50-point buffer.
-   **More Info:** See the [HLTEM Strategy Documentation](docs/HLTEM_STRATEGY.md) and `EAs/HLTEM/README.md`.

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

- Structured logging format is implemented for the active GoldEA families:
  - `[M1_SCALPER][GoldEA][TYPE] ...`
  - `[M5][GoldEA][TYPE] ...`
  - `[M1_QUICKHANDS][GoldEA][TYPE] ...`
- Standard log types:
  - `CHECK` for signal evaluation
  - `EXECUTION` for order placement
  - `REJECTION` for skipped/blocked trades with explicit reason
  - `RESULT` for SL/TP/BE lifecycle events
  - `MGMT` for active trade intelligence and management (e.g., Reversal-based tightening)
  - `STATS` for periodic internal counter snapshots
- Trade lifecycle is fully logged with `tradeId`, `score`, `atr`, `spread`, and `reason` fields.
- The Python analyzer now supports current and mixed legacy prefixes, but some older logs still contain historical strategy names and auxiliary event tags.
- Current M1 check format:
  - `[M1_SCALPER][GoldEA][CHECK] [M1_TREND_RSI_CONTINUATION] BUY check: ... reason=VALID`
- Current M1 execution/result format:
  - `[M1_SCALPER][GoldEA][EXECUTION] [M1_TREND_RSI_CONTINUATION] BUY executed: tradeId=... lot=... entry=... sl=... tp=...`
  - `[M1_SCALPER][GoldEA][RESULT] [M1_TREND_RSI_CONTINUATION] TAKE_PROFIT_HIT tradeId=... profit=...`
