# PROJECT_INDEX.md

## 1) Project Snapshot

- Project type: MetaTrader 5 multi-EA trading system for `XAUUSDm`
- Main EAs:
- `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` (M1 aggressive scalper)
- `EAs/Adaptive/XAUUSD_Adaptive_MultiFactor_EA.mq5` (M5 capital stabilizer)
- `EAs/Beginner/XAUUSD_Beginner_Trend_Pullback_EA.mq5` (M5 simplified learning EA)
- Shared libraries:
- `EAs/Include/GoldEA_Common_Core.mqh`
- `EAs/Include/GoldEA_Unified_Risk.mqh`
- Log analysis:
- `scripts/analyze_ea_logs.py`
- Generated analysis artifacts:
- `log_analysis_output/events.csv`
- `log_analysis_output/summary.csv`
- `log_analysis_output/data.json`
- Raw backtest log present in workspace:
- `logs/M1 Scalper logs.log`

---

## 2) Full File Inventory (Workspace Files)

The following list includes all files currently present in the project workspace.

| Component | File | Purpose | Used By |
| --- | --- | --- | --- |
| Root config | `.gitignore` | Ignore MT5 binaries/logs, IDE files, generated outputs | Git / repo hygiene |
| Root docs | `README.md` | Main project overview, structure, setup, script usage | All developers |
| Root index | `PROJECT_INDEX.md` | Central code/system map (this file) | Future development/debugging |
| Docs | `doc/CHANGELOG.md` | Historical strategy/refactor notes | Developers |
| Docs | `doc/OPTIMIZATION_CHECKLIST.md` | Backtest/optimization checklist | Strategy tuning |
| Docs | `doc/RISK_MANAGEMENT.md` | Unified risk model explanation | Risk/QA |
| Adaptive docs | `EAs/Adaptive/README.md` | M5 adaptive EA notes (R-multiple trailing emphasis) | M5 EA users |
| Adaptive main | `EAs/Adaptive/XAUUSD_Adaptive_MultiFactor_EA.mq5` | M5 EA bootstrap (`OnInit`, `OnTick`, includes modules) | MT5 runtime |
| Adaptive inputs | `EAs/Adaptive/XAUUSD_Adaptive_Inputs.mqh` | Inputs, enums, scoring/risk/session params | Adaptive main/modules |
| Adaptive indicators | `EAs/Adaptive/XAUUSD_Adaptive_Indicators.mqh` | Indicator handles, Asian range, snapshot calculation | Adaptive entry/management |
| Adaptive entry | `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh` | Trend-pullback decision engine (capital stabilizer mode) | Adaptive management |
| Adaptive risk | `EAs/Adaptive/XAUUSD_Adaptive_Risk.mqh` | Lot sizing from stop distance and risk% | Adaptive execution |
| Adaptive logging | `EAs/Adaptive/XAUUSD_Adaptive_Logging.mqh` | CSV logging, dashboard rendering, arrows | Adaptive main/management |
| Adaptive management | `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh` | Execute, manage open trades, entry evaluation, transaction result logs | Adaptive main |
| Beginner docs | `EAs/Beginner/README.md` | Beginner EA high-level guide | Beginner users |
| Beginner main | `EAs/Beginner/XAUUSD_Beginner_Trend_Pullback_EA.mq5` | Self-contained simple M5 EA | MT5 runtime |
| Shared include | `EAs/Include/GoldEA_Common_Core.mqh` | Common helpers (debug, keys, volume, indicator read, dashboard line) | M1 + M5 modules |
| Shared include | `EAs/Include/GoldEA_Unified_Risk.mqh` | Shared fixed monetary SL engine (`$3/$6/1%`) + stop normalization helpers | M1 + M5 execution |
| M1 docs | `EAs/M1_Scalper/README.md` | Pointer to consolidated docs | M1 users |
| M1 main | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` | M1 EA bootstrap + execution orchestration | MT5 runtime |
| M1 inputs | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Inputs.mqh` | High-risk mode, session mode, filters, visualization params | M1 main/modules |
| M1 indicators | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Indicators.mqh` | Placeholder/empty module | M1 include chain (legacy) |
| M1 entry | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | Scoring-based EMA/ATR entry validator (`ValidateEntry`) | M1 main |
| M1 high-risk mgmt | `EAs/M1_Scalper/XAUUSD_M1_Scalper_HighRisk_Management.mqh` | Profit-lock trailing and dynamic TP extension helpers | M1 main |
| M1 logging | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Logging.mqh` | M1 CSV logging + dashboard | M1 main |
| M1 management | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Management.mqh` | Alternate/legacy management + `TRADE_RESULT` print style | Not included by current M1 main |
| M1 risk | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Risk.mqh` | Alternate/legacy lot sizing and cooldown checks | Not included by current M1 main |
| Preset | `presets/XAUUSD_Exness_Starter_Preset.txt` | Starter config values for M5 adaptive EA | Manual setup |
| Python script | `scripts/analyze_ea_logs.py` | Parse EA logs, split by EA type, summarize, compare, export data | Quant analysis |
| Raw logs | `logs/M1 Scalper logs.log` | MT5 tester output sample (mixed infra + EA lines) | Script input |
| Output data | `log_analysis_output/events.csv` | Parsed event-level dataset | Script output |
| Output summary | `log_analysis_output/summary.csv` | Summary metrics per EA | Script output |
| Output JSON | `log_analysis_output/data.json` | Full structured output (events + summaries) | Script output |

