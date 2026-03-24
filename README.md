# XAUUSDm MetaTrader 5 Expert Advisors

This project contains three MetaTrader 5 Expert Advisors (EAs) for trading `XAUUSDm` (gold):
1. **M5 Adaptive Multi-Factor EA**: A dynamic session-based swing/trend trading system.
2. **M1 High-Frequency Scalper EA**: An aggressive, strict-RR scalping system for rapid growth.
3. **M5 Beginner Trend Pullback EA**: A simplified learning version with fewer moving parts.

Current version identifiers:
- `XAUUSD_Adaptive_MultiFactor_EA.mq5`: `M5 Version 4`
- `XAUUSD_M1_Scalper_EA.mq5`: `M1 Version 1`
- `XAUUSD_Beginner_Trend_Pullback_EA.mq5`: beginner support EA

## EA 1: M5 Adaptive Multi-Factor EA

Version: `M5 Version 4`

The M5 EA combines:
 - Dynamic EMA trend filters with current defaults of `21 EMA` and `100 EMA`
- Momentum filter with `RSI`
- Volatility filter with `ATR`
- Bollinger Bands for range detection
- Dynamic session detection (Asian, London, New York)
- Adaptive risk management and trade management

Main EA file:

- `XAUUSD_Adaptive_MultiFactor_EA.mq5`

Additional files:

- `XAUUSD_Exness_Starter_Preset.txt`
- `OPTIMIZATION_CHECKLIST.md`

## 1. Strategy Summary

The EA behaves like a structured decision engine, dynamically switching strategies based on the current trading session and market volatility.

It uses three distinct strategies:
- **Range Strategy (Low Volatility / Asian Session):** Trades Bollinger Band reversals when RSI is extreme.
- **Breakout Strategy (London Session):** Trades breakouts of the established Asian session high/low.
- **Trend Strategy (New York Session):** Trades trend-continuation pullbacks using EMA alignment and RSI.
- **Outside Defined Sessions:** The advanced EA blocks new entries instead of forcing a strategy choice.

It checks:

- Current broker server time to determine the session
- Current ATR against a volatility threshold
- Indicator confluence specific to the active strategy

It then applies:

- Fixed percentage risk per trade
- ATR-based stop loss
- Dynamic take profit
- Minimal profit locking
- ATR trailing stop
- Partial profit taking

## 2. Entry Logic

### Range Strategy (Asian Session or Low Volatility)
- **Buy:** Price near lower Bollinger Band AND RSI indicates oversold.
- **Sell:** Price near upper Bollinger Band AND RSI indicates overbought.

### Breakout Strategy (London Session, High Volatility)
- **Buy:** Price breaks above the recorded Asian session high (or a strong EMA trend with `ADX > 25` overrides a weak breakout).
- **Sell:** Price breaks below the recorded Asian session low (or a strong EMA trend with `ADX > 25` overrides a weak breakout).

### Trend Strategy (New York Session, High Volatility)
- **Buy:** Price > slow EMA, fast EMA > slow EMA, RSI is in buy zone, and price pulls back to the fast EMA.
- **Sell:** Price < slow EMA, fast EMA < slow EMA, RSI is in sell zone, and price pulls back to the fast EMA.

## 3. Risk Management

The EA uses adaptive risk management.

- Risk per trade: `1%` of account balance by default
- Absolute risk cap: controlled with `InpMaxAbsoluteRiskPercent`
- Counter-trend setups can be allowed with separate risk and score requirements
- Stop loss: `1.8 x ATR`
- Take profit: `3.0 x ATR` (focused on larger R:R targets)
- Lot size is calculated automatically from stop-loss distance
- Calculated volume is normalized to the broker lot step and clamped to the broker minimum lot when needed

This means the EA adjusts position size depending on current market volatility.

## 4. Trade Management

After a trade is opened, the EA manages it automatically:

