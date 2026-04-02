# XAUUSD M1 QuickHands EA

The M1 QuickHands EA is a standalone Expert Advisor designed for fast, pattern-based scalping on the M1 timeframe. It focuses on a specific candlestick pattern ("GG-R" and "RR-G") aligned with the prevailing trend.

## 🧠 Core Strategy: Trend-Aligned Reversion Pattern

The EA follows a simple but effective pattern-based entry logic:

### BUY Pattern: GG-R
- **Condition:** EMA Fast (20) > EMA Slow (50)
- **Candle Pattern:**
    - Candle[3] = GREEN (Bullish)
    - Candle[2] = GREEN (Bullish)
    - Candle[1] = RED (Bearish)
- **Entry:** Executive on Candle[0] (Open of the current candle)

### SELL Pattern: RR-G
- **Condition:** EMA Fast (20) < EMA Slow (50)
- **Candle Pattern:**
    - Candle[3] = RED (Bearish)
    - Candle[2] = RED (Bearish)
    - Candle[1] = GREEN (Bullish)
- **Entry:** Executive on Candle[0] (Open of the current candle)

## 💰 Risk & Money Management

- **Fixed Lot:** 0.01 lot per trade.
- **Fixed Risk SL:** Uses the `GoldEA_Unified_Risk.mqh` engine to enforce a $3 stop loss.
- **Fixed TP:** $15 take profit ($3 risk : $15 reward = 1:5 RR).
- **Trailing Logic:**
    - At +1R profit: Lock in 0.3R or (Profit - 1R).
    - At +2R profit: Lock in (Profit - 1R).

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