---

## 3) Strategy Mapping by EA

### M1 Scalper EA (`EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`)

- Timeframe: `PERIOD_M1`
- Strategy type: Capital Booster (high-frequency scalping)
- Entry logic source: `ValidateEntry()` in `XAUUSD_M1_Scalper_Entry.mqh`
- Indicators used:
- EMA20 / EMA50
- ATR
- Entry conditions:
- Session restricted to London + New York (Asian disabled)
- Spread within dynamic/floor threshold
- Pullback continuation multi-strategy model:
- Entry Triggers (All evaluated, then processed by signal engine):
  - **M1_EMA_PULLBACK**: (Bar-close) `EMA20 > EMA50` and `mid` pulls back to touch `EMA20` + direction check.
  - **M1_BREAKOUT**: (Tick-level) `mid` exceeds highest high (or lowest low) of the last X periods + ATR expansion guard.
  - **M1_REVERSAL**: (Bar-close) RSI extreme (`<30` or `>70`) + matching strict engulfing candle formulation.
  - **M1_LIQUIDITY_SWEEP**: (Bar-close) Price takes a previous high/low and then reverses with a strong wick.
- Entry decision:
  - `ValidateEntry` returns an array of signals.
  - `ProcessStrategySignals` processes the signals, applies rules (e.g. liquidity sweep override, conflict avoidance), and determines the final trade.
- In-trade management:
  - `StrategyFeedbackManager` reacts to new signals while a trade is open to manage it dynamically.
- Runtime safety kept:
- spread filter
- cooldown controls (5-candle entry cooldown)
- loss-cluster guard: after 2 consecutive losses, skip next 2 signal evaluations
- Signal evaluation frequency: new M1 candle only
- Exit / management:
- M1 scalp exit targets:
- Entry SL/TP from ATR:
  - `slDistance = clamp(ATR*0.8, 2.0, 5.0)`
  - `tpDistance = slDistance * 1.5`
- Runner management (R-based):
  - `>1R`: move SL to breakeven
  - `>1.5R`: lock `+0.5R`
  - `>2R`: trail by `1R`
- Risk model:
- Uses `GoldEA_Unified_Risk.mqh` via `CalculateTradeRisk()`
- Rule A: `0.01 lot -> $3`
- Rule B: `0.02 lot -> $6`
- Rule C: `>=0.03 lot -> 1% of balance`
- Known issues (inferred):
- `XAUUSD_M1_Scalper_Indicators.mqh` is empty (legacy shell)
- M1 now uses structured `CHECK/EXECUTION/REJECTION/RESULT/STATS` logs with parser-friendly `BUY|SELL check:` lines

### M5 Adaptive Multi-Factor EA (`EAs/Adaptive/XAUUSD_Adaptive_MultiFactor_EA.mq5`)

