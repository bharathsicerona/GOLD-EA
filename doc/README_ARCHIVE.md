# XAUUSDm MetaTrader 5 Expert Advisors

This project contains a suite of MetaTrader 5 Expert Advisors (EAs) and tools for trading `XAUUSD` (Gold).

### Expert Advisors
1.  **M5 Adaptive Multi-Factor EA**: A dynamic session-based swing/trend trading system.
2.  **M1 High-Frequency Scalper EA**: An aggressive, high-risk scalping system designed for rapid account growth.
3.  **M5 Beginner Trend Pullback EA**: A simplified, easy-to-understand version for learning purposes.

### Support & Analysis Tools
*   `GoldEA_Common_Core.mqh`: A shared library of helper functions reused by the other EAs.
*   `analyze_ea_logs.py`: A Python tool for analyzing and summarizing MT5 backtest logs.

---

## EA 1: M5 Adaptive Multi-Factor EA (`XAUUSD_Adaptive_MultiFactor_EA.mq5`)

This EA combines multiple strategies and indicators to adapt to changing market conditions on the M5 timeframe.

### Strategy Summary

The EA dynamically switches strategies based on the current trading session and market volatility.

*   **Range Strategy (Low Volatility / Asian Session):** Trades Bollinger Band reversals when RSI is at an extreme.
*   **Breakout Strategy (London Session):** Trades breakouts of the established Asian session high/low.
*   **Trend Strategy (New York Session):** Trades trend-continuation pullbacks using EMA alignment and RSI.

### Entry Logic

*   **Range (Buy):** Price near lower Bollinger Band AND RSI indicates oversold.
*   **Range (Sell):** Price near upper Bollinger Band AND RSI indicates overbought.
*   **Breakout (Buy):** Price breaks above the recorded Asian session high.
*   **Breakout (Sell):** Price breaks below the recorded Asian session low.
*   **Trend (Buy):** Price > slow EMA, fast EMA > slow EMA, and price pulls back to the fast EMA.
*   **Trend (Sell):** Price < slow EMA, fast EMA < slow EMA, and price pulls back to the fast EMA.

### Risk & Trade Management

*   **Risk:** Calculates lot size based on a fixed percentage risk per trade (e.g., 1%).
*   **Stop Loss:** Uses an ATR-based multiple for the initial stop loss.
*   **Take Profit:** Targets a specified Reward:Risk ratio.
*   **Profit Locking:** Includes logic for partial-closes, break-even stops, and ATR-based trailing stops.

### Optional Scoring System

The EA can use a weighted scoring system (0-100) to grade trade setups. Each condition (trend, momentum, RSI, etc.) contributes to the score. An entry can be configured to only trigger if its score exceeds a minimum threshold (e.g., 80), filtering out weaker setups.

---

## EA 2: M1 High-Frequency Scalper EA (`XAUUSD_M1_Scalper_EA.mq5`)

This is a dedicated high-frequency EA engineered for the **M1 timeframe**. It leverages explosive short-term momentum using high-risk, high-reward principles.

### Core Strategy (EMA + RSI Momentum Pullbacks)

*   **Trend Confirmation:** Price must be on the correct side of the `EMA 50`.
*   **Momentum Burst:** `EMA 20` must have crossed the `EMA 50`.
*   **Volatility Filter:** ATR must exceed a minimum threshold to ensure the market has enough energy.
*   **RSI Velocity:** RSI must reside in a strong but non-exhausted zone.
*   **The Trigger:** The entry is sparked when price sharply pulls back toward the `EMA 20`.

*(Note: The latest version of this EA uses the `ValidateEntry` function, which relies on a series of hard filters rather than a scoring system).*

### High-Risk Features

*   **Aggressive Lot Sizing:** Designed to use a higher risk per trade (e.g., 3-5% or more).
*   **Force Minimum Lot:** By default, if the calculated lot size is below the broker's minimum, the EA will **force the trade** using the minimum lot size. This is crucial for growing low-capital accounts.
*   **Step-Based Trailing Stop:** An aggressive profit-locking mechanism that moves the SL to fixed dollar amounts as profit targets are hit (e.g., at $2 profit, SL moves to lock $1).
*   **Dynamic Take Profit:** The Take Profit target is automatically extended as the trade moves further into profit, allowing winning trades to run.

---

## EA 3: M5 Beginner Trend Pullback EA (`XAUUSD_Beginner_Trend_Pullback_EA.mq5`)

This is a simplified "training-wheels" version of the project. It uses a clean trend-pullback strategy and is designed for traders who want to understand the core logic before using the more advanced EAs.

---

## Log Analyzer (`analyze_ea_logs.py`)

This Python script parses MT5 backtest logs (`.log` files) that contain output from the EAs. It extracts key data points and generates a summary report.

### How to Run
```bash
# Basic analysis
python analyze_ea_logs.py logs

# Export detailed reports
python analyze_ea_logs.py logs --export-summary-csv logs/summary.csv --export-events-csv logs/events.csv
```

### Calculated Metrics
*   Total Signals vs. Trades Executed
*   Win/Loss Rate (if outcome is logged)
*   Most Common Rejection Reasons
*   Session-based Activity Breakdown

---

## Installation

1.  Open MetaTrader 5.
2.  Click `File -> Open Data Folder`.
3.  Navigate to the `MQL5/Experts/` directory.
4.  Copy the EA file (`.mq5`) and all of its associated include files (`.mqh`) into this folder.
    *   **Crucially**, all `.mqh` files must be in the **same folder** as the `.mq5` file.
5.  Open `MetaEditor` from MT5.
6.  In the MetaEditor navigator, find the `.mq5` file you just copied. Double-click to open it.
7.  Press `F7` or click `Compile`. If successful, you will see "0 error(s), 0 warning(s)".
8.  Return to MT5. In the `Navigator` panel, right-click `Expert Advisors` and choose `Refresh`.
9.  Drag the newly compiled EA onto a chart.
10. In the `Inputs` tab, review the settings. In the `Common` tab, ensure `Allow Algo Trading` is checked.
11. Click `OK`. A smiley-face icon in the top-right of the chart indicates the EA is running.
