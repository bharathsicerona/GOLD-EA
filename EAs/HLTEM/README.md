# HLTEM Expert Advisor (M15 Context -> M1 Execution)

## 📌 Overview
HLTEM is an institutional-grade multi-timeframe liquidity model designed for XAUUSD. It captures high-probability reversals by combining High-Timeframe (HTF) liquidity raids with Low-Timeframe (LTF) tactile execution.

---

## 🏛️ How It Works
The EA follows a strict three-step pipeline:

1.  **HTF Bias (M15):** 
    - Identifies **Liquidity Sweeps** (price takes out a 20-candle high/low and closes back).
    - Confirms via a **Break of Structure (BOS)** on the M15 close.
    - Maps the **Order Block (OB)** where the move originated.

2.  **LTF Precision (M1):**
    - Waits for price to re-enter the mapped HTF Order Block.
    - Triggers a **Market Structure Shift (MSS)** on M1 (5-bar swing break).
    - Detects **Fair Value Gap (FVG)** imbalances.

3.  **Tactical Entry:**
    - Executes on any **touch** or **close** within the M1 FVG zone (v2 Relaxed Rule).
    - Enforces a fixed **2.5R Reward-to-Risk ratio**.

---

## 🎨 Chart Visualization
HLTEM provides advanced on-chart diagnostic aids for setup transparency:
- **🔵 Blue Box:** HTF Order Block Zone.
- **🟢/🔴 Dotted Lines:** Active M1 MSS High/Low breakout levels.
- **🟡 Yellow Box:** Active M1 Fair Value Gap (FVG).

---

## 🛠️ Configuration
| Input | Default | Purpose |
| --- | --- | --- |
| `InpMagicNumber` | 4012026 | Unique trade identifier for state tracking |
| `InpTradeLot` | 0.01 | Fixed lot size for testing phase |
| `InpRewardRatio` | 2.5 | Fixed TP target relative to stop distance |
| `InpSlBufferPoints`| 50 | Safety buffer points added to FVG SL edge |

---

## 📁 Document Links
- [Complete Strategy Guide](../../docs/HLTEM_STRATEGY.md)
- [Project Inventory](../../PROJECT_INDEX.md)
- [Project Root README](../../README.md)