- Timeframe: `PERIOD_M5`
- Strategy type: Capital Stabilizer (session-based)
- Entry logic source: `SelectAndRunStrategy()` in `XAUUSD_Adaptive_Entry.mqh`
- Indicators used:
- EMA fast/slow
- RSI
- ATR
- Bollinger Bands
- ADX
- Market structure: Asian session high/low range
- Active strategy logic (ANY valid triggers entry, no score constraint):
- **Range (M5_RANGE):** Asian session ONLY. Buys on RSI < 35 with bullish candle, sells on RSI > 65 with bearish candle.
- **Breakout (M5_BREAKOUT):** London session ONLY. Places pending Buy Stop at `g_asianHigh` or Sell Stop at `g_asianLow` (if no pending order exists) to capture intra-candle breakout movement without slippage.
- **Trend Pullback (M5_TREND_PULLBACK):** `EMA20 > EMA50` + pullback condition + bullish candle (reverse for sell).
- **ATR Breakout (M5_ATR_BREAKOUT):** London/NY session ONLY. ADX > 28, ATR expands > 30% vs 20-period average, price breaks fast EMA.
- Filters:
- Minimum score requirement removed entirely in favor of strict multi-factor triggers.
- Counter-trend gate disabled by strategy design (trend alignment required)
- Exit / management:
- Execution with structured M5 SL/TP: for `0.01 lot`, SL is `$10` and TP is `3R` by default
- Trade management includes:
- R-multiple tracking state (`M5TrailLevel` global state)
- Partial close at `1.5R`
- Active R-based trailing locks:
- `1R -> +0.1R`
- `1.5R -> +0.5R`
- `2R -> +1R`
- `2.5R -> +1.5R`
- Risk model:
- `CalculateLotSize()` in `XAUUSD_Adaptive_Risk.mqh` remains for lot selection
- `CalculateFixedSLDistance()` in `GoldEA_Unified_Risk.mqh` defines final SL distance
- Known issues (inferred):
- Risk logic partly duplicated (lot calc in `..._Risk.mqh` + hard absolute cap in management)
- Mixed “score + penalty + overrides” makes behavior complex; tuning can be non-linear

### Beginner Trend Pullback EA (`EAs/Beginner/XAUUSD_Beginner_Trend_Pullback_EA.mq5`)

- Timeframe: `PERIOD_M5`
- Strategy type: Simple trend pullback
- Indicators used:
- EMA20 / EMA100
- RSI
- ATR
- Entry conditions:
- Buy: trend up + RSI buy band + pullback near fast EMA + bullish candle + min ATR
- Sell: trend down + RSI sell band + pullback near fast EMA + bearish candle + min ATR
- Filters:
- Session (London/NY windows)
- Spread max
- One position per side and duplicate-bar prevention
- Exit:
- SL = ATR * stop multiplier
- TP = SL * TP multiplier
- Risk:
- Simple balance% based lot sizing in-file

---

## 4) Key Functions and Logic Blocks

### Adaptive EA (M5)

- `IsNewBar()` -> `XAUUSD_Adaptive_MultiFactor_EA.mq5`
- `CalculateIndicators()` -> `XAUUSD_Adaptive_Indicators.mqh`
- `RunNewYorkTrendPullbackStrategy()` -> `XAUUSD_Adaptive_Entry.mqh`
- `RunAsianRangeStrategy()` -> `XAUUSD_Adaptive_Entry.mqh`
- `RunLondonBreakoutStrategy()` -> `XAUUSD_Adaptive_Entry.mqh`
- `SelectAndRunStrategy()` + `PickBestDecision()` -> session-based strategy selection
- `ExecuteTrade()` -> order send + state globals + CSV logging
- `ManageTrade()` -> open-position management stack
- `EvaluateEntries()` -> bar-close trading logic
- `EvaluateTickAndDashboard()` -> live preview and optional tick logging
- `OnTradeTransaction()` -> prints stop/take/breakeven outcomes

### M1 Scalper EA

- `AdaptiveFilterCheck()` -> `XAUUSD_M1_Scalper_Entry.mqh`
- `ValidateEntry()` -> scoring-based EMA/ATR validator with directional score comparison (`XAUUSD_M1_Scalper_Entry.mqh`)
- `ExecuteHighRiskTrade()` -> unified fixed-SL risk engine call, position open
- `ManageTrailingStop()` / `UpdateDynamicTP()` / `ExtendTakeProfit()` -> aggressive management
- `OnTick()` -> Adaptive Filter Layer -> position management + cooldown + frequency cap + buy/sell validation
- `OnTradeTransaction()` (main) -> remove risk-map state, cooldown timing

### Shared Includes

- `GoldEA_Common_Core.mqh`:
- `DebugPrint`, `CurrentTimeText`
- key builders: `BuildGlobalKey`, `BuildStateKey`
- `NextTradeId`, `NormalizeVolume`, `GetIndicatorValue`
- dashboard helper + log cleanup helper (cleanup currently commented out)
- `GoldEA_Unified_Risk.mqh`:
- `NormalizeLot`, `AdjustLotForM1`, `NormalizeStop`, `CalculateFixedSLDistance`, `CalculateTradeRisk` (shared fixed-SL risk engine)

---

## 5) Risk Management Rules

### M1 Current Effective Risk Path