- Locks a minimal profit of `0.3 x ATR` when profit reaches `1.2 x ATR`
- Closes `50%` of the position at `1.5R`
- **Account Profit Lock:** Secures target profit % (e.g., 1%) when account profit reaches trigger % (e.g., 5%)
- Delays trailing until profit reaches `2.0 x ATR`
- Uses a `2.5 x ATR` trailing stop distance to let the trend breathe, **updated strictly on new bars**
- Mandates a minimum trailing step of `0.5 x ATR` to filter market noise
- **Profit Lock:** Automatically locks `1.0 x ATR` in secured profit once a trade reaches a `2.5 x ATR` profit margin
- **Trade Cooldown:** Prevents rapid re-entry by requiring a minimum wait time between trades
- Global open positions are limited by `InpMaxOpenPositionsTotal`
- Same-direction stacking is controlled by `InpMaxConcurrentTrades`

## 5. Built-In Filters

To avoid bad trading conditions, the EA includes:

- Spread filter
- Session filter
- Minimum ATR filter
- Duplicate signal protection
- Global position limiting (prevents overtrading when signals repeat)
- Magic number isolation

By default, it only trades during:

- Asian session (Range)
- London session (Breakout)
- New York session (Trend)

Important: these session hours use broker server time, so you may need to adjust them for Exness.

## 6. Optional Scoring System

The EA includes an optional score-based decision system.

Each setup gets a score from `0` to `100` based on weighted factors:

- Trend vs `EMA200`
- `EMA50` vs `EMA200` alignment
- RSI validity
- Pullback quality near `EMA50`
- Range Bollinger Band proximity
- Asian session breakout confirmation
- **Momentum Boost:** `+15` points added during London or NY sessions if `ADX > 25`
- **Breakout Penalty:** `-20` points deducted if trading the Breakout strategy without a valid Asian box break

The EA can be configured to trade only when the score is above a minimum threshold such as `80`.

This helps reduce weaker setups.

## 7. Project Files

- [XAUUSD_Adaptive_MultiFactor_EA.mq5](C:\Users\bhara\OneDrive\Documents\Auto-trading code\XAUUSD_Adaptive_MultiFactor_EA.mq5)
- [XAUUSD_M1_Scalper_EA.mq5](C:\Users\bhara\OneDrive\Documents\Auto-trading code\XAUUSD_M1_Scalper_EA.mq5)
- [XAUUSD_M1_Scalper_README.md](C:\Users\bhara\OneDrive\Documents\Auto-trading code\XAUUSD_M1_Scalper_README.md)
- [XAUUSD_M1_Scalper_Inputs.mqh](C:\Users\bhara\OneDrive\Documents\Auto-trading code\XAUUSD_M1_Scalper_Inputs.mqh)
- [XAUUSD_M1_Scalper_Indicators.mqh](C:\Users\bhara\OneDrive\Documents\Auto-trading code\XAUUSD_M1_Scalper_Indicators.mqh)
- [XAUUSD_M1_Scalper_Risk.mqh](C:\Users\bhara\OneDrive\Documents\Auto-trading code\XAUUSD_M1_Scalper_Risk.mqh)
- [XAUUSD_M1_Scalper_Entry.mqh](C:\Users\bhara\OneDrive\Documents\Auto-trading code\XAUUSD_M1_Scalper_Entry.mqh)
- [XAUUSD_M1_Scalper_Logging.mqh](C:\Users\bhara\OneDrive\Documents\Auto-trading code\XAUUSD_M1_Scalper_Logging.mqh)
- [XAUUSD_M1_Scalper_Management.mqh](C:\Users\bhara\OneDrive\Documents\Auto-trading code\XAUUSD_M1_Scalper_Management.mqh)
- [XAUUSD_Beginner_Trend_Pullback_EA.mq5](C:\Users\bhara\OneDrive\Documents\Auto-trading code\XAUUSD_Beginner_Trend_Pullback_EA.mq5)
- [XAUUSD_Exness_Starter_Preset.txt](C:\Users\bhara\OneDrive\Documents\Auto-trading code\XAUUSD_Exness_Starter_Preset.txt)
- [OPTIMIZATION_CHECKLIST.md](C:\Users\bhara\OneDrive\Documents\Auto-trading code\OPTIMIZATION_CHECKLIST.md)
- [README.md](C:\Users\bhara\OneDrive\Documents\Auto-trading code\README.md)

