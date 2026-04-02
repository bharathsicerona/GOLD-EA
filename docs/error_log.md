# Error Log - GoldEA Refactor

## [2026-03-31] Compilation Errors after Trade Context Engine Implementation

### 1. HashMap Type Errors
- **Error:** `class type expected, pointer to type 'TradeContext' is not allowed`
- **Location:** `GoldEA_Common_Core.mqh`, `XAUUSD_M1_Scalper_EA.mq5`
- **Cause:** MQL5 `CHashMap` does not easily support pointers to custom structs as value types without explicit comparers.
- **Fix:** Change `TradeContext` to a struct and store it by value in `CHashMap<ulong, TradeContext>`, or change it to a `class` and use pointers if necessary. Given the small size, storing by value (struct) is preferred.

### 2. M1 Scalper Logic Errors
- **Error:** `undeclared identifier 'spread'`
- **Location:** `XAUUSD_M1_Scalper_EA.mq5` line 760.
- **Cause:** `spread` variable used in `LogSignals` call but not declared or scope is incorrect.
- **Fix:** Ensure `spread` is fetched from `SymbolInfoInteger` before usage.

- **Error:** `undeclared identifier 'ResultPosition'`
- **Location:** `XAUUSD_M1_Scalper_EA.mq5` line 239.
- **Cause:** `CTrade` does not have a `ResultPosition()` method.
- **Fix:** Use `trade.ResultDeal()` and then `HistoryDealGetInteger(deal, DEAL_POSITION_ID)`.

- **Error:** `declaration of 'totalSignals' hides global variable`
- **Location:** `XAUUSD_M1_Scalper_EA.mq5` line 511.
- **Cause:** Local variable named `totalSignals` declared in a function, shadowing the global stats counter.
- **Fix:** Rename local variable or use the global one.

### 3. TradeContext Copy Logic
- **Error:** `objects are passed by reference only` in `HashMap.mqh`
- **Cause:** Likely due to the `struct` containing `string` fields and being used in a template that expects simple types or reference-compatible types.
- **Fix:** Define `TradeContext` as a class if used with pointers, or ensure proper struct usage.

## [2026-03-31] Fourth Round of Errors (M1_QuickHands EA)

### 1. Enum Conversion
- **Error:** `cannot convert enum XAUUSD_M1_QuickHands_EA.mq5 168 42`
- **Cause:** `PositionOpen` expects `ENUM_ORDER_TYPE` but `sig.type` was `ENUM_POSITION_TYPE`.
- **Fix:** Used the `orderType` local variable (already cast to `ENUM_ORDER_TYPE`).

### 2. Missing Identifier
- **Error:** `undeclared identifier 'ResultPosition'`
- **Cause:** `CTrade` class does not have `ResultPosition()`.
- **Fix:** Used `trade.ResultOrder()` and `trade.ResultDeal()` for ticket identification.

### 3. Private Member Access (HashMap)
- **Error:** `'CHashMap<ulong,TradeContext*>::Insert' - cannot access private member function`
- **Cause:** `Insert` is an internal private method in MQL5's `Generic/HashMap.mqh`.
- **Fix:** Switched to the public `Add(key, value)` method.

### 4. Parameter Mismatch (HashMap)
- **Error:** `wrong parameters count, 2 passed, but 3 requires`
- **Cause:** Misidentified the `Insert` signature (which was private anyway).
- **Fix:** Switched to `Add` which takes exactly 2 parameters.

## [2026-03-31] Second Round of Compilation Errors (Header Overlaps)

### 1. Variable Redefinition
- **Error:** `variable already defined InpEnableDebugPrints`, `InpTradeSymbol`, `InpMagicNumber`
- **Location:** `GoldEA_Common_Core.mqh`
- **Cause:** Shared header included redundant `input` declarations that already existed in `XAUUSD_M1_Scalper_Inputs.mqh` and `XAUUSD_Adaptive_Inputs.mqh`.
- **Fix:** Removed the `input` field declarations from `GoldEA_Common_Core.mqh`. Main EAs now handle their own input definitions before including the core header.

### 2. Missing Core Functions
- **Error:** `undeclared identifier CleanupLogsByPattern`, `SetDashboardLabelLine`
- **Location:** Logging modules (`XAUUSD_M1_Scalper_Logging.mqh`, `XAUUSD_Adaptive_Logging.mqh`)
- **Cause:** These helper functions were expected by the logging modules but were accidentally omitted from the refactored `Common_Core.mqh`.
- **Fix:** Implemented `CleanupLogsByPattern` (file deletion utility) and `SetDashboardLabelLine` (graphical dashboard update utility) in `GoldEA_Common_Core.mqh`.

### 3. Function Collision
- **Error:** `'DrawTradeArrow' - function already defined and has body`
- **Location:** `XAUUSD_Adaptive_Logging.mqh` vs `GoldEA_Common_Core.mqh`
- **Cause:** `DrawTradeArrow` was defined in both the shared core and the specialized Adaptive logging module.
- **Fix:** Removed `DrawTradeArrow` from `GoldEA_Common_Core.mqh`. Each EA logging module now manages its own specialized arrow placement logic.

### 4. Parameter Mismatch
- **Error:** `wrong parameters count, 4 passed, but 3 requires`
- **Location:** `XAUUSD_Adaptive_Indicators.mqh` calling `GetIndicatorValue`
- **Cause:** The core header version of `GetIndicatorValue` was missing the `shift` parameter used by the Adaptive EA.
- **Fix:** Updated `GetIndicatorValue` signature to `bool GetIndicatorValue(int handle, int shift, double &value, int buffer=0)`.

### 5. Missing Input Identifier
- **Error:** `undeclared identifier InpMinimumScore`
- **Location:** `XAUUSD_Adaptive_Logging.mqh`
- **Cause:** The dashboard logic required a threshold for coloring scores that wasn't defined in the M5 input file.
- **Fix:** Added `InpMinimumScore = 60` to `XAUUSD_Adaptive_Inputs.mqh`.

## [2026-03-31] Third Round of Compilation Errors (Logic & Braces)

### 1. Unbalanced Braces / Unexpected End of Program
- **Error:** `'{' - unbalanced parentheses` at line 513 + `unexpected end of program`.
- **Location:** `XAUUSD_M1_Scalper_EA.mq5`
- **Cause:** A `replace_file_content` call removed a closing brace `}` from an `if` block while adding the new `LOW_SCORE` filter.
- **Fix:** Refactored `ProcessStrategySignals` to use a clean if-else priority chain with one common exit point and a final score filter. Verified all braces are balanced.

### 2. Cascading Header Errors (Global Expressions)
- **Files:** `GoldEA_Common_Core.mqh`, `HashMap.mqh`, `IMap.mqh`
- **Error:** `expressions are not allowed on a global scope`
- **Cause:** These are secondary errors caused by the syntax breakage in the main MQ5. When the compiler fails inside a function due to an unbalanced brace, it treats the subsequent global includes and declarations as being *inside* that broken function scope.
- **Fix:** Resolving the MQ5 syntax error clears these secondary issues.

### 3. Memory Safety (Object references)
- **File:** `HashMap.mqh`
- **Error:** `'TradeContext' - objects are passed by reference only`
- **Cause:** Attempting to store the `TradeContext` class by value in a `CHashMap`.
- **Fix:** Switched to storing pointers (`TradeContext*`) in `g_tradeContextMap`. Implemented `new` and `delete` in `ExecuteTrade` and `OnTradeTransaction`.
