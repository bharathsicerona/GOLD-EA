# XAUUSD M1 Scalper EA

The M1 Scalper EA has been upgraded to a multi-strategy collaboration model with enhanced intelligence. It evaluates multiple strategies and uses a signal interaction engine with a priority-based rule set to make a final trading decision.

- **Strategies & Signal Quality:**
    -   **`M1_LIQUIDITY_SWEEP`:** A high-priority strategy that enters after a liquidity sweep. Marked as a strong signal with override power.
    -   **`M1_BREAKOUT`:** Enters on price breaking recent structure with ATR expansion and strong candle quality (body > 60% of range). Weak breakouts are filtered out.
    -   **`M1_EMA_PULLBACK`:** A neutral signal that enters on a price pullback to the EMA20 in a confirmed trend.
    -   **`M1_REVERSAL`:** A weak signal that enters on RSI extremes with an engulfing candle pattern. Only considered if aligned with a liquidity sweep.
- **Signal Interaction Engine:**
    - Processes signals from all strategies based on a strict priority order.
    - Handles conflicts, confirmations, and overrides to filter for high-quality trades.
- **Strategy Feedback Manager:**
    - Manages open trades by reacting to new signals.
    - Can extend TP on confirming signals, tighten SL on opposing signals, or perform an immediate exit if a strong override signal (liquidity sweep) appears against the trade.

Primary documentation:

- Project overview: [README](../../README.md)
- Detailed runtime map: [PROJECT_INDEX](../../PROJECT_INDEX.md)
- Current M1 analysis context: [cursor_info](../../cursor_info.md)