## 7A. Which File Should You Use

Use the file that matches your stage:

- Use `XAUUSD_Adaptive_MultiFactor_EA.mq5` if you want the full strategy with scoring and advanced trade management
- Use `XAUUSD_M1_Scalper_EA.mq5` if you want the dedicated M1 momentum scalper
- Use `XAUUSD_Beginner_Trend_Pullback_EA.mq5` if you want the simpler M5 learning version
- Use `XAUUSD_Exness_Starter_Preset.txt` as a starting input guide for Exness
- Use `OPTIMIZATION_CHECKLIST.md` when tuning settings in Strategy Tester
- Keep the M1 `.mqh` support files beside `XAUUSD_M1_Scalper_EA.mq5` when compiling the split M1 EA

## 8. How to Install the EA in MT5

Follow these steps carefully.

1. Open MetaTrader 5.
2. Click `File -> Open Data Folder`.
3. Open the folder `MQL5`.
4. Open the folder `Experts`.
5. Copy the EA file you want to use into the `Experts` folder.
6. Recommended choices:

- `XAUUSD_Adaptive_MultiFactor_EA.mq5` for the full M5 multi-factor system
- `XAUUSD_M1_Scalper_EA.mq5` for the dedicated M1 scalper
- `XAUUSD_Beginner_Trend_Pullback_EA.mq5` for the simpler M5 version

7. Open `MetaEditor`.
8. In MetaEditor, find the EA under `Experts`.
9. Open the file and press `Compile`.
10. Go back to MT5.
11. In the `Navigator` panel, refresh `Expert Advisors`.
12. Drag the EA onto an `XAUUSDm` chart.
13. Match the chart timeframe to the EA design:

- `M5` for `XAUUSD_Adaptive_MultiFactor_EA.mq5`
- `M1` for `XAUUSD_M1_Scalper_EA.mq5`
- `M5` for `XAUUSD_Beginner_Trend_Pullback_EA.mq5`

14. Enable `Algo Trading`.

## 9. Important Exness Setup Notes

Before using the EA on Exness, check these items:

1. Confirm the correct symbol name.
Your broker's exact symbol is `XAUUSDm`.

2. If the symbol name is different, change:

```text
InpTradeSymbol = "XAUUSDm"
```

to your broker's exact symbol name.

3. Check the broker server time.
London and New York trading hours inside the EA are based on server time, not your local time.

4. Check gold contract specifications:

- Minimum lot
- Lot step
- Tick size
- Tick value
- Spread behavior during volatile news

5. Start on demo first.
Gold is highly volatile and can move very fast, especially during news events.

## 10. How to Attach the EA to a Chart

1. Open the `XAUUSDm` chart in MT5.
2. Set the timeframe. Recommended starting point:

- `M5` as the main tuned timeframe
- `M15` only if you want a slower, less active variation

3. Drag the EA onto the chart.
4. In the input settings, review the default values.
5. Make sure `Allow Algo Trading` is enabled.
6. Confirm the smiley icon or active EA indicator appears on the chart.

## 11. Main Input Parameters

These are the most important settings you can optimize.

### Core Strategy

- `InpTradeSymbol`: symbol to trade
- `InpTimeframe`: chart timeframe used for signals
- `InpMagicNumber`: unique ID for this EA

### Indicators

- `InpFastEmaPeriod`: short EMA, default `21`
- `InpSlowEmaPeriod`: long EMA, default `100`
- `InpRsiPeriod`: RSI period, default `14`
- `InpAtrPeriod`: ATR period, default `14`
- `InpVolAtrThreshold`: ATR threshold to classify high vs low volatility
- `InpBandsPeriod`: Bollinger Bands period
- `InpBandsDeviation`: Bollinger Bands deviation

### RSI Zones

- `InpRsiBuyMin`
- `InpRsiBuyMax`
- `InpRsiSellMin`
- `InpRsiSellMax`

### Risk Settings

