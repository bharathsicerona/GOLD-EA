# XAUUSD M1 High-Risk Scalper EA

This document provides a complete overview of the XAUUSD M1 High-Risk Scalper, an aggressive Expert Advisor designed for rapid account growth through high-frequency, momentum-based scalping.

---

## 1. Project Overview

This EA is a specialized trading system engineered exclusively for the **M1 timeframe on XAUUSD**. Its core philosophy is to prioritize **profit maximization and fast compounding** over conservative risk management. It is designed for traders who understand and accept the higher drawdown potential inherent in high-risk, high-reward strategies.

*   **Strategy:** EMA-based Trend & RSI Momentum Pullbacks
*   **Timeframe:** M1 Only
*   **Risk Model:** Aggressive, High-Reward
*   **Key Features:** Step-Based Profit Locking, Dynamic TP Extension

---

## 2. System Architecture & Execution Flow

The EA is built on a modular architecture to separate concerns and optimize performance, which is critical for M1 scalping. The execution flow on every tick is lean and efficient.

### Architecture Diagram (Text-Based)

```
[ OnTick Event ]
       |
       v
[ 1. HasOpenPosition? ]--YES-->[ 2. TradeManager.Manage() ]
       |                            |
       |                            +--> ManageTrailingStop()
       |                            +--> UpdateDynamicTP()
       |
       NO
       |
       v
[ 3. IsCooldownActive? ]--YES-->[ END ]
       |
       NO
       |
       v
[ 4. EntryEngine.ValidateEntry() ]--INVALID-->[ END ]
       |
     VALID (BUY or SELL)
       |
       v
[ 5. RiskManager.CalculateLotSize() ]--ZERO_LOT-->[ END ]
       |
       |
       v
[ 6. TradeEngine.ExecuteTrade() ]
```

### Execution Flow Explained

1.  **Position Check:** The `OnTick()` function first checks if a position managed by this EA is already open.
2.  **Trade Management:** If a trade is open, control is handed to the **TradeManager**. It calls `ManageTrailingStop()` to lock in profits and `UpdateDynamicTP()` to extend the target on every tick. No new trades are considered.
3.  **Cooldown:** If no trade is open, the system checks if a cooldown period is active after a recent loss.
4.  **Entry Validation:** If clear to trade, the **EntryEngine** (`ValidateEntry`) rigorously checks for a valid BUY or SELL signal using a series of hard filters. If no valid signal is found, the process ends for that tick.
5.  **Risk Calculation:** If a valid signal is found, the **RiskManager** (`CalculateHighRiskLotSize`) calculates the appropriate lot size based on the defined risk percentage.
6.  **Trade Execution:** Finally, the `ExecuteTrade` function opens the position with the calculated SL, TP, and lot size. It also stores the initial risk value needed for the dynamic TP logic.

---

## 3. M1 Scalper Strategy: A Deep Dive

The strategy is designed to capture short, explosive momentum bursts on the M1 chart. It is not a trend-following system in the traditional sense; rather, it's a **pullback-to-momentum** strategy.

### Core Components

*   **Trend Baseline (`EMA 50`):** The EA uses a 50-period EMA to establish a short-term trend baseline. For a BUY signal, price must be above the EMA 50; for a SELL, it must be below.
*   **Momentum (`EMA 20` vs `EMA 50`):** The relationship between the 20 and 50 EMAs confirms the momentum. A BUY requires the EMA 20 to be above the EMA 50.
*   **The Trigger (Pullback to `EMA 20`):** The actual entry signal is based on the price pulling back towards the `EMA 20`, providing an opportunity to enter the established momentum at a better price.

### The `ValidateEntry` Filter System

To ensure high-quality entries and avoid "instant SL hits," every potential trade must pass a strict sequence of hard filters:

1.  **Session Filter:** The trade must occur during an allowed session (by default, all sessions are enabled in "Aggressive Mode").
2.  **Spread Filter:** The current broker spread must be below the maximum allowed (`InpMaxSpreadPoints`).
3.  **Spike Candle Filter:** The previous candle's range (`High - Low`) cannot be excessively large compared to the current ATR. This avoids entering on volatile, unpredictable exhaustion spikes.
4.  **Candle Confirmation:** The previous candle must have closed in the direction of the trade (e.g., a bullish candle for a BUY signal).
5.  **RSI Momentum Filter:** The RSI value must be **actively increasing** for a BUY and **decreasing** for a SELL. This "RSI Velocity" check ensures you are entering with momentum, not against it.

Only if **all** these conditions are met is a signal considered valid.

---

## 4. The Profit Engine: Trailing SL & Dynamic TP

This is the heart of the EA's high-reward philosophy. It is designed to aggressively lock profits and let winners run as far as possible.

### Step-Based Trailing Stop

