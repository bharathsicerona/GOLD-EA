# XAUUSD Adaptive M5 EA - System Documentation

This document covers the specific features and logic of the M5 Adaptive Multi-Factor trading strategy.

---

## Trade Management System

The M5 strategy employs a sophisticated, multi-stage trade management system designed to protect capital and maximize profit capture during favorable trends.

### 1. R-Multiple Trailing Stop (v1.0)

This is the primary trailing stop mechanism for the M5 strategy. It dynamically adjusts the Stop Loss based on the current profit measured in "R-multiples".

*   **Definition of 'R':** "R" is the initial risk distance of the trade, measured in price. If a trade is entered at 1800.00 with an initial Stop Loss at 1795.00, the `R-value` is 5.00 points.

*   **Take Profit:** The initial Take Profit is automatically set to **3R** (3 times the initial risk distance).

*   **Trailing Logic:** The system monitors the unrealized profit of the trade. As profit crosses specific R-multiple thresholds, the Stop Loss is moved forward to lock in gains. The SL is **only ever moved forward**, never backward.

    *   When profit reaches **≥ 0.5R**, the Stop Loss is moved to **+0.1R** (locking in 10% of the initial risk value).
    *   When profit reaches **≥ 1.0R**, the Stop Loss is moved to **+0.5R**.
    *   When profit reaches **≥ 2.0R**, the Stop Loss is moved to **+1.0R** (locking in the initial risk amount, making the trade "risk-free").
    *   When profit reaches **≥ 2.5R**, the Stop Loss is moved to **+1.5R**.

*   **Logging:** Every Stop Loss modification by this system is logged with the reason, current profit in R, and the new SL level in R.
    *   Example: `M5 TRAIL UPDATE: Profit reached 1.05R. Moving SL to +0.50R (New SL: 1802.50, Level: 2)`

### 2. Account Profit Lock

This is a secondary, account-level protection mechanism. If an open position's profit reaches a user-defined percentage of the total account balance (e.g., 5% of account equity), the Stop Loss is moved to a secure level to protect this significant gain.

### 3. Partial Close

At 1.5R profit, the EA is configured to close 50% of the trade volume. This banks a portion of the profit while leaving the remainder of the position open to capture further trend movement.