- `InpRiskPercent`
- `InpMaxAbsoluteRiskPercent`
- `InpAllowCounterTrend`
- `InpCounterTrendRisk`
- `InpCounterTrendMinScore`
- `InpMaxOpenPositionsTotal`
- `InpMaxConcurrentTrades`
- `InpTradeCooldownSeconds`
- `InpStopAtrMultiplier`
- `InpTakeProfitMultiplier`
- `InpBreakevenAtrMultiplier`
- `InpMinProfitLockAtr`
- `InpAccountProfitLockTriggerPercent`
- `InpAccountProfitLockTargetPercent`
- `InpTrailActivationAtrMultiplier`
- `InpCounterTrendTpMultiplier`
- `InpTrailStepAtrMultiplier`
- `InpProfitLockActivationAtr`
- `InpProfitLockAtr`
- `InpTrailAtrMultiplier`

### Trade Filters

- `InpMinAtrPoints`
- `InpPullbackAtrFactor`
- `InpMaxSpreadPoints`

### Session Settings

- `InpAsianStartHour`
- `InpAsianEndHour`
- `InpLondonStartHour`
- `InpLondonEndHour`
- `InpNewYorkStartHour`
- `InpNewYorkEndHour`

### Scoring and Logging

- `InpUseScoring`
- `InpMinimumScore`
- `InpWeightTrend`
- `InpWeightEmaAlignment`
- `InpWeightRsi`
- `InpWeightRangeBB`
- `InpWeightBreakout`
- `InpWeightPullback`
- `InpEnableDebugPrints`
- `InpEnableCSVLogging`
- `InpEnableDashboard`
- `InpLogEveryTick`
- `InpLogRetentionDays`
- `InpEnablePushAlerts`
- `InpEnableEmailAlerts`

## 12. Recommended Starting Values for Gold

These are not guaranteed best settings, but they are a sensible starting point for testing:

- Timeframe: `M5`
- Fast EMA: `21`
- Slow EMA: `100`
- Volatility ATR Threshold: `150.0`
- RSI: `14`
- ATR: `14`
- Risk: `1%`
- Stop ATR: `1.8`
- Take Profit Multiplier: `3.0`
- Min Profit Lock ATR: `0.3`
- Trailing ATR: `2.5`
- Min ATR Points: `120`
- Max Spread Points: `500`
- Score Threshold: `80`

If your Exness spread is larger on your account type, raise the spread threshold slightly after testing.

## 12A. M5 Strategy Notes

This version is tuned for `M5` gold trading and actively adapts to the time of day.

- During low volume (Asian session), it trades mean-reversion.
- When volatility expands (London/NY), it trades breakouts and trend-continuation.
- The scoring system weights are tailored to each specific strategy type.

## 13. How to Backtest in MT5 Strategy Tester

Use these steps:

1. Open MT5.
2. Press `Ctrl + R` to open the `Strategy Tester`.
3. Select `XAUUSD_Adaptive_MultiFactor_EA`.
4. Select the symbol `XAUUSDm`.
5. Select timeframe `M5` first.
6. Choose `Every tick based on real ticks` if available.
7. Set a good test period, for example at least `6 to 12 months`.
8. Set initial deposit and leverage close to your real trading conditions.
9. Run the backtest.
10. Review:

- Profit factor
- Drawdown
- Number of trades
- Average trade
- Win rate
- Equity curve smoothness

## 14. How to Optimize the EA

Optimization is important because gold behavior changes over time.

Start by optimizing these parameters for the M5 model:

1. `InpFastEmaPeriod`
2. `InpSlowEmaPeriod`
3. `InpRsiBuyMin`
4. `InpRsiBuyMax`
5. `InpRsiSellMin`
6. `InpRsiSellMax`
7. `InpStopAtrMultiplier`
8. `InpTakeProfitMultiplier`
9. `InpTrailAtrMultiplier`
10. `InpVolAtrThreshold`
11. `InpMinimumScore`
12. Session Hours

Practical optimization approach:

1. Keep risk fixed at `1%` while testing.
2. Optimize on one historical period.
3. Validate on a different historical period.
4. Compare results across calm and volatile months.
5. Avoid choosing settings only because they gave the highest profit.
6. Prefer stable settings with lower drawdown and smoother equity growth.

## 15. Suggested Optimization Ranges for XAUUSDm

