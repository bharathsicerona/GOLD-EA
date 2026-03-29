# M1 Scalper - Adaptive Filter Layer

The M1 Scalper EA includes an Adaptive Filter Layer that runs before any trading strategies are evaluated. Its purpose is to analyze the current market conditions and prevent trades when the environment is unfavorable. This layer significantly improves trade quality, reduces overtrading, and avoids low-probability setups.

## Filters

The Adaptive Filter Layer consists of several dynamic filters:

### 1. ATR Dynamic Filter

-   **Purpose:** To avoid trading in low-volatility environments where scalping is less effective.
-   **Formula:** `current ATR < average ATR over last 20 candles * 0.8`
-   **Scenario:** If the current ATR is 20% below the recent average, it indicates that volatility is contracting, and the market may be entering a consolidation phase. The filter will reject trades with the reason `LOW_ATR_DYNAMIC`.

### 2. Trend Strength Filter

-   **Purpose:** To ensure that there is a clear trend direction before considering a trade.
-   **Formula:** `(absolute difference between fast and slow EMAs) / current ATR < 0.1`
-   **Scenario:** If the gap between the EMAs is very small relative to the current ATR, it suggests that the trend is weak or non-existent. The filter will reject trades with the reason `WEAK_TREND`.

### 3. Chop Detection Filter

-   **Purpose:** To identify and avoid choppy, range-bound markets where scalping strategies tend to perform poorly.
-   **Formula:** `(highest high of last 5 candles - lowest low of last 5 candles) < current ATR * 1.2`
-   **Scenario:** If the range of the last 5 candles is smaller than 1.2 times the current ATR, it indicates that the market is consolidating in a tight range. The filter will reject trades with the reason `CHOP_MARKET_DYNAMIC`.

### 4. Candle Quality Filter

-   **Purpose:** To ensure that the current candle shows sufficient momentum.
-   **Formula:** `candle body < current ATR * 0.3`
-   **Scenario:** If the body of the current candle is very small relative to the ATR, it indicates a lack of conviction from either buyers or sellers. The filter will reject trades with the reason `WEAK_CANDLE_DYNAMIC`.

### 5. Breakout Quality Filter

-   **Purpose:** To filter out weak breakouts that are likely to fail.
-   **Formula:** `breakout candle body < current ATR * 0.5`
-   **Scenario:** This filter is applied specifically to breakout signals. If the body of the breakout candle is not strong enough, the breakout is considered weak and is rejected with the reason `WEAK_BREAKOUT_DYNAMIC`.

### 6. Session Adaptive Filter

-   **Purpose:** To apply stricter conditions during the New York session, which can have different volatility characteristics.
-   **Formula:** `current ATR < average ATR over last 20 candles`
-   **Scenario:** During the New York session, if the current ATR is below the recent average, it indicates that the session is unusually quiet. The filter will reject trades with the reason `NY_WEAK_CONDITION`.

## Impact on Trading

The Adaptive Filter Layer acts as a gatekeeper, ensuring that the trading strategies are only executed when the market conditions are optimal for scalping. This results in:

-   **Reduced Overtrading:** By filtering out low-probability setups, the EA takes fewer trades, which reduces commission costs and avoids unnecessary risk.
-   **Improved Win Rate:** By focusing on high-quality setups in favorable market conditions, the win rate of the EA is expected to improve.
-   **Enhanced Risk Management:** By avoiding choppy and low-volatility markets, the EA is better able to manage risk and protect capital.