- Main file includes `GoldEA_Unified_Risk.mqh`, not `XAUUSD_M1_Scalper_Risk.mqh`
- Trade flow:
- Build raw lot/SL candidate
- Apply `AdjustLotForM1(lot, balance)` before risk/margin/order flow
- For balances `<= $200`, lot is forced to `0.01` (margin-safe mode)
- Call `CalculateTradeRisk(...)` to derive fixed monetary SL from lot size
- Check free margin (`HasSufficientMargin`)
- Open order with adjusted parameters

### M5 Current Effective Risk Path

- Lot sizing from `CalculateLotSize(stopDistance, riskPercent)`
- Minimum lot enforcement in `CalculateLotSize(...)`: `lot >= 0.01`
- SL distance from `CalculateFixedSLDistance(lot, balance)` in shared risk module, with M5 override:
- `0.01 lot` uses `$10` stop risk
- Place order and track per-position state via Global Variables
- TP defaults to `3R`
- Trailing in `ManageTrade()` is active with level-based R locks (`1R/1.5R/2R/2.5R`)

### Beginner EA

- Lot = balance% risk / loss-per-lot
- SL/TP ATR-based
- No advanced adaptive risk layers

---

## 6) Log Structure and Trade Lifecycle Mapping

### Primary Console Prefixes

- M5: `[M5][GoldEA] ...`
- M1: `[M1_SCALPER][GoldEA] ...`

### Standardized Log Types

- `CHECK`: signal evaluation lines (`BUY|SELL check: ...`)
- `EXECUTION`: order placement lines (`BUY|SELL executed: ...`)
- `REJECTION`: explicit skipped/blocked reasons (`reason=...`)
- `RESULT`: lifecycle outcomes (`STOP LOSS HIT`, `TAKE PROFIT HIT`, `BREAKEVEN`)
- `STATS`: periodic counters (signals/trades/skips/win/loss + reject buckets)

### M1 Structured Log Contract (Analyzer-Critical)

- CHECK:
- `[M1_SCALPER][GoldEA][CHECK] [M1_BREAKOUT] BUY|SELL check: rsi=... ema20=... ema50=... score=... buyScore=... sellScore=... atr=... spread=... momentum=... breakoutBuy=... breakoutSell=... slDistance=... tpDistance=... decision=... reason=...`
- EXECUTION:
- `[M1_SCALPER][GoldEA][EXECUTION] BUY|SELL executed: tradeId=... lot=... entry=... sl=... tp=... score=...`
- RESULT:
- `[M1_SCALPER][GoldEA][RESULT] STOP_LOSS_HIT tradeId=... profit=...`
- `[M1_SCALPER][GoldEA][RESULT] TAKE_PROFIT_HIT tradeId=... profit=...`
- Active normalized rejection reasons:
- `LOW_ATR_DYNAMIC`, `WEAK_TREND`, `CHOP_MARKET_DYNAMIC`, `WEAK_CANDLE_DYNAMIC`, `WEAK_BREAKOUT_DYNAMIC`, `NY_WEAK_CONDITION`, `WEAK_BREAKOUT_REJECTED`, `CORE_CONDITION_FAIL`, `TREND_WEAK`, `MOMENTUM_WEAK`, `SCORE_TOO_LOW`, `DIRECTION_CONFLICT`, `EARLY_NOISE`, `M5_TREND_BLOCK`, `SELL_DISABLED_DEBUG`, `LOW_ATR`, `LOSS_CLUSTER_COOLDOWN`, `EMA_FLAT`, `HIGH_SPREAD`, `COOLDOWN_ACTIVE`, `COOLDOWN_5CANDLE`, `MAX_TRADES_REACHED`, `INSUFFICIENT_MARGIN`, `ORDER_FAILED`, `RISK_ENGINE_BLOCK`, `INVALID_TICKVALUE`

### Typical Lifecycle (M5)

1. Signal/decision checks
- `[...] [TRADE][MGMT] ...` / strategy checks
2. Execution
- `SELL executed: tradeId=... lot=... entry=... sl=... tp=...`
3. Management updates
- R-trailing / lock logs
4. Exit result
- `STOP LOSS HIT ticket=... profit=...`
- `TAKE PROFIT HIT ticket=... profit=...`
- `BREAKEVEN ticket=... profit=...`

### CSV Logs from EAs

- M5 file pattern: `GoldEA_Log_YYYYMMDD.csv`
- M1 file pattern: `GoldEA_M1_Log_YYYYMMDD.csv`
- Common columns:
- Time, Symbol, Action, Session, Strategy, Price, RSI, EMA fields, ATR, Spread, Score, Decision, Reason

