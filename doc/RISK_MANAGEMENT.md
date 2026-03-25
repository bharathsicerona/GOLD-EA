# Risk Management System Documentation (v1.0)

## 1. Overview

This document outlines the unified risk management engine implemented across all Gold-trading Expert Advisors (EAs), including the M1 Scalper and M5 Conservative strategies. The system is designed to enforce strict capital preservation rules, enhance scalability, and ensure consistent risk behavior without interfering with the core entry logic of the EAs.

The risk engine automatically adjusts trade parameters (Lot Size and Stop Loss) *before* an order is sent to the broker, based on a set of two primary rules.

---

## 2. Core Risk Models

The system operates on a dual-model basis, automatically selecting the rule based on the trade's lot size.

### Rule A: Fixed $10 Risk Cap (for Minimum Lot Trades)

This rule is designed to protect small accounts and control the absolute downside of the smallest possible trades.

*   **Applies When:** The trade's lot size is the broker's minimum (typically `0.01`).
*   **Logic:**
    1.  The system calculates the monetary risk of the trade based on its proposed Stop Loss distance (`Risk = SL distance in price × Tick Value × Lot Size`).
    2.  If the calculated `Risk` is **greater than $10.00**, the system will **reduce the Stop Loss distance** until the risk is exactly $10.00.
    3.  The trade is then executed with the original `0.01` lot but with the new, tighter Stop Loss.
    4.  **Safety Check:** If the adjusted Stop Loss is closer than the broker's minimum required distance (`Stops Level`), the trade is aborted to prevent an invalid order error.
*   **Log Message:** `RISK LOG: Rule 'Fixed $10 cap' applied. SL adjusted from [X] to [Y]. Lot: 0.01, Risk: $10.00`

### Rule B: Dynamic 1% Risk (for All Other Trades)

This rule ensures that as the account grows or shrinks, the risk per trade remains a consistent percentage of equity, promoting scalable and sustainable growth.

*   **Applies When:** The trade's lot size is greater than the broker's minimum (e.g., `0.02` or higher, or when auto-calculation is used).
*   **Logic:**
    1.  The system **ignores the EA's incoming lot size**.
    2.  It calculates the maximum acceptable risk in dollars, which is **1% of the current account balance**. (e.g., `$10` on a `$1000` account).
    3.  Based on the proposed Stop Loss distance, it calculates the **lot size** that corresponds to this dollar risk.
        *   `Lot Size = (Account Balance × 1%) / (SL distance in price × Tick Value)`
    4.  The calculated lot size is normalized to meet the broker's volume step requirements (e.g., rounded down to the nearest 0.01).
    5.  The trade is executed with this newly calculated lot size and the original Stop Loss.
*   **Log Message:** `RISK LOG: Rule '1% dynamic risk' applied. Account Balance: $X, Risk Target: $Y. Calculated Lot: Z, ...`

---

## 3. Stop Loss Normalization

To prevent trade execution errors, all Stop Loss values are automatically normalized before being used. This involves two checks:
1.  **Tick Size Alignment:** The SL price is rounded to the nearest valid price tick.
2.  **Minimum Distance:** The system ensures the SL is at least the minimum required distance (`Stops Level`) away from the entry price, as defined by the broker.

---

## 4. Example Scenarios

### Scenario 1: Small Account, 0.01 Lot Trade
*   **Account Balance:** $100
*   **EA wants to open:** 0.01 lot BUY with a 2000-point SL.
*   **Risk Calculation:** The 2000-point SL would risk $20. This is > $10.
*   **Action:** The risk engine reduces the SL to 1000 points (to cap risk at $10).
*   **Result:** Trade is opened with **0.01 lots** and a **1000-point SL**.

### Scenario 2: Larger Account, Dynamic Lot
*   **Account Balance:** $5,000
*   **EA wants to open:** 0.10 lot BUY with a 1500-point SL.
*   **Risk Calculation:** The system ignores the 0.10 lot. It calculates the risk target as 1% of $5,000 = **$50**.
*   **Action:** It calculates the lot size needed to risk $50 with a 1500-point SL. `Lot = $50 / (1500 points of risk) = 0.33 lots`.
*   **Result:** Trade is opened with **0.33 lots** and the original **1500-point SL**.
