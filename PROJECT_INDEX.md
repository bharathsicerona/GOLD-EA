# PROJECT_INDEX.md

## 1) Project Snapshot

- Project type: MetaTrader 5 multi-EA trading system for `XAUUSDm`
- Main EAs:
- `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` (M1 aggressive scalper)
- `EAs/Adaptive/XAUUSD_Adaptive_MultiFactor_EA.mq5` (M5 adaptive multi-strategy)
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
| Adaptive entry | `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh` | Range/Breakout/Trend decision engine, scoring and penalties | Adaptive management |
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
| M1 entry | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | Weighted scoring entry validator (`ValidateEntry`) | M1 main |
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
- Strategy type: High-frequency, high-risk scalping
- Entry logic source: `ValidateEntry()` in `XAUUSD_M1_Scalper_Entry.mqh`
- Indicators used:
- EMA20 / EMA50
- RSI
- ATR
- Entry conditions (scored, not strict all-or-nothing):
- Session allowed (or blocked only in safe mode during Asian)
- Spread within dynamic/floor threshold
- No spike candle (ATR-based)
- Pullback continuation entry model:
- Core required conditions:
- BUY: `Price > EMA20` + near `EMA20` pullback
- SELL: `Price < EMA20` + near `EMA20` pullback
- Delayed entry gate:
- Wait at least one closed candle after pullback detection.
- Structure-break confirmation:
- BUY requires break above previous candle high.
- SELL requires break below previous candle low.
- Score boosts (0..4):
- `+1` RSI aligned
- `+1` wick rejection
- `+1` strong candle body (current > previous)
- `+1` strong EMA alignment (`emaFast/emaSlow` gap condition)
- `+1` optional micro-structure quality (higher-low/lower-high)
- Executes if score `>= 2` (after core + structure-break confirmation)
- Hard rejections minimized to:
- spread filter
- RSI extremes (BUY `>80`, SELL `<20`)
- cooldown/trade-frequency controls in EA runtime
- Signal evaluation frequency: new M1 candle only (not every tick)
- Exit / management:
- Initial SL from fixed monetary risk model (`$3/$6/1%` from lot size)
- Initial TP from RR (`InpRewardRiskRatio`)
- `ManageTrailingStop()` in `XAUUSD_M1_Scalper_HighRisk_Management.mqh` is no-op in fixed-SL mode
- `ExtendTakeProfit()` can push TP farther for runners
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
- Strategy type: Multi-strategy adaptive engine (Range / Breakout / Trend)
- Entry logic source: `SelectAndRunStrategy()` in `XAUUSD_Adaptive_Entry.mqh`
- Indicators used:
- EMA fast/slow
- RSI
- ATR
- Bollinger Bands
- ADX
- Market structure: Asian session high/low range
- Strategy routing:
- Asian or low-volatility: Range strategy
- London: Breakout strategy
- New York: Trend strategy
- Core scoring:
- Weighted score components (`InpWeight*`)
- Penalty model for weak structure/adx/gap/persistence
- Context-based score boosts/penalties (e.g., breakout/range adjustments)
- Filters:
- Spread, session, cooldown, max positions, duplicate-bar block, continuation checks
- Counter-trend gate with separate risk and minimum score
- Exit / management:
- Execution with fixed monetary SL (`$3/$6/1%`) and RR-based TP
- Trade management includes:
- R-multiple tracking state (`M5TrailLevel` global state)
- Partial close at `1.5R`
- SL-modification blocks are gated off in fixed-SL mode
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
- `RunRangeStrategy()`, `RunBreakoutStrategy()`, `RunTrendStrategy()` -> `XAUUSD_Adaptive_Entry.mqh`
- `SelectAndRunStrategy()` + `PickBestDecision()` -> strategy arbitration
- `ExecuteTrade()` -> order send + state globals + CSV logging
- `ManageTrade()` -> open-position management stack
- `EvaluateEntries()` -> bar-close trading logic
- `EvaluateTickAndDashboard()` -> live preview and optional tick logging
- `OnTradeTransaction()` -> prints stop/take/breakeven outcomes

### M1 Scalper EA

- `ValidateEntry()` -> weighted scoring and rejection reasons (`XAUUSD_M1_Scalper_Entry.mqh`)
- `ExecuteHighRiskTrade()` -> unified fixed-SL risk engine call, position open
- `ManageTrailingStop()` / `UpdateDynamicTP()` / `ExtendTakeProfit()` -> aggressive management
- `OnTick()` -> position management + cooldown + frequency cap + buy/sell validation
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
- SL distance from `CalculateFixedSLDistance(lot, balance)` in shared risk module
- Place order and track per-position state via Global Variables
- In fixed-SL mode, post-entry SL update blocks are gated off in `ManageTrade()`

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
- `[M1_SCALPER][GoldEA][CHECK] [M1_PA] BUY|SELL check: rsi=... ema20=... ema50=... score=... atr=... spread=... decision=... reason=...`
- EXECUTION:
- `[M1_SCALPER][GoldEA][EXECUTION] BUY|SELL executed: tradeId=... lot=... entry=... sl=... tp=... score=...`
- RESULT:
- `[M1_SCALPER][GoldEA][RESULT] STOP_LOSS_HIT tradeId=... profit=...`
- `[M1_SCALPER][GoldEA][RESULT] TAKE_PROFIT_HIT tradeId=... profit=...`

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

### Python Analyzer Compatibility Notes

