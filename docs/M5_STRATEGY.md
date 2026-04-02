# M5 ADAPTIVE EA — STRATEGY DOCUMENTATION

## 🎯 OBJECTIVE
The M5 Adaptive EA is a **Capital Stabilizer** system designed to take only high-quality setups by first identifying the market environment and then applying the most appropriate trading strategy.

## 🧠 CORE ARCHITECTURE: MARKET MODE ENGINE
Unlike traditional EAs that evaluate all strategies simultaneously, the M5 Adaptive EA uses a **Market Mode Engine** to detect the current regime before considering any trade.

### DetectMarketMode Logic:
1. **MODE_BREAKOUT**: Detected when volatility is high (`ATR > ATR_Avg * 1.3`) and trend strength is significant (`ADX > 28`).
2. **MODE_TREND**: Detected when there is a clear separation between EMA20 and EMA50 (`EMA_Gap > Threshold`) and sufficient trend strength (`ADX > 22`).
3. **MODE_NONE**: Default state when neither condition is met. The EA skips execution.

---

## 🧭 STRATEGIES

### 1. M5_TREND_PULLBACK (Mode: TREND)
*   **Context**: Active during clear trending phases (London/New York).
*   **Logic**: Enters on a pullback to the EMA20 followed by a candle confirming the trend direction.
*   **Risk Model**:
    *   Stop Loss: `0.8 * ATR`
    *   Take Profit: `2.5 * SL` (Reward/Risk: 2.5)
    *   **Management**: Moves SL to BE+0.1R when profit reaches `1.0R`. Moves SL to `1.0R` when profit reaches `2.0R`.

### 2. M5_ATR_BREAKOUT (Mode: BREAKOUT)
*   **Context**: Active during high-volatility breakout events.
*   **Logic**: Enters when a candle closes in the trend direction during a volatility spike.
*   **Risk Model**:
    *   Stop Loss: `1.2 * ATR`
    *   Take Profit: `4.0 * SL` (Reward/Risk: 4.0)
    *   **Management**: Moves SL to `0.5R` when profit reaches `1.5R`. Moves SL to `2.0R` when profit reaches `3.0R`.

---

## 🚫 HARD PRE-FILTERS
To eliminate noise, the following filters are applied **before** any strategy is evaluated:
*   **WEAK_TREND**: Rejected if `ADX < 20`.
*   **LOW_VOLATILITY**: Rejected if `ATR < ATR_Avg * 0.8`.
*   **LOW_ATR**: Rejected if `ATR < Min_Points`.

---

## ⏱️ TRADE FREQUENCY CONTROL
Strict per-session limits are enforced to prevent overtrading:
*   **Trend Pullback**: Max 2 trades per session.
*   **ATR Breakout**: Max 1 trade per session.

---

## 📊 LOGGING & ANALYTICS
The EA follows a strict logging contract for compatibility with the Python Analyzer.

### Example Logs:
```
[M5][GoldEA][CHECK] [M5_TREND_PULLBACK] BUY check: atr=1.25000 spread=12 reason=VALID strategy=M5_TREND_PULLBACK
[M5][GoldEA][EXECUTION] BUY executed: tradeId=12345 lot=0.01 entry=1950.50 sl=1948.50 tp=1955.50 strategy=M5_TREND_PULLBACK
[M5][GoldEA][REJECTION] BUY rejected: reason=NO_MARKET_MODE lot=0.00 balance=10000.00
[M5][GoldEA][RESULT] TAKE_PROFIT_HIT tradeId=12345 profit=50.00
```

### Rejection Reason Table:
| ReasonCode | Description |
| :--- | :--- |
| **NO_MARKET_MODE** | Market is neither trending nor breaking out. |
| **WEAK_TREND** | ADX is below the minimum threshold (20). |
| **LOW_VOLATILITY** | Current ATR is lower than the recent average. |
| **HIGH_SPREAD** | Broker spread exceeds the maximum allowed points. |
| **SESSION_BLOCK** | Trading is disabled for the current hour. |
| **MAX_TRADES_REACHED**| Per-session or global trade limit hit. |
| **COOLDOWN_ACTIVE** | Minimum time between trades has not elapsed. |
