# XAUUSD M1 QuickHands EA

The M1 QuickHands EA is a standalone Expert Advisor designed for fast, pattern-based scalping on the M1 timeframe. It focuses on a specific candlestick pattern ("GGR" and "RRG") aligned with the prevailing trend.

## 🧠 Core Strategy: Trend-Aligned Reversion Pattern

The EA follows a simple but effective pattern-based entry logic:

### BUY Pattern: GGR
- **Condition:** EMA Fast (20) > EMA Slow (50)
- **Candle Pattern (Old -> New):**
    - Candle[3] = GREEN
    - Candle[2] = GREEN
    - Candle[1] = RED
- **Pullback Rule:** `(C1 Range) < 0.6 * (C2 High - C3 Low)`
- **Entry:** Open of Candle[0]

### SELL Pattern: RRG
- **Condition:** EMA Fast (20) < EMA Slow (50)
- **Candle Pattern (Old -> New):**
    - Candle[3] = RED
    - Candle[2] = RED
    - Candle[1] = GREEN
- **Pullback Rule:** `(C1 Range) < 0.6 * (C3 High - C2 Low)`
- **Entry:** Open of Candle[0]

## 💰 Risk & Money Management

- **Fixed Lot:** 0.01 lot per trade.
- **Initial Stop Distance:** Built from the entry module using a hybrid structure/ATR model.
- **Risk Clamp:** Entry logic clamps the prepared stop distance into a practical `4.0` to `6.0` price-distance band.
- **Fixed TP:** Current execution path targets **3R**, not 5R.
- **Trailing Logic:**
    - No change before `2R`.
    - At `2R`, move stop to about `+1R`.

## 📊 Standardized Logging

This EA follows the GoldEA logging contract strictly for full compatibility with the Python `analyze_ea_logs.py` script:

- **Prefix:** `[M1_QUICKHANDS][GoldEA]`
- **Log Types:**
    - `[CHECK]`: Emitted on every new bar check.
    - `[EXECUTION]`: Emitted when a trade is successfully opened.
    - `[MGMT]`: Emitted on trailing stop updates.
    - `[RESULT]`: Emitted when a trade is closed (SL, TP, or manual).

## 🚀 Performance Insights

The EA is designed to be fully traceable via the GoldEA Analytics suite, providing detailed metrics on pattern success rates and trailing efficiency.