- Prefixes now align with parser expectations: `M1_SCALPER` and `M5`.
- Structured fields are emitted consistently in CHECK/EXECUTION/RESULT lines:
- `score=...`, `atr=...`, `spread=...`, `reason=...`, `tradeId=...`
- M1 and M5 both emit parser-friendly:
- `[...][CHECK] [strategy-or-CHECK] BUY|SELL check: ...`
- `[...][EXECUTION] BUY|SELL executed: ...`

---

## 7) Python Log Analyzer: Assumptions and Limitations

---

## 🚀 ENTRY POINT MAP (FOR CODEX)

### M1 Scalper (`EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`)

- `OnTick()` drives runtime loop: dashboard update, open-position management, cooldown/frequency gates, then entry checks.
- Entry validation path: `ValidateEntry(POSITION_TYPE_BUY/SELL)` in `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh`.
- Trade execution path: `ExecuteHighRiskTrade()` in `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` (calls `CalculateTradeRisk()` from `EAs/Include/GoldEA_Unified_Risk.mqh`).
- Trade management path: `ManageTrailingStop()`, `UpdateDynamicTP()`, `ExtendTakeProfit()` in `EAs/M1_Scalper/XAUUSD_M1_Scalper_HighRisk_Management.mqh` and EA main.
- Trade lifecycle callback: `OnTradeTransaction()` in EA main updates cooldown state and risk-map cleanup.

### M5 Adaptive (`EAs/Adaptive/XAUUSD_Adaptive_MultiFactor_EA.mq5`)

- `OnTick()` drives loop: `EvaluateTickAndDashboard()`, `IsNewBar()`, `ManageOpenTrades(newBar)`, `EvaluateEntries()`.
- Entry evaluation path: `EvaluateEntries()` in `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`.
- Strategy selection path: `SelectAndRunStrategy()` in `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh` (routes Range/Breakout/Trend and scores both sides).
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
| M1 entry scoring / rejection reasons | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Inputs.mqh`, `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 RSI entry window and extreme RSI rejection logs | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 pullback logic (trend -> pullback -> resumption) | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 price-action pullback confirmation (EMA proximity + candle + wick) | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 momentum removal and candle-led confirmation | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 core+score simplification (reduced hard filtering) | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 delayed structure-break confirmation after pullback | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 trade throttling / cooldown / frequency cap | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_Inputs.mqh` |
| M1 trailing stop / dynamic TP / runner logic | `EAs/M1_Scalper/XAUUSD_M1_Scalper_HighRisk_Management.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 lot sizing and risk normalization | `EAs/Include/GoldEA_Unified_Risk.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M1 lot cap logic (<= $200 -> 0.01 lot) | `EAs/Include/GoldEA_Unified_Risk.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` |
| M5 min lot enforcement | `EAs/Adaptive/XAUUSD_Adaptive_Risk.mqh` | `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh` |
| Cross-EA fixed monetary SL model (`$3/$6/1%`) | `EAs/Include/GoldEA_Unified_Risk.mqh` | `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5`, `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh`, `EAs/Adaptive/XAUUSD_Adaptive_Risk.mqh` |
| M5 strategy behavior (Range/Breakout/Trend scoring) | `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh` | `EAs/Adaptive/XAUUSD_Adaptive_Indicators.mqh`, `EAs/Adaptive/XAUUSD_Adaptive_Inputs.mqh` |
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

- M1 signal formatting mismatch was resolved via structured `CHECK` logs.
- What changed: `BUY|SELL check:` lines now include `score`, `atr`, `spread`, `reason`.
- Impact: improved parser coverage and more reliable rejection analytics.

- `EAs/M1_Scalper/XAUUSD_M1_Scalper_Indicators.mqh` is effectively legacy/empty.
- What breaks: developers may edit this file expecting indicator behavior changes.
- Impact: false fixes, wasted debugging cycles.

- M5 fixed-SL mode disables SL-updating management blocks by design.
- What breaks: users expecting trailing/breakeven/account-lock SL movement in current mode.
- Impact: SL stays constant after entry; only TP/partial-close lifecycle continues.

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

- M1 entry compile breakpoint in `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` (resolved).
- What broke: misplaced `ctx.emaFast/ctx.emaSlow` assignment was inserted between `if (...)` and `else`.
- Impact: `illegal 'else' without matching 'if'` and trailing `not all control paths return a value`.
- Fix: moved context assignments before branch selection in `ValidateEntry()`.

---

## ⚡ FAST DEBUG NAVIGATION

- If NO TRADES:
- Check M1 `OnTick()` gates in `EAs/M1_Scalper/XAUUSD_M1_Scalper_EA.mq5` (`HasOpenPosition`, cooldown, same-bar, 5-minute cap).
- Check M1 `ValidateEntry()` in `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh` (spread/spike/score threshold).
- Check M5 `EvaluateEntries()` and `SelectAndRunStrategy()` in `EAs/Adaptive/XAUUSD_Adaptive_Management.mqh` and `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh`.

- If TOO MANY SKIPS:
- Check M1 spread/spike filters and score threshold in `EAs/M1_Scalper/XAUUSD_M1_Scalper_Entry.mqh`.
- Check M5 penalties/thresholds in `EAs/Adaptive/XAUUSD_Adaptive_Entry.mqh`.
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
- Keyword-based normalization maps inconsistent text to stable reasons (`LOW_SCORE`, `HIGH_SPREAD`, `INSUFFICIENT_MARGIN`, `COOLDOWN_ACTIVE`, `SESSION_BLOCK`)
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
- Check `SelectAndRunStrategy()` penalties and minimum score behavior
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