The trailing stop is not based on pips or ATR. It is based on **fixed monetary profit targets**.

*   When trade profit reaches **$1.00**, the Stop Loss is immediately moved to lock in **+$0.20**.
*   When trade profit reaches **$2.00**, the SL is moved to lock in **+$1.00**.
*   When trade profit reaches **$3.00**, the SL is moved to lock in **+$2.00**.

This pattern continues indefinitely. **Example:** If the trade profit hits $10.50, the SL will be moved to lock in $9.00 of profit. This mechanism is designed to secure the majority of floating profit with each dollar gained, drastically reducing the risk of a winning trade turning into a loser.

### Dynamic Take Profit

The Take Profit is not static. It expands as the trade proves its strength, allowing the EA to capture massive outlier moves.

*   **Initial TP:** The trade is opened with a standard Take Profit targeting a **3:1 Reward-to-Risk** ratio (3R).
*   **At 1R Profit:** When the floating profit equals the initial risk (1R), the EA extends the Take Profit target to **4R**.
*   **At 2R Profit:** If the trade continues to 2R in profit, the EA extends the TP again to **6R**.

This ensures that a strong, trending move is not cut short by a premature Take Profit.

---

## 5. The High-Risk Philosophy & Risk Engine

This EA is built for aggressive account growth and operates on a high-risk model.

### Risk & Lot Sizing
*   **High Risk Per Trade:** The EA is designed to use a high percentage of equity per trade, controlled by `InpHighRiskPercent` (defaulting to 3%, but intended for values from 3-50%).
*   **Forced Minimum Lot:** Trading with high risk on a low-capital account often results in a calculated lot size that is below the broker's minimum (e.g., 0.01 lots). This EA handles this by **forcing the trade at the minimum lot size** by default. This ensures the EA never misses a valid setup due to capital constraints. This behavior can be configured via the `InpMinLotAction` input.
*   **Margin Check:** Before placing any trade, the EA calculates the required margin and ensures it is well within the account's free margin to prevent margin call errors.

### Drawdown Expectation

A high-risk strategy will inherently have significant drawdowns. Users should be fully aware that a string of losses is possible and that large swings in equity are a normal part of this strategy's performance profile. The goal is for the large, extended wins to mathematically outweigh the frequent small losses.

---

## 6. Installation & Usage

1.  **Copy Files:** Copy the `.mq5` file and all `.mqh` files into your MT5 `MQL5/Experts/` folder. **All files must be in the same folder.**
2.  **Compile:** Open the `XAUUSD_M1_Scalper_EA.mq5` file in MetaEditor and press `F7` to compile it.
3.  **Attach:** Drag the EA onto an **M1 Chart** for `XAUUSD`.
4.  **Settings:** In the `Inputs` tab, review the parameters. Ensure `Allow Algo Trading` is checked in the `Common` tab.
5.  **Run:** Click `OK`. A smiley face on the chart confirms the EA is running.

---

## 7. Backtesting & Optimization Guide

### Backtesting
*   **Model:** Always use `Every tick based on real ticks` for accuracy.
*   **Period:** Test over at least 6-12 months of data.
*   **Focus:** Do not focus on Win Rate. Instead, analyze **Profit Factor** and the **shape of the equity curve**. A jagged curve with large wins is expected.

### Optimization for the M1 Scalper
When optimizing, focus on the parameters that define entries and the initial stop loss. The trailing logic is fixed.

*   **Phase 1 (Structure):** `InpFastEmaPeriod`, `InpSlowEmaPeriod`.
*   **Phase 2 (Confirmation):** `InpRsiBuyMin`, `InpRsiBuyMax`, `InpRsiSellMin`, `InpRsiSellMax`.
*   **Phase 3 (Volatility):** `InpStopAtrMultiplier`, `InpSpikeCandleAtrFactor`.

#### Suggested Starting Parameters for XAUUSD M1
*   `InpHighRiskPercent`: Start at `3.0` and increase as you get comfortable.
*   `InpStopAtrMultiplier`: `2.0` - `3.0` (A larger value gives the trade more room to breathe initially).
*   `InpRewardRiskRatio`: `3.0` (This is the initial target; the dynamic TP will manage it later).
*   `InpSpikeCandleAtrFactor`: `2.5` - `3.5`.
*   `InpMaxSpreadPoints`: `300` - `400` (For XAUUSD, a spread of 30-40 pips).

---

## 8. Limitations

*   **High Drawdown:** This is not a "safe" or "low-risk" system. It is designed to be aggressive and will experience significant drawdowns.
*   **Broker Dependency:** Performance is highly sensitive to broker conditions, especially **spread and execution speed (latency)**. It must be run on a low-spread ECN account.
*   **No News Filter:** The EA does not have a built-in news filter. It will trade during high-impact news, which can lead to extreme volatility and slippage.