### Parser Mapping (`scripts/analyze_ea_logs.py`)

- Parses lines matching `EA_PREFIX_RE`: `[M1][GoldEA]`, `[M1_SCALPER][GoldEA]`, or `[M5][GoldEA]`
- Event types:
- Signal checks (`CHECK_RE`)
- Trade executed (`EXEC_RE`)
- Result states (`RESULT_RE`)
- Reconstructs/links:
- Attempts metadata link from last signal by side -> execution
- Links exits to execution by `trade_id` / ticket
- Derives risk and inferred R-multiple where possible
- Builds lifecycle records per trade (`entry -> exit`) and counts resolved trades only when exit is linked.
- Applies trailing-SL win/loss correction: `STOP_LOSS_HIT` with `profit > 0` => `WIN`.

### Python Analyzer Compatibility Notes

- Prefixes now align with parser expectations: `M1_SCALPER` and `M5`.
- Structured fields are emitted consistently in CHECK/EXECUTION/RESULT lines:
- `score=...`, `atr=...`, `spread=...`, `reason=...`, `tradeId=...`
- M1 and M5 both emit parser-friendly:
- `[...][CHECK] [STRATEGY_NAME] BUY|SELL check: ...`
- `[...][EXECUTION] BUY|SELL executed: ...`
- Rejection normalization now avoids generic `OTHER`; unknown labels map to `UNCLASSIFIED_REJECTION`.

---

## 7) Python Log Analyzer: Assumptions and Limitations

---

## 🚀 ENTRY POINT MAP (FOR CODEX)

### M1 Scalper (`EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`)

- `OnTick()` drives runtime loop: dashboard update, open-position management, cooldown/frequency gates, then entry checks.
- Entry validation path: `AdaptiveFilterCheck()` -> `ValidateEntry(POSITION_TYPE_BUY/SELL)` in `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh`.
- Trade execution path: `ExecuteHighRiskTrade()` in `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` (calls `CalculateTradeRisk()` from `EAs/Include/GoldEA_Unified_Risk.mqh`).
- Trade management path: `ManageTrailingStop()`, `UpdateDynamicTP()`, `ExtendTakeProfit()` in `EAs/M1_Scalper/XAUUSD_M1_Scalper_HighRisk_Management.mqh` and EA main.
- Trade lifecycle callback: `OnTradeTransaction()` in EA main updates cooldown state and risk-map cleanup.

### M5 Adaptive (`EAs/Adaptive/XAUUSD_Adaptive_MultiFactor_EA.mq5`)

- `OnTick()` drives loop: `EvaluateTickAndDashboard()`, `IsNewBar()`, `ManageOpenTrades(newBar)`, `EvaluateEntries()`.
- Entry evaluation path: `EvaluateEntries()` in `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`.
- Strategy selection path: `SelectAndRunStrategy()` in `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh` (session-based strategy selection).
- Trade execution path: `ExecuteTrade(const DecisionContext&)` in `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`.
- Trade management path: `ManageTrade(ticket, isNewBar)` in `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`.
- Trade lifecycle callback: `OnTradeTransaction()` in `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`.

### Python Log Analyzer (`scripts/analyze_ea_logs.py`)

- Main parsing entry: `parse_log_file(path)` reads lines and routes by regex.
- Signal parsing: `parse_check_line(...)` using `CHECK_RE`.
- Execution parsing: `parse_execution_line(...)` using `EXEC_RE`.
- Result parsing: `parse_result_line(...)` using `RESULT_RE`.
- EA split gate accepts `[M1][GoldEA]`, `[M1_SCALPER][GoldEA]`, and `[M5][GoldEA]` (M1 normalized internally).

---

## 🛠️ CHANGE IMPACT MAP

