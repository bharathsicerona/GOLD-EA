# 🚀 M1 QuickHands Strategy (Capital Accelerator)

M1 QuickHands is a high-frequency, pattern-based Expert Advisor for Gold (XAUUSD) designed to capture quick trend-resumption impulses on the M1 timeframe.

## 🎯 Strategy Objective
The strategy exploits a specific candlestick sequence (**GG-R** or **RR-G**) that occurs during a confirmed EMA trend. It assumes that a single opposing candle against the trend is often a brief pause before the trend resumes with momentum.

---

## 🧠 Core Entry Logic

### Indicators
- **EMA Fast:** 20 Periods (Close)
- **EMA Slow:** 50 Periods (Close)
- **ATR:** 14 Periods

### BUY Signal: GG-R Pattern
1. **Trend Context:** EMA 20 > EMA 50 (Strong Upward Trend).
2. **Candlestick Sequence (M1):**
   - `Candle [3]`: **Green** (Bullish)
   - `Candle [2]`: **Green** (Bullish)
   - `Candle [1]`: **Red** (Bearish Pullback)
3. **Trigger:** Enter **Buy** at the open of `Candle [0]`.

### SELL Signal: RR-G Pattern
1. **Trend Context:** EMA 20 < EMA 50 (Strong Downward Trend).
2. **Candlestick Sequence (M1):**
   - `Candle [3]`: **Red** (Bearish)
   - `Candle [2]`: **Red** (Bearish)
   - `Candle [1]`: **Green** (Bullish Pullback)
3. **Trigger:** Enter **Sell** at the open of `Candle [0]`.

---

## 🛑 Filters & Risk Engine

### Filters
- **Dynamic ATR Filter:** Rejects trades if ATR is below `InpMinAtrPoints`.
- **Candle Quality Filter:** All 3 setup candles (C1, C2, C3) must have a **Body ≥ 50%** of their total High-Low range.
- **EMA Confirmation Filter:** If the origin candle (**C3**) is on the wrong side of the EMA Fast, then the signal candle (**C1**) must have crossed and closed back on the correct side to confirm momentum.
- **Spread Filter:** Blocks execution if the real-time spread exceeds `InpMaxSpreadPoints`.

### Risk Management
- **Initial Stop Loss:** Hybrid model between Structure Wick and ATR.
  - **Structure SL:** Uses `Low[3]` (BUY) or `High[3]` (SELL) as the primary base.
  - **ATR SL:** `ATR(14, 1) * 0.8`.
  - **Hybrid Selection:** `MathMin(StructureDist, ATRDist * 1.5)`.
  - **Safety Clamps (Entry Only):** Minimum **4.0** points ($4.00) and Maximum **6.0** points ($6.00).
  - **R-Model:** The final SL distance is defined as **1R**.
- **Take Profit:** Fixed at **3.0R** (3:1 RR Ratio).

---

## 🔄 R-Multiple Management (BE+1R)
The EA uses a structured R-based management system instead of continuous trailing:

| Price Action | Management Action |
| :--- | :--- |
| **Price < +2.0R** | Hold initial 1R Stop Loss. |
| **Price hits +2.0R** | Move SL to **+1.0R** (Locking in 1R profit). |
| **Price hits +3.0R** | Target reached (TP). |

This ensures a minimum 1:1 RR is bankable once the trade reaches a high-probability extension point.

---

## 📈 Logging & Analytics
M1 QuickHands is fully integrated with the **GoldEA Analytics Suite**:

- **Prefix:** `[M1_QUICKHANDS][GoldEA]`
- **Extra Metadata:** Logs the specific `pattern` (GG-R/RR-G) in every CHECK and EXECUTION event.
- **Management Logs:** Emits `[MGMT] TRAIL_UPDATE` logs with `lockedR` fields for performance tracking.

## 🐍 Python Parser Integration
The `scripts/analyze_ea_logs.py` script specifically calculates:
- Overall Win Rate vs Pattern Success Rate.
- Average/Max Locked R multiples.
- Execution speed and ATR efficiency.
