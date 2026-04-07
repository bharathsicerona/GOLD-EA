# Risk Management System Documentation

## 1. Overview

This project currently uses two practical risk paths:

- A shared fixed-monetary stop framework in `EAs/Include/GoldEA_Unified_Risk.mqh`
- EA-specific execution overlays that may pass ATR-derived distance into that shared engine

The important point is that the active codebase does **not** use one single universal behavior for every EA. Documentation and testing should always confirm which execution path is active in the EA being reviewed.

---

## 2. Shared Risk Engine (`GoldEA_Unified_Risk.mqh`)

### Fixed Monetary Model

When the caller uses the fixed monetary path, the shared engine applies:

- `0.01 lot -> $4 risk`
- `0.02 lot -> $8 risk`
- `0.03 lot and above -> 1% of account balance`

The module converts monetary risk into price distance using:

- `SYMBOL_TRADE_TICK_VALUE`
- `SYMBOL_TRADE_TICK_SIZE`
- broker stop-level constraints

### Helper Functions

- `NormalizeLot()` normalizes volume to broker lot steps
- `AdjustLotForM1()` forces `0.01` for small-balance M1 safety mode when used
- `NormalizeStop()` aligns SL to tick size and broker stop distance
- `CalculateFixedSLDistance()` converts dollar risk into price distance
- `CalculateTradeRisk()` is the main integration function used by EA execution modules

---

## 3. M1-Specific Dynamic Overlay

The shared risk module also contains `CalculateM1DynamicRisk()`.

When M1 passes an ATR distance into `CalculateTradeRisk()`:

- ATR distance is first converted into raw dollar risk
- Risk is then clamped into a practical monetary band
- Current implementation uses a base clamp of:
  - roughly `$3-$5` for `0.01`
  - scaled proportionally for larger lots

This means the M1 Scalper can behave differently from the plain fixed-dollar path even though both flows pass through the same shared header.

---

## 4. Current Effective Behavior by EA

### M1 Scalper

- Main execution file: `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`
- Uses `CalculateTradeRisk(...)` with an ATR distance argument
- Effective stop comes from the M1 dynamic overlay inside the shared risk engine
- Lot is currently fixed at `0.01` in the active execution path

### M5 Adaptive

- Main execution file: `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`
- Current active path builds price-distance SL directly from strategy ATR logic
- The shared risk header is included for helpers and compatibility, but M5 execution is primarily strategy-distance driven in the current code

### M1 QuickHands

- Current execution path prepares SL directly from entry-module structure/ATR logic
- It does not actively call `CalculateTradeRisk()` in the current version

---

## 5. Safety Controls

Across the project, the active safeguards include:

- stop normalization to broker tick grid
- broker minimum stop distance enforcement
- free-margin validation before order placement
- spread filters in entry logic
- cooldown controls to reduce clustering

---

## 6. Review Notes

When auditing future changes, verify all three layers:

- shared monetary helpers in `GoldEA_Unified_Risk.mqh`
- EA execution module that calls or bypasses the shared engine
- documentation in `README.md` and `PROJECT_INDEX.md`

This is important because historical versions of the project used older `$3/$6`, `$10`, and strategy-specific risk models that may still appear in legacy notes or older backtest logs.