| Change Needed | Primary File | Supporting Files |
| ------------- | ------------ | ---------------- |
| M5 session-based strategy implementation | `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh` | `EAs/Adaptive/XAUUSD_Adaptive_Inputs.mqh`, `EAs/Adaptive/XAUUSD_Adaptive_Indicators.mqh` |
| M1 entry scoring / rejection reasons | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Inputs.mqh`, `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 RSI entry window and extreme RSI rejection logs | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 pullback logic (trend -> pullback -> resumption) | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 price-action pullback confirmation (EMA proximity + candle + wick) | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 momentum removal and candle-led confirmation | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 core+score simplification (reduced hard filtering) | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 delayed structure-break confirmation after pullback | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 pure price-action scalping refactor | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`, `EAs/M1_Scalper/XAUUSD_M1_Scalper_HighRisk_Management.mqh` |
| M1 pullback-reversal entry refinement for trailing-SL alignment | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 ultra-simple EMA-touch entry + profit-lock exit alignment | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`, `EAs/M1_Scalper/XAUUSD_M1_Scalper_HighRisk_Management.mqh` |
| M1 Capital Booster scoring entry (core+booster model) | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 trend-strength + London/NY-only filter tuning | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Inputs.mqh`, `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 5-candle entry cooldown tuning | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Inputs.mqh` |
| M1 momentum + ATR quality filters | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Inputs.mqh` |
| M1 loss-cluster skip logic (2 losses -> skip 2 signals) | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` |
| M1 advanced dynamic trailing (level-based + runner mode) | `EAs/M1_Scalper/XAUUSD_M1_Scalper_HighRisk_Management.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 trade throttling / cooldown / frequency cap | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Inputs.mqh` |
| M1 trailing stop / dynamic TP / runner logic | `EAfs/M1_Scalper/XAUUSD_M1_Scalper_HighRisk_Management.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 lot sizing and risk normalization | `EAs/Include/GoldEA_Unified_Risk.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 lot cap logic (<= $200 -> 0.01 lot) | `EAs/Include/GoldEA_Unified_Risk.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M5 min lot enforcement | `EAs/Adaptive/XAUUSD_Adaptive_Risk.mqh` | `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh` |
| Cross-EA fixed monetary SL model (`$3/$6/1%`) | `EAs/Include/GoldEA_Unified_Risk.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`, `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`, `EAs/Adaptive/XAUUSD_Adaptive_Risk.mqh` |
| M5 Capital Stabilizer trend-pullback logic (EMA20/EMA50 + pullback candle) | `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh` | `EAs/Adaptive/XAUUSD_Adaptive_Indicators.mqh`, `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh` |
| M5 Asian-session-only stabilizer filter + higher score threshold | `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh` | `EAs/Adaptive/XAUUSD_Adaptive_Inputs.mqh` |
| M5 structured risk/TP for 0.01 lot (`$10` SL, `3R` TP) | `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh` | `EAs/Adaptive/XAUUSD_Adaptive_Risk.mqh`, `EAs/Include/GoldEA_Unified_Risk.mqh` |
| M5 R-level trailing locks (`1R/1.5R/2R/2.5R`) | `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh` | `EAs/Adaptive/XAUUSD_Adaptive_Logging.mqh` |
| M5 execution filters / order placement | `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh` | `EAs/Adaptive/XAUUSD_Adaptive_Risk.mqh`, `EAs/Adaptive/XAUUSD_Adaptive_Inputs.mqh` |
| M5 trade management and exit logging | `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh` | `EAs/Adaptive/XAUUSD_Adaptive_Logging.mqh` |
| Shared debug keys / normalization helpers | `EAs/Include/GoldEA_Common_Core.mqh` | M1 + M5 include chains |
| Log parsing and EA split logic | `scripts/analyze_ea_logs.py` | `logs/*.log`, `log_analysis_output/*` |
| CSV/dashboard structure changes | `EAs/Adaptive/XAUUSD_Adaptive_Logging.mqh` or `EAs/M1_Scalper/XAUUSD_M1_Scalper_Logging.mqh` | Corresponding EA main/module files |

---

## ⚠️ KNOWN BREAKPOINTS

- M1 prefix mismatch with parser is resolved (`[M1_SCALPER][GoldEA]` now used).
- What changed: M1 log wrapper standardized to parser-compatible prefix.
- Impact: M1 event ingestion in Python analysis is materially improved.

- M1 strategy name logging mismatch is resolved.
- What changed: M1 `CHECK` logs no longer hardcode `[M1_PA]`; they now dynamically insert the actual strategy name (e.g., `[M1_BREAKOUT]`).
- Impact: The Python analyzer can now correctly attribute M1 signals to their specific strategies, fixing a major analytics blind spot.

- M1 signal formatting mismatch was resolved via structured `CHECK` logs.
- What changed: `BUY|SELL check:` lines now include `score`, `atr`, `spread`, `reason`.
- Impact: improved parser coverage and more reliable rejection analytics.

- `EAs/M1_Scalper/XAUUSD_M1_Scalper_Indicators.mqh` is effectively legacy/empty.
- What breaks: developers may edit this file expecting indicator behavior changes.
- Impact: false fixes, wasted debugging cycles.

- M5 now uses active structured trailing by R-level.
- What changed: `ManageTrade()` applies SL-forward locks at `1R/1.5R/2R/2.5R`.
- Impact: better trend capture with controlled downside after profit develops.