You can test ranges like these for `M5`:

- `InpFastEmaPeriod`: `13` to `34`
- `InpSlowEmaPeriod`: `80` to `150`
- `InpRsiBuyMin`: `50` to `58`
- `InpRsiBuyMax`: `64` to `72`
- `InpRsiSellMin`: `28` to `36`
- `InpRsiSellMax`: `42` to `50`
- `InpStopAtrMultiplier`: `1.0` to `1.8`
- `InpTakeProfitMultiplier`: `1.4` to `2.2`
- `InpTrailAtrMultiplier`: `0.6` to `1.2`
- `InpVolAtrThreshold`: `100` to `250`
- `InpMaxSpreadPoints`: depends on your Exness account type
- `InpMinimumScore`: `75` to `90`

## 16. Safety Checklist Before Live Trading

Do not skip this part.

1. Compile without errors in MetaEditor.
2. Confirm the symbol name is correct for Exness.
3. Confirm session hours match broker server time.
4. Test on demo account first.
5. Run at least one backtest and one forward demo test.
6. Check lot sizes are being calculated correctly.
7. Watch how the EA behaves during high-impact news.
8. Make sure VPS or MT5 stays online if you want continuous trading.

## 17. Common Issues and Fixes

### EA Does Not Open Trades

Possible reasons:

- Wrong symbol name
- Spread too high
- ATR below threshold
- Outside session hours
- Score below minimum threshold
- No valid candle confirmation

### Compile Errors in MetaEditor

Possible reasons:

- MT5 installation issue
- Old build of MetaTrader 5
- Manual edits introduced syntax errors

### Lot Size Looks Wrong

Possible reasons:

- Broker contract size differs
- Tick value or tick size from broker is unusual
- Stop loss distance is too small or too large

### Too Many Trades

Possible adjustments:

- Raise `InpMinimumScore`
- Raise `InpMinAtrPoints`
- Adjust Volatility ATR Threshold

### Too Few Trades

Possible adjustments:

- Lower `InpMinimumScore`
- Reduce `InpMinAtrPoints`
- Lower Volatility ATR Threshold

## 18. How the EA Works Internally

The EA is built with modular logic so it is easier to maintain:

- Signal generation
- Lot size calculation
- Trade execution
- Open-trade management
- Session and spread filtering
- Logging
- Cleanup of stale per-trade global state

Logging behavior in the advanced EA:

- Writes structured CSV logs to daily files like `MQL5/Files/GoldEA_Log_YYYYMMDD.csv`
- Logs every tick decision as a live preview, even when no trade is taken
- Logs separate bar-close execution signals before real order placement
- Logs buy and sell executions
- Logs minimal profit locks, partial close, and trailing-stop actions
- Shows a live dashboard directly on the chart using labels
- Clears stale per-trade global variables on new bars after closed positions are gone
- Deletes daily CSV logs older than `InpLogRetentionDays`

CSV logging columns:

- `Time`
- `Symbol`
- `Action`
- `Session`
- `Strategy`
- `Price`
- `RSI`
- `EMA50`
- `EMA200`
- `ATR`
- `Spread`
- `Score`
- `Decision`
- `Reason`

Important logging note:

- `LIVE_TICK_PREVIEW` rows are current-candle previews for monitoring and analysis
- `BAR_CLOSE_SIGNAL` rows represent closed-candle signals used for actual entry decisions
- Executed trade rows such as `BUY_EXECUTED` and `SELL_EXECUTED` come after the bar-close signal stage

How to enable CSV logging:

1. Keep `InpEnableCSVLogging = true`.
2. Run the EA in Strategy Tester or on a chart.
3. Open MT5 `File -> Open Data Folder -> MQL5 -> Files`.
4. Open the current daily log file such as `GoldEA_Log_20260323.csv`.

How to view the dashboard:

1. Keep `InpEnableDashboard = true`.
2. Attach the EA to a chart.
3. The decision line now shows whether the result is `LIVE_PREVIEW` or `BAR_CLOSE_SIGNAL`.

---

## EA 2: M1 High-Frequency Scalper EA

Version: `M1 Version 1`

