# XAUUSD M1 Scalper EA

The M1 Scalper EA has been upgraded to a multi-strategy collaboration model with enhanced intelligence. It evaluates multiple strategies and uses a signal interaction engine with a priority-based rule set to make a final trading decision.

- **Core Entry Strategies:**
    -   **`M1_LIQUIDITY_SWEEP`:** High-priority strategy; enters after price sweep of recent highs/lows.
    -   **`M1_BREAKOUT`:** Enters on recent structure break with ATR expansion.
    -   **`M1_EMA_PULLBACK`:** Enters on price pullback to EMA20 in a confirmed trend.
- **Management Intelligence (Reversal Layer):**
    -   **`M1_REVERSAL`:** Formerly an entry strategy, now an in-trade intelligence layer. Monitors RSI and engulfing candles to proactively manage open trades.
- **Strategy Feedback Manager (Enhanced):**
    - Now located in the management header, it integrates the **Reversal Layer** to:
        - **Tighten SL:** If a reversal forms against the trade.
        - **Extend TP:** If a reversal supports the trade (Boost Mode).
        - **Early Exit:** Closes trade profitably if a strong reversal forms against it.
        - **Legacy Feedback:** Still handles same-direction confirmation and opposite signal conflict management.

Primary documentation:

- Project overview: [README](../../README.md)
- Detailed runtime map: [PROJECT_INDEX](../../PROJECT_INDEX.md)
- Current M1 analysis context: [cursor_info](../../cursor_info.md)