- Margin failures in M1 were reduced by design using forced `0.01` lot for balances `<= $200`.
- What changed: M1 now applies `AdjustLotForM1(...)` before risk/margin checks.
- Impact: significantly fewer low-balance margin rejections in M1.

- Python parser still uses regex-first parsing (`EA_PREFIX_RE`, `CHECK_RE`, `EXEC_RE`, `RESULT_RE`) but now has legacy fallbacks.
- What can still break: severely malformed lines with no side/context metadata.
- Impact: reduced (not eliminated) chance of partial datasets on inconsistent logs.

- MQL5 compile sensitivity for uppercase conversion in helper functions.
- What breaks: using `string u = StringToUpper(rawReason);` causes compile error (`constant variable cannot be passed as reference`).
- Impact: EA build fails before runtime.
- Fix applied in:
- `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`
- `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`
- Correct usage: assign string first, then call `StringToUpper(u);`

- M5 compile scope sensitivity in `ExecuteTrade()`.
- What broke: `balance` was referenced before declaration in `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`.
- Impact: `undeclared identifier 'balance'` build error.
- Fix: moved `double balance = AccountInfoDouble(ACCOUNT_BALANCE);` above first usage.

- M1 entry compile breakpoint in `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` (resolved).
- What broke: misplaced `ctx.emaFast/ctx.emaSlow` assignment was inserted between `if (...)` and `else`.
- Impact: `illegal 'else' without matching 'if'` and trailing `not all control paths return a value`.
- Fix: moved context assignments before branch selection in `ValidateEntry()`.

- `CopyBuffer` start-index logic gap.
- What broke: `CopyBuffer` starting at index 0 fetches the current *unformed* live candle, corrupting moving averages and instantly triggering `LOW_ATR` or falsifying expansion checks.
- Impact: Severe logic desync. Strategies fail to trigger or evaluate incorrectly.
- Fix: Always start array-based MVA queries against fully closed candle arrays (e.g. index 1 or `snapshot.shift`) when doing entry tests.

---

## ⚡ FAST DEBUG NAVIGATION

- If NO TRADES:
- Check M1 `OnTick()` gates in `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` (`HasOpenPosition`, cooldown, same-bar, 5-minute cap).
- Check M1 `ValidateEntry()` in `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` (ATR/spread hard gates + core/score direction checks).
- Check M5 `EvaluateEntries()` and `SelectAndRunStrategy()` in `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh` and `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh` (trend-pullback decisions only).

- If TOO MANY SKIPS:
- Check M1 spread/spike filters and score threshold in `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh`.
- Check M5 Asian-session gate and minimum-score filter in `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh`.
- Check session/spread/ATR inputs in `EAs/M1_Scalper/XAUUSD_M1_Scalper_Inputs.mqh` and `EAs/Adaptive/XAUUSD_Adaptive_Inputs.mqh`.

- If WRONG RESULTS / WIN-LOSS MISMATCH:
- Check trade lifecycle handlers `OnTradeTransaction()` in M1 main and M5 management module.
- Check parser linkage logic in `scripts/analyze_ea_logs.py` (`parse_execution_line`, `parse_result_line`).

- If LOGS NOT PARSED:
- Check log prefixes in EA `Log()` output vs `EA_PREFIX_RE`.
- Check signal/execution/result print formats vs `CHECK_RE`, `EXEC_RE`, `RESULT_RE`.
- Validate by running parser on a small sample log before full backtest batch.

### What It Parses Well

- M5-style execution and result lines with `tradeId`, `profit=...`
- Stop-loss/take-profit result logs
- Prefixed EA-tag lines (`[M5][GoldEA] ...`)

### Key Assumptions

- Timestamp pattern is `YYYY.MM.DD HH:MM:SS`
- Trade identity can be linked by `tradeId` or `ticket`
- R-multiple inference needs execution SL/entry and result profit/TP context

### Current Limitations

- Prefix mismatch handling is fixed in parser:
- Analyzer now accepts `[M1]`, `[M1_SCALPER]`, and `[M5]`, then normalizes M1 -> `M1_SCALPER`
- Signal parsing was extended:
- If strict `CHECK_RE` fails, legacy lines (`VALID BUY SIGNAL`, `BUY REJECTED`, etc.) are parsed with fallback extraction
- Rejection reason structuring is improved:
- Keyword-based normalization maps inconsistent text to stable reasons (`CORE_CONDITION_FAIL`, `HIGH_SPREAD`, `INSUFFICIENT_MARGIN`, `COOLDOWN_ACTIVE`, `COOLDOWN_2CANDLE`, `SESSION_BLOCK`)
- Remaining practical limitation:
- Very noisy logs can still dilute signal quality when non-trade diagnostics dominate

