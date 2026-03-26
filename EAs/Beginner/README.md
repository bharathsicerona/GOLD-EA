# Beginner Trend Pullback EA

This Expert Advisor is a simple, easy-to-understand trend-following strategy for XAUUSD on the M5 timeframe. It is designed for educational purposes to demonstrate the core principles of an automated trading system.

## Strategy

-   **Trend Filter:** The EA uses a slow EMA (100-period) to determine the overall trend direction.
-   **Entry Signal:** It enters on a pullback to a fast EMA (20-period) in the direction of the main trend.
-   **Confirmation:** An RSI filter is used to ensure the market is not overbought or oversold at the time of entry.

## Risk Management

-   **Lot Sizing:** Calculates lot size based on a fixed percentage of the account balance (`InpRiskPercent`).
-   **Stop Loss:** Sets the initial Stop Loss based on a multiple of the Average True Range (ATR).
-   **Take Profit:** Sets a Take Profit based on a fixed multiple of the Stop Loss distance.

## How to Use

This EA is self-contained in a single file for simplicity. Follow the main project `README.md` for installation and setup instructions.
