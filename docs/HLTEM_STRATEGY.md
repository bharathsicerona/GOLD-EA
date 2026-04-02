# HLTEM Strategy (HTF Liquidity to LTF Execution Model)

## 📌 Strategy Overview
The HLTEM strategy is an institutional-grade multi-timeframe model that synchronizes High-Timeframe (HTF) structural bias with Low-Timeframe (LTF) precision execution. It targets high-probability market reversals by identifying liquidity sweeps on M15 and validating them with localized structure shifts on M1.

---

## 🏛️ HTF Context Engine (M15)
The HTF engine establishes the "Market Bias" based on liquidity raids and structural breaks.

### 1. Liquidity Sweep
- **Logic:** Price sweeps the High or Low of the previous 20 candles (Lookback index 2-22) but closes back within the range.
- **Goal:** Identifying stop-hunts or liquidity grabs.

### 2. Close-based BOS (Break of Structure)
- **Logic:** After a sweep, price must close beyond the previous candle's swing high/low to confirm a displacement in trend.
- **BOS Rule:** Candle[1] close must exceed Candle[2] high (Bullish) or low (Bearish).

### 3. Directional Mapping
- **BUY:** Bearish Liquidity Sweep + Bullish BOS.
- **SELL:** Bullish Liquidity Sweep + Bearish BOS.

### 4. Order Block (OB) Identification
- The engine identifies the last opposite-colored candle (the "Order Block") that preceded the BOS. This candle forms the "Kill Zone" for the LTF engine.

---

## 🎯 LTF Execution Engine (M1)
The LTF engine manages the tactical entry once the HTF Bias is confirmed.

### 1. Zone Validation
- Price must be physically residing within the mapped HTF Order Block (M15 OB).

### 2. Market Structure Shift (MSS)
- Price must break the local M1 swing high or low based on a 5-bar fractal.
- **Rule:** Candle[1] close must exceed the highest high or lowest low of the last 5 bars.
- This ensures the shift is based on real structural displacement rather than single-candle noise.

### 3. Impulse Verification
- The displacement move must be strong.
- **Rule:** Candle body size must be > 1.2 * ATR(14).

### 4. Fair Value Gap (FVG)
- Identifying a 3-candle imbalance (FVG).
- **Bullish FVG:** Low[1] > High[3].
- **Bearish FVG:** High[1] < Low[3].

### 5. Entry Rules (v2 Relaxed)
- **Primary:** Price should close inside the defined FVG zone.
- **Secondary (Testing):** Price touches the FVG zone (high/low contact) without requiring a full bar close inside.
- This allows for higher trade frequency during the validation phase.

---

## 🛡️ Risk & Management
- **Lot Size:** Fixed 0.01 lot.
- **Stop Loss (SL):** Placed at the protective side of the FVG zone + 50 points buffer.
- **Take Profit (TP):** Fixed 2.5R (Reward-to-Risk ratio of 2.5).
- **Execution:** Instant execution upon M1 bar close confirmation.

---

## 📊 Pipeline Observability
The EA adheres to the GoldEA logging contract with advanced on-chart visual aids:
- **🔵 Blue Box:** Visualizes the HTF Order Block (OB) zone.
- **🟢/🔴 Dotted Lines:** Highlight the current MSS High/Low break levels.
- **🟡 Yellow Box:** Visualizes the active LTF Fair Value Gap (FVG).

### Key Logs:
- `[HLTEM] HTF_VALID`: Logged when the M15 bias is established.
- `[HLTEM] MSS_BULLISH/BEARISH`: Debug log when a structural shift is detected.
- `[HLTEM] NO_MSS / NO_FVG_TOUCH`: Rejection reasons for LTF failure.
- `[HLTEM] TRADE_PLACED`: Execution receipt with tradeId and risk parameters.

---

## 📁 File Structure
- `EAs/HLTEM/XAUUSD_HLTEM_EA.mq5`: Main entry point and OnTick orchestrator.
- `EAs/HLTEM/XAUUSD_HLTEM_Inputs.mqh`: Unified configuration and Magic Number.
- `EAs/HLTEM/XAUUSD_HLTEM_HTF.mqh`: M15 Bias engine (Liquidity/BOS).
- `EAs/HLTEM/XAUUSD_HLTEM_LTF.mqh`: M1 Execution logic (Swing MSS/FVG).
- `EAs/HLTEM/XAUUSD_HLTEM_Execution.mqh`: Trade sending and risk management.
- `EAs/HLTEM/XAUUSD_HLTEM_Logging.mqh`: Standardized LogTyped wrapper.
- `EAs/HLTEM/XAUUSD_HLTEM_Debug.mqh`: Chart visualization and cleanup.