---

## 8) Dependency Graph

### M5 Adaptive Dependency Chain

`XAUUSD_Adaptive_MultiFactor_EA.mq5` ->
- `XAUUSD_Adaptive_Inputs.mqh`
- `../Include/GoldEA_Common_Core.mqh`
- `XAUUSD_Adaptive_Indicators.mqh`
- `XAUUSD_Adaptive_Entry.mqh`
- `XAUUSD_Adaptive_Risk.mqh`
- `XAUUSD_Adaptive_Logging.mqh`
- `XAUUSD_Adaptive_Management.mqh`

### M1 Scalper Dependency Chain

`XAUUSD_M1_Scalper_EA.mq5` ->
- `XAUUSD_M1_Scalper_Inputs.mqh`
- `../Include/GoldEA_Common_Core.mqh`
- `XAUUSD_M1_Scalper_Indicators.mqh` (currently empty)
- `XAUUSD_M1_Scalper_Entry.mqh`
- `../Include/GoldEA_Unified_Risk.mqh`
- `XAUUSD_M1_Scalper_Logging.mqh`
- `XAUUSD_M1_Scalper_HighRisk_Management.mqh`

### Beginner EA

- Standalone (only `<Trade/Trade.mqh>` include)

### Analysis Pipeline

`logs/*.log` -> `scripts/analyze_ea_logs.py` -> `log_analysis_output/events.csv`, `summary.csv`, `data.json`

---

## 9) How to Debug Quickly

## No Trades

- M1:
- Check `ValidateEntry()` rejection reasons in `XAUUSD_M1_Scalper_Entry.mqh`
- Check safe/aggressive session mode in `XAUUSD_M1_Scalper_Inputs.mqh`
- Check cooldown blocks in main `OnTick()`
- M5:
- Check `SelectAndRunStrategy()` trend/pullback/candle gates and `ExecuteTrade()` M5 structured SL/TP + R-trailing mapping
- Check `EvaluateEntries()` blocks: max position, cooldown, continuation, duplicate bar

## Overtrading

- M1:
- Check `OnTick()` frequency limiter (`max 3 closes in 5 min`) and cooldown windows
- M5:
- Check `InpTradeCooldownSeconds`, position caps, and `HasOpenPosition` behavior

## SL/TP or Risk Mismatch

- M1:
- Inspect `CalculateTradeRisk()` in `GoldEA_Unified_Risk.mqh`
- Validate `stopLoss` normalization and min stop levels
- M5:
- Inspect `ExecuteTrade()` absolute-loss clamp section and lot calc function
- Verify `initrisk` global variable writes/reads in `ManageTrade()`

## Signal vs Log Analyzer Mismatch

- Confirm EA prefix matches parser (`M1_SCALPER` or `M5`)
- Confirm signal log format matches `CHECK_RE` expected syntax

---

## 10) Improvement Flags (Inferred)

- M1 parser compatibility gap:
- Analyzer compatibility improved: M1 logger now emits `[M1_SCALPER][GoldEA]`
- Structured CHECK/EXECUTION/RESULT lines now parse more reliably
- Duplicate/legacy module risk:
- M1 has both `HighRisk_Management.mqh` and separate `Management.mqh`
- M1 has both `GoldEA_Unified_Risk.mqh` path and separate `M1_Scalper_Risk.mqh`
- `XAUUSD_M1_Scalper_Indicators.mqh` is empty; indicator lifecycle lives in main EA
- `CleanupLogsByPattern()` body in shared core is currently commented out; retention flags may not physically delete files
- Some docs/history mention older architecture; verify runtime behavior from code first, docs second

---

## 11) Fast Navigation Pointers

- M5 entry logic: `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh`
- M5 execution/management: `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`
- M5 indicators/session/range: `EAs/Adaptive/XAUUSD_Adaptive_Indicators.mqh`
- M1 entry logic: `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh`
- M1 execution loop: `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`
- M1 aggressive management: `EAs/M1_Scalper/XAUUSD_M1_Scalper_HighRisk_Management.mqh`
- Shared helpers: `EAs/Include/GoldEA_Common_Core.mqh`
- Unified risk engine: `EAs/Include/GoldEA_Unified_Risk.mqh`
- Log parser: `scripts/analyze_ea_logs.py`