This is a dedicated high-frequency Expert Advisor engineered strictly for the **M1 timeframe** on XAUUSD. It leverages explosive short-term momentum using high-risk (up to 10%), high-reward (1:3 RR) principles to rapidly scale small account balances.

### Core Mechanics

#### 1. The Strategy (EMA + RSI Momentum Pullbacks)
Unlike the multi-factor EA, this system relies purely on split-second momentum and deep pullbacks:
- **Trend Confirmation:** Price must be on the correct side of the `EMA 50`.
- **Momentum Burst:** `EMA 20` must have crossed the `EMA 50` aggressively.
- **Trend Strength (NEW):** The gap between EMA20 and EMA50 must exceed `InpMinEmaGapPoints` to avoid flat/choppy markets.
- **Volatility Filter (NEW):** The ATR must exceed `150 points` to guarantee the market has enough energy to reach the 1:3 RR target.
- **RSI Velocity:** RSI(14) must reside in a strong but non-exhausted zone (`50-70` for Buys, `30-50` for Sells).
- **Candle Confirmation (NEW):** The signal candle must close in the direction of the trend (Bullish for Buys, Bearish for Sells).
- **The Trigger:** The actual entry is sparked when price sharply pulls back toward the `EMA 20`, entering at a mathematical discount while the trend holds.

#### 2. Risk Engine & SL Shrinking
Trading small accounts ($100) mathematically conflicts with Gold's standard contract limits (`0.01` min lot). This usually results in small accounts assuming 20%+ risk.

To achieve exactly 10% risk without missing setups:
- The EA calculates expected loss at `0.01` lots.
- If the expected loss exceeds your defined 10% cash equivalent, the EA **DOES NOT reject the trade**.
- Instead, it recalculates and **shrinks the physical Stop Loss** closer to the entry price until the maximum loss guarantees exactly 10% risk.

#### 3. The 1:3 RR Mandate
This EA forces a strict `1:3 Reward-to-Risk` target on every trade. 
If the Stop Loss is dynamically shrunk to protect the account, the Take Profit distance is simultaneously derived from the newly shrunk SL size to preserve exactly 1:3 RR.

#### 4. Trade Management
Profits on the M1 timeframe evaporate in seconds. To prevent profitable strikes from reversing:
- **The 5% Account Trigger:** The EA monitors the live monetary profit of the trade.
- **The 1% Lock:** The absolute millisecond profit hits 5% of the total account balance, the SL is dragged deep into profit to permanently secure 1% of the account.
- **ATR Trailing:** Once the 1% buffer is locked, the EA activates a trailing stop using an ATR Multiplier to squeeze every last drop out of runaway momentum spikes.

#### 5. Additional Filters
- **Session Filter:** Only trades during London (08:00–13:00) and New York (13:00–22:00) sessions, avoiding Asian session spread spikes.
- **Dynamic Spread Filter:** Maximum spread is dynamically clamped to `0.5 x ATR` (capped by `InpMaxSpreadPoints`), ensuring trades only execute when the spread is a tiny fraction of the expected movement.

#### Visuals & Logging
- The EA perfectly inherits the **Visual Dashboard** and **CSV Logging Engine** from the M5 Adaptive EA.
- It generates a 0–100 pseudo-score based on its M1 internal conditions (Trend + Momentum + RSI + Pullback + Gap + Candle) for seamless visual parity.
- Uses identical `[GoldEA]` prefix formatting and `DecisionContext` logic so your log files remain consistently readable.
- Uses its own daily CSV file format: `GoldEA_M1_Log_YYYYMMDD.csv`
- The split M1 version depends on the local `.mqh` support modules in this folder

## EA 3: M5 Beginner Trend Pullback EA

This is the simple training-wheel version of the project for traders who want cleaner logic before using the advanced engines.

- Timeframe: `M5`
- Trend filter: fast EMA vs slow EMA
- Momentum filter: RSI zones
- Volatility filter: minimum ATR
- Risk model: fixed percentage risk with ATR stop and ATR-based target
- Session filter: London and New York windows only

Use this file when you want a smaller codebase that is easier to audit and backtest.
